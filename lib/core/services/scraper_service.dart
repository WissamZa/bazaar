import 'dart:convert';
import 'package:http/http.dart' as http;

import '../providers/scraping_provider.dart';
import 'llm_extractor.dart';
import 'on_device_llm.dart';
import 'product_schema_parser.dart';

/// Result of a successful online scrape.
class ScrapedProduct {
  final String name;
  final String? nameAr;
  final String? brand;
  final double? price;
  final String currency;
  final String source;
  final String? imageUrl;

  const ScrapedProduct({
    required this.name,
    this.nameAr,
    this.brand,
    this.price,
    required this.currency,
    required this.source,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'name_ar': nameAr,
        'brand': brand,
        'price': price,
        'currency': currency,
        'source': source,
        'image_url': imageUrl,
      };
}

/// Identifiers for every lookup source the app knows about.
/// `auto` runs the full chain; the others target a single source.
enum LookupSource {
  auto,
  openFoodFacts,
  searxng,
}

extension LookupSourceX on LookupSource {
  String get label {
    switch (this) {
      case LookupSource.auto:
        return 'Auto (all sources)';
      case LookupSource.openFoodFacts:
        return 'Open Food Facts';
      case LookupSource.searxng:
        return 'SearXNG';
    }
  }

  String get labelAr {
    switch (this) {
      case LookupSource.auto:
        return 'تلقائي (كل المصادر)';
      case LookupSource.openFoodFacts:
        return 'أوبن فود فاكتس';
      case LookupSource.searxng:
        return 'سيركس إن جي';
    }
  }

  String displayName(String localeCode) =>
      localeCode == 'ar' ? labelAr : label;
}

/// Resolves a barcode to a product name + price using a configurable chain:
///
///   Tier 1 — Open Food Facts (always, gives AR name)
///   Tier 1 — SearXNG → first result URL → JSON-LD / OG parser
///   Tier 2 — Cloud LLM fallback (Gemini / OpenAI / Groq / Cerebras / Ollama)
///   Tier 3 — On-device LLM (MediaPipe Gemma / Llama / Qwen)
///
/// The chain is configured by [ScrapingProvider]. All API keys are read from
/// [Secrets] at call time — never logged, never persisted in plain prefs.
class ScraperService {
  ScraperService._();
  static final ScraperService instance = ScraperService._();

  static const _timeout = Duration(seconds: 12);
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'Accept': 'text/html,application/json,application/xhtml+xml',
  };

  /// Injected by main() at startup. Null = use defaults (no LLM, schema only).
  ScrapingProvider? config;

  /// Run scrapers in order, return the first non-null result. If only Open
  /// Food Facts returns data (no price), keep iterating so a store scraper
  /// can fill in the price.
  Future<ScrapedProduct?> searchBarcode(String barcode) async {
    ScrapedProduct? base;

    // OFF is always tried first — fast JSON, gives bilingual name.
    try {
      final result = await _tryOpenFoodFacts(barcode);
      if (result != null) base = result;
    } catch (_) {}

    // SearXNG → Tier 1/2/3 chain (this is where the magic happens).
    try {
      final searxResult = await _trySearXNGChain(barcode, base);
      if (searxResult != null) {
        if (base == null) {
          base = searxResult;
        } else {
          // Merge: keep OFF name, prefer a real price/brand from SearXNG.
          base = ScrapedProduct(
            name: base.name,
            nameAr: base.nameAr ?? searxResult.nameAr,
            brand: searxResult.brand ?? base.brand,
            price: searxResult.price ?? base.price,
            currency: searxResult.price != null
                ? searxResult.currency
                : base.currency,
            source: '${base.source} + ${searxResult.source}',
            imageUrl: base.imageUrl ?? searxResult.imageUrl,
          );
        }
      }
    } catch (_) {}

    if (base != null && base.price != null && base.name.isNotEmpty) {
      return base;
    }
    return base;
  }

  /// Look up a barcode using ONLY the user-selected [source].
  /// When [source] is `auto`, falls back to the full chain via [searchBarcode].
  Future<ScrapedProduct?> searchBarcodeFromSource(
    String barcode,
    LookupSource source,
  ) async {
    if (source == LookupSource.auto) {
      return searchBarcode(barcode);
    }
    try {
      switch (source) {
        case LookupSource.openFoodFacts:
          return await _tryOpenFoodFacts(barcode);
        case LookupSource.searxng:
          return await _trySearXNGChain(barcode, null);
        case LookupSource.auto:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Look up a barcode using a SPECIFIC [strategy] for this one call,
  /// ignoring the global strategy set in ScrapingProvider. Used by the
  /// manual lookup button in add_edit_item_screen to let the user pick a
  /// strategy per-lookup.
  ///
  /// Always runs Open Food Facts first (for bilingual name), then the
  /// SearXNG chain with the given strategy.
  Future<ScrapedProduct?> searchBarcodeWithStrategy(
    String barcode,
    ExtractionStrategy strategy,
  ) async {
    ScrapedProduct? base;
    try {
      final result = await _tryOpenFoodFacts(barcode);
      if (result != null) base = result;
    } catch (_) {}

    try {
      final searxResult = await _trySearXNGChain(
        barcode,
        base,
        strategyOverride: strategy,
      );
      if (searxResult != null) {
        if (base == null) {
          base = searxResult;
        } else {
          base = ScrapedProduct(
            name: base.name,
            nameAr: base.nameAr ?? searxResult.nameAr,
            brand: searxResult.brand ?? base.brand,
            price: searxResult.price ?? base.price,
            currency: searxResult.price != null
                ? searxResult.currency
                : base.currency,
            source: '${base.source} + ${searxResult.source}',
            imageUrl: base.imageUrl ?? searxResult.imageUrl,
          );
        }
      }
    } catch (_) {}

    return base;
  }

  /// Specialized lookup for SearXNG that returns all results.
  Future<List<ScrapedProduct>> searchBarcodeSearXNGMulti(String barcode) async {
    final url = Uri.parse(
      '${config?.searxngUrl ?? 'https://cachyos-nitro.tail3d23b7.ts.net:8080'}'
      '/search?q=$barcode&format=json',
    );
    try {
      final res = await http.get(url, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List?;
      if (results == null) return [];

      return results.map((r) {
        final map = r as Map<String, dynamic>;
        return ScrapedProduct(
          name: map['title'] as String? ?? 'Unknown Product',
          price: null,
          currency: 'SAR',
          source: 'SearXNG',
          imageUrl: map['img_src'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Open Food Facts — Tier 0: free structured JSON, gives name (no price)
  // ───────────────────────────────────────────────────────────────────────
  static Future<ScrapedProduct?> _tryOpenFoodFacts(String barcode) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
    );
    final res = await http.get(url, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != 1) return null;
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    final name = (product['product_name'] ??
            product['product_name_en'] ??
            product['generic_name'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) return null;
    return ScrapedProduct(
      name: name,
      nameAr: product['product_name_ar'] as String?,
      price: null,
      currency: 'SAR',
      source: 'Open Food Facts',
      imageUrl: product['image_url'] as String?,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // SearXNG chain — Tier 1 + Tier 2 + Tier 3
  // ───────────────────────────────────────────────────────────────────────

  /// The full chain. [offBase] is the OFF result we already have, used to
  /// short-circuit if SearXNG returns nothing useful.
  ///
  /// [strategyOverride] lets callers run a DIFFERENT strategy for a single
  /// lookup without changing the global setting (used by the manual lookup
  /// button in the add/edit item screen).
  ///
  /// We try TWO queries against SearXNG, in this order:
  ///   1. Bare barcode — broadest possible results, catches products from
  ///      any country (Chinese barcodes like 697…, EU barcodes like 40…, etc.)
  ///   2. Barcode + Saudi-focused filter — biases toward Saudi stores where
  ///      we're more likely to find a SAR-denominated price.
  ///
  /// For each query, we walk the top 5 result URLs and try Tier 1/2/3
  /// extraction on each. First URL that yields a usable name wins.
  Future<ScrapedProduct?> _trySearXNGChain(
    String barcode,
    ScrapedProduct? offBase, {
    ExtractionStrategy? strategyOverride,
  }) async {
    final strategy = strategyOverride ??
        config?.strategy ??
        ExtractionStrategy.schemaThenCloudLlm;
    final searxngUrl =
        config?.searxngUrl ?? 'https://cachyos-nitro.tail3d23b7.ts.net:8080';

    // Two-pass query strategy: broad first, Saudi-focused second.
    final queries = <String>[
      barcode,                                       // pass 1: bare barcode
      '$barcode (site:.sa OR SAR OR "السعودية")',   // pass 2: Saudi-biased
    ];

    List<Map<String, dynamic>> allResults = [];
    for (final q in queries) {
      final url = Uri.parse(
        '$searxngUrl/search?q=${Uri.encodeComponent(q)}&format=json&locale=ar-SA',
      );
      _log('SearXNG query: $q');
      try {
        final res = await http.get(url, headers: _headers).timeout(_timeout);
        if (res.statusCode != 200) {
          _log('  → HTTP ${res.statusCode}, skipping this query');
          continue;
        }
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final results = (json['results'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
        _log('  → ${results.length} results');
        // Deduplicate by URL — pass 1 and pass 2 often overlap.
        final seen = allResults.map((r) => r['url']).toSet();
        for (final r in results) {
          if (!seen.contains(r['url'])) allResults.add(r);
        }
        // If pass 1 already gave us ≥5 results, don't bother with pass 2.
        if (allResults.length >= 5) break;
      } catch (e) {
        _log('  → error: $e');
        continue;
      }
    }

    if (allResults.isEmpty) {
      _log('SearXNG returned no results for either query.');
      return offBase;
    }

    // Try the top 5 result URLs in order; first one that yields data wins.
    for (final r in allResults.take(5)) {
      final resultUrl = r['url'] as String?;
      final resultTitle = (r['title'] as String? ?? '').trim();
      if (resultUrl == null || resultUrl.isEmpty) continue;

      _log('Trying result: $resultUrl');

      // Skip obvious UAE / Dubai links — user is in Saudi and these usually
      // have different prices / currencies.
      final lower = resultUrl.toLowerCase();
      if (lower.contains('.ae') || lower.contains('/uae')) {
        _log('  → skipped (UAE link)');
        continue;
      }

      // ── Tier 1: fetch & parse JSON-LD / OG ──────────────────────────
      ExtractedProduct? ex;
      String? html;
      if (strategy.usesSchema) {
        try {
          final pageRes = await http
              .get(Uri.parse(resultUrl), headers: _headers)
              .timeout(_timeout);
          if (pageRes.statusCode == 200) {
            html = pageRes.body;
            ex = ProductSchemaParser.fromHtml(html);
            _log('  → Tier 1 schema: name=${ex?.name}, brand=${ex?.brand}, '
                'price=${ex?.price}');
          } else {
            _log('  → Tier 1 HTTP ${pageRes.statusCode}');
          }
        } catch (e) {
          _log('  → Tier 1 error: $e');
          ex = null;
        }
      }

      // ── Tier 2: cloud LLM ────────────────────────────────────────────
      final needsLlm = ex == null || ex.name == null || ex.price == null;
      if (needsLlm && strategy.usesCloudLlm && config != null) {
        if (html == null || html.isEmpty) {
          _log('  → Tier 2 skipped: no HTML to feed the LLM');
        } else {
          _log('  → Tier 2 calling ${config!.provider.label}…');
          try {
            final llmResult = await LlmExtractor.extract(
              provider: config!.provider,
              html: html,
              barcode: barcode,
              modelOverride:
                  config!.model.isEmpty ? null : config!.model,
              baseUrlOverride:
                  config!.baseUrl.isEmpty ? null : config!.baseUrl,
            );
            if (llmResult != null && llmResult.name != null) {
              _log('  → Tier 2 result: name=${llmResult.name}, '
                  'brand=${llmResult.brand}, price=${llmResult.price}');
              // Merge: prefer schema's structured fields, fill gaps from LLM.
              ex = ExtractedProduct(
                name: ex?.name ?? llmResult.name,
                brand: ex?.brand ?? llmResult.brand,
                price: ex?.price ?? llmResult.price,
                currency: ex?.currency ?? llmResult.currency,
                imageUrl: ex?.imageUrl ?? llmResult.imageUrl,
              );
            } else {
              _log('  → Tier 2 returned null');
            }
          } catch (e) {
            _log('  → Tier 2 error: $e');
          }
        }
      }

      // ── Tier 3: on-device LLM ────────────────────────────────────────
      final needsOnDevice =
          ex == null || ex.name == null || ex.price == null;
      if (needsOnDevice && strategy.usesOnDevice) {
        if (html == null || html.isEmpty) {
          _log('  → Tier 3 skipped: no HTML');
        } else {
          _log('  → Tier 3 calling on-device LLM…');
          try {
            final local = await OnDeviceLlm.instance.extract(
              html: html,
              barcode: barcode,
            );
            if (local != null && local.name != null) {
              _log('  → Tier 3 result: name=${local.name}, '
                  'brand=${local.brand}, price=${local.price}');
              ex = ExtractedProduct(
                name: ex?.name ?? local.name,
                brand: ex?.brand ?? local.brand,
                price: ex?.price ?? local.price,
                currency: ex?.currency ?? local.currency,
                imageUrl: ex?.imageUrl ?? local.imageUrl,
              );
            }
          } catch (e) {
            _log('  → Tier 3 error: $e');
          }
        }
      }

      // Got something usable? Build the ScrapedProduct and stop.
      if (ex != null && ex.name != null && ex.name!.isNotEmpty) {
        _log('✓ Using result from ${Uri.parse(resultUrl).host}');
        return ScrapedProduct(
          name: ex.name!,
          nameAr: offBase?.nameAr,
          brand: ex.brand,
          price: ex.price,
          currency: ex.currency ?? 'SAR',
          source: 'SearXNG → ${Uri.parse(resultUrl).host}',
          imageUrl: ex.imageUrl ?? r['img_src'] as String?,
        );
      }

      // Use SearXNG's title as a last-resort name if it's not garbage.
      if (resultTitle.isNotEmpty &&
          !resultTitle.toLowerCase().contains('untitled') &&
          resultTitle != 'بلا عنوان') {
        _log('  → using SearXNG title as fallback name');
        return ScrapedProduct(
          name: resultTitle,
          nameAr: offBase?.nameAr,
          price: null,
          currency: 'SAR',
          source: 'SearXNG',
          imageUrl: r['img_src'] as String?,
        );
      }
    }

    _log('✗ No usable product data found across ${allResults.length} results');
    return offBase;
  }

  /// Debug logger — prints to stderr so it shows up in `flutter run` console
  /// output. Disable by setting [ScraperService.debugLog] to false.
  static bool debugLog = true;
  static void _log(String msg) {
    if (debugLog) {
      // ignore: avoid_print
      print('[scraper] $msg');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Pipeline debugger — used by the PipelineDebuggerScreen to show the user
  // exactly what each tier produced for a given barcode. Lets them verify
  // the on-device LLM is actually working and compare to a manual browser
  // search.
  // ───────────────────────────────────────────────────────────────────────

  /// Run the full pipeline against [barcode] and return a step-by-step
  /// breakdown. Pure observability — does NOT cache, does NOT write to DB.
  /// Safe to call any number of times.
  Future<PipelineDebugResult> debugPipeline(String barcode) async {
    final result = PipelineDebugResult(barcode: barcode);
    final sw = Stopwatch()..start();

    // ── Step 1: Open Food Facts ──────────────────────────────────────────
    sw.reset();
    try {
      final off = await _tryOpenFoodFacts(barcode);
      result.steps.add(PipelineDebugStep(
        name: 'Open Food Facts',
        status: off != null
            ? PipelineStepStatus.success
            : PipelineStepStatus.noData,
        duration: sw.elapsed,
        data: off?.toJson(),
      ));
      result.offResult = off;
    } catch (e) {
      result.steps.add(PipelineDebugStep(
        name: 'Open Food Facts',
        status: PipelineStepStatus.failed,
        duration: sw.elapsed,
        error: e.toString(),
      ));
    }

    // ── Step 2: SearXNG queries ──────────────────────────────────────────
    final searxngUrl =
        config?.searxngUrl ?? 'https://cachyos-nitro.tail3d23b7.ts.net:8080';
    final queries = <String>[
      barcode,
      '$barcode (site:.sa OR SAR OR "السعودية")',
    ];
    List<Map<String, dynamic>> allResults = [];
    for (final q in queries) {
      sw.reset();
      try {
        final url = Uri.parse(
          '$searxngUrl/search?q=${Uri.encodeComponent(q)}&format=json&locale=ar-SA',
        );
        final res =
            await http.get(url, headers: _headers).timeout(_timeout);
        final List<Map<String, dynamic>> results;
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          results = (json['results'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              <Map<String, dynamic>>[];
        } else {
          results = [];
        }
        final seen = allResults.map((r) => r['url']).toSet();
        for (final r in results) {
          if (!seen.contains(r['url'])) allResults.add(r);
        }
        result.steps.add(PipelineDebugStep(
          name: 'SearXNG query: "$q"',
          status: results.isEmpty
              ? PipelineStepStatus.noData
              : PipelineStepStatus.success,
          duration: sw.elapsed,
          data: {
            'count': results.length,
            'titles': results
                .take(5)
                .map((r) => {
                      'title': r['title'],
                      'url': r['url'],
                      'engine': r['engine'],
                    })
                .toList(),
          },
        ));
        if (allResults.length >= 5) break;
      } catch (e) {
        result.steps.add(PipelineDebugStep(
          name: 'SearXNG query: "$q"',
          status: PipelineStepStatus.failed,
          duration: sw.elapsed,
          error: e.toString(),
        ));
      }
    }
    result.searxngResults = allResults;

    // Build the "open in browser" URL — uses the bare-barcode query.
    result.browserCompareUrl =
        '$searxngUrl/search?q=${Uri.encodeComponent(barcode)}';

    if (allResults.isEmpty) {
      return result..finalProduct = result.offResult;
    }

    // ── Step 3+: Per-result Tier 1 / 2 / 3 ──────────────────────────────
    final strategy =
        config?.strategy ?? ExtractionStrategy.schemaThenCloudLlm;
    for (final r in allResults.take(5)) {
      final resultUrl = r['url'] as String?;
      final resultTitle = (r['title'] as String? ?? '').trim();
      if (resultUrl == null || resultUrl.isEmpty) continue;

      final lower = resultUrl.toLowerCase();
      if (lower.contains('.ae') || lower.contains('/uae')) continue;

      final stepBase = 'Result: ${Uri.parse(resultUrl).host}';
      String? html;
      ExtractedProduct? ex;

      // ── Tier 1: schema parser ──────────────────────────────────────────
      sw.reset();
      if (strategy.usesSchema) {
        try {
          final pageRes = await http
              .get(Uri.parse(resultUrl), headers: _headers)
              .timeout(_timeout);
          if (pageRes.statusCode == 200) {
            html = pageRes.body;
            ex = ProductSchemaParser.fromHtml(html);
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 1 (schema)',
              status: ex?.name != null
                  ? PipelineStepStatus.success
                  : PipelineStepStatus.noData,
              duration: sw.elapsed,
              data: ex?.toJson(),
            ));
          } else {
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 1 (schema)',
              status: PipelineStepStatus.failed,
              duration: sw.elapsed,
              error: 'HTTP ${pageRes.statusCode}',
            ));
          }
        } catch (e) {
          result.steps.add(PipelineDebugStep(
            name: '$stepBase — Tier 1 (schema)',
            status: PipelineStepStatus.failed,
            duration: sw.elapsed,
            error: e.toString(),
          ));
        }
      }

      // ── Tier 2: cloud LLM ──────────────────────────────────────────────
      final needsLlm = ex == null || ex.name == null || ex.price == null;
      if (needsLlm && strategy.usesCloudLlm && config != null) {
        sw.reset();
        if (html == null || html.isEmpty) {
          result.steps.add(PipelineDebugStep(
            name: '$stepBase — Tier 2 (cloud LLM)',
            status: PipelineStepStatus.skipped,
            duration: Duration.zero,
            error: 'No HTML available (Tier 1 did not fetch the page)',
          ));
        } else {
          try {
            final llmResult = await LlmExtractor.extract(
              provider: config!.provider,
              html: html,
              barcode: barcode,
              modelOverride:
                  config!.model.isEmpty ? null : config!.model,
              baseUrlOverride:
                  config!.baseUrl.isEmpty ? null : config!.baseUrl,
            );
            if (llmResult != null && llmResult.name != null) {
              ex = ExtractedProduct(
                name: ex?.name ?? llmResult.name,
                brand: ex?.brand ?? llmResult.brand,
                price: ex?.price ?? llmResult.price,
                currency: ex?.currency ?? llmResult.currency,
                imageUrl: ex?.imageUrl ?? llmResult.imageUrl,
              );
            }
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 2 (${config!.provider.label})',
              status: llmResult?.name != null
                  ? PipelineStepStatus.success
                  : PipelineStepStatus.noData,
              duration: sw.elapsed,
              data: llmResult?.toJson(),
            ));
          } catch (e) {
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 2 (${config!.provider.label})',
              status: PipelineStepStatus.failed,
              duration: sw.elapsed,
              error: e.toString(),
            ));
          }
        }
      }

      // ── Tier 3: on-device LLM ──────────────────────────────────────────
      final needsOnDevice =
          ex == null || ex.name == null || ex.price == null;
      if (needsOnDevice && strategy.usesOnDevice) {
        sw.reset();
        if (html == null || html.isEmpty) {
          result.steps.add(PipelineDebugStep(
            name: '$stepBase — Tier 3 (on-device)',
            status: PipelineStepStatus.skipped,
            duration: Duration.zero,
            error: 'No HTML available',
          ));
        } else {
          try {
            final local = await OnDeviceLlm.instance.extract(
              html: html,
              barcode: barcode,
            );
            if (local != null && local.name != null) {
              ex = ExtractedProduct(
                name: ex?.name ?? local.name,
                brand: ex?.brand ?? local.brand,
                price: ex?.price ?? local.price,
                currency: ex?.currency ?? local.currency,
                imageUrl: ex?.imageUrl ?? local.imageUrl,
              );
            }
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 3 (on-device)',
              status: local?.name != null
                  ? PipelineStepStatus.success
                  : PipelineStepStatus.noData,
              duration: sw.elapsed,
              data: local?.toJson(),
            ));
          } catch (e) {
            result.steps.add(PipelineDebugStep(
              name: '$stepBase — Tier 3 (on-device)',
              status: PipelineStepStatus.failed,
              duration: sw.elapsed,
              error: e.toString(),
            ));
          }
        }
      }

      // First result with a usable name wins, same as the production chain.
      if (ex != null && ex.name != null && ex.name!.isNotEmpty) {
        result.finalProduct = ScrapedProduct(
          name: ex.name!,
          nameAr: result.offResult?.nameAr,
          brand: ex.brand,
          price: ex.price,
          currency: ex.currency ?? 'SAR',
          source: 'SearXNG → ${Uri.parse(resultUrl).host}',
          imageUrl: ex.imageUrl ?? r['img_src'] as String?,
        );
        break;
      }
    }

    // If nothing structured was found, fall back to SearXNG's first title.
    if (result.finalProduct == null && allResults.isNotEmpty) {
      final first = allResults.first;
      final title = (first['title'] as String? ?? '').trim();
      if (title.isNotEmpty &&
          !title.toLowerCase().contains('untitled') &&
          title != 'بلا عنوان') {
        result.finalProduct = ScrapedProduct(
          name: title,
          price: null,
          currency: 'SAR',
          source: 'SearXNG (title-only fallback)',
          imageUrl: first['img_src'] as String?,
        );
      }
    }

    return result;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ───────────────────────────────────────────────────────────────────────
  static Future<String?> _fetchHtml(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) return res.body;
    } catch (_) {
      return null;
    }
    return null;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Pipeline debugger data classes
// ───────────────────────────────────────────────────────────────────────────

enum PipelineStepStatus { success, noData, failed, skipped }

extension PipelineStepStatusX on PipelineStepStatus {
  String get label => switch (this) {
        PipelineStepStatus.success => 'success',
        PipelineStepStatus.noData => 'no data',
        PipelineStepStatus.failed => 'failed',
        PipelineStepStatus.skipped => 'skipped',
      };
}

class PipelineDebugStep {
  final String name;
  final PipelineStepStatus status;
  final Duration duration;
  final Map<String, dynamic>? data;
  final String? error;

  const PipelineDebugStep({
    required this.name,
    required this.status,
    required this.duration,
    this.data,
    this.error,
  });
}

class PipelineDebugResult {
  final String barcode;
  final List<PipelineDebugStep> steps = [];
  ScrapedProduct? offResult;
  List<Map<String, dynamic>> searxngResults = [];
  ScrapedProduct? finalProduct;
  String? browserCompareUrl;

  PipelineDebugResult({required this.barcode});

  /// Total wall-clock time spent (sum of step durations).
  Duration get totalDuration =>
      steps.fold(Duration.zero, (a, s) => a + s.duration);
}

