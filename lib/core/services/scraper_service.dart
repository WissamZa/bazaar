import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import 'llm_common.dart';
import 'llm_extractor.dart';
import 'on_device_llm.dart';
import 'product_schema_parser.dart';
import 'scraping_config.dart';

export 'scraping_config.dart' show LookupSource, ExtractionStrategy;

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

/// Resolves a barcode to product data using a configurable chain:
///
///   Tier 0 — Open Food Facts (free JSON, gives bilingual name)
///   Tier 1 — SearXNG → result page → JSON-LD / OG parser
///   Tier 2 — Cloud LLM (Gemini / OpenAI / Groq / Cerebras / Ollama)
///   Tier 3 — On-device LLM (MediaPipe .task models)
///
/// The chain is driven by [ScrapingConfig]; keys are read from [Secrets] at
/// call time. [cancelToken] lets callers abandon long chains (e.g. the user
/// navigating away), which the v1 pipeline could not do.
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

  /// Injected at startup from the ScrapingConfigNotifier.
  ScrapingConfig config = const ScrapingConfig();

  /// Run the full chain, return the best result. Open Food Facts always runs
  /// first (fast JSON, bilingual name); the SearXNG chain fills price/brand.
  Future<ScrapedProduct?> searchBarcode(
    String barcode, {
    CancelToken? cancelToken,
  }) async {
    ScrapedProduct? base;
    try {
      base = await _tryOpenFoodFacts(barcode);
    } catch (_) {}

    try {
      final searx = await _trySearXNGChain(
        barcode,
        base,
        cancelToken: cancelToken,
      );
      if (searx != null) {
        base = _merge(base, searx);
      }
    } catch (_) {}
    return base;
  }

  /// Look up a barcode using ONLY the user-selected [source].
  Future<ScrapedProduct?> searchBarcodeFromSource(
    String barcode,
    LookupSource source, {
    CancelToken? cancelToken,
  }) async {
    if (source == LookupSource.auto) {
      return searchBarcode(barcode, cancelToken: cancelToken);
    }
    try {
      switch (source) {
        case LookupSource.openFoodFacts:
          return await _tryOpenFoodFacts(barcode);
        case LookupSource.searxng:
          return await _trySearXNGChain(
            barcode,
            null,
            cancelToken: cancelToken,
          );
        case LookupSource.auto:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Look up with a SPECIFIC [strategy] for one call (manual lookup picker),
  /// ignoring the global strategy. Always runs OFF first for the AR name.
  Future<ScrapedProduct?> searchBarcodeWithStrategy(
    String barcode,
    ExtractionStrategy strategy, {
    CancelToken? cancelToken,
  }) async {
    ScrapedProduct? base;
    try {
      base = await _tryOpenFoodFacts(barcode);
    } catch (_) {}
    try {
      final searx = await _trySearXNGChain(
        barcode,
        base,
        strategyOverride: strategy,
        cancelToken: cancelToken,
      );
      if (searx != null) base = _merge(base, searx);
    } catch (_) {}
    return base;
  }

  /// Specialized SearXNG lookup returning every result (bulk picker).
  Future<List<ScrapedProduct>> searchBarcodeSearXNGMulti(String barcode) async {
    final url = Uri.parse('${config.searxngUrl}/search?q=$barcode&format=json');
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
          currency: 'SAR',
          source: 'SearXNG',
          imageUrl: map['img_src'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── internals ──────────────────────────────────────────────────────────

  static ScrapedProduct? _merge(ScrapedProduct? base, ScrapedProduct? extra) {
    if (extra == null) return base;
    if (base == null) return extra;
    return ScrapedProduct(
      name: base.name,
      nameAr: base.nameAr ?? extra.nameAr,
      brand: extra.brand ?? base.brand,
      price: extra.price ?? base.price,
      currency: extra.price != null ? extra.currency : base.currency,
      source: '${base.source} + ${extra.source}',
      imageUrl: base.imageUrl ?? extra.imageUrl,
    );
  }

  /// Tier 0: Open Food Facts.
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
    final name =
        (product['product_name'] ??
                product['product_name_en'] ??
                product['generic_name'] ??
                '')
            .toString()
            .trim();
    if (name.isEmpty) return null;
    return ScrapedProduct(
      name: name,
      nameAr: product['product_name_ar'] as String?,
      currency: 'SAR',
      source: 'Open Food Facts',
      imageUrl: product['image_url'] as String?,
    );
  }

  /// Tiers 1–3. Two SearXNG queries (broad, then Saudi-biased), walking the
  /// top 5 result URLs each. [offBase] short-circuits when nothing better
  /// shows up.
  Future<ScrapedProduct?> _trySearXNGChain(
    String barcode,
    ScrapedProduct? offBase, {
    ExtractionStrategy? strategyOverride,
    CancelToken? cancelToken,
  }) async {
    final strategy = strategyOverride ?? config.strategy;
    final searxngUrl = config.searxngUrl;
    if (searxngUrl.isEmpty) {
      _log('SearXNG URL not configured — skipping chain.');
      return offBase;
    }

    final allResults = await _searxngResults(searxngUrl, barcode);
    if (allResults.isEmpty) {
      _log('SearXNG returned no results for either query.');
      return offBase;
    }

    for (final r in allResults.take(5)) {
      if (cancelToken?.isCancelled ?? false) return null;
      final resultUrl = r['url'] as String?;
      final resultTitle = (r['title'] as String? ?? '').trim();
      if (resultUrl == null || resultUrl.isEmpty) continue;

      _log('Trying result: $resultUrl');
      final lower = resultUrl.toLowerCase();
      // Skip UAE links — user is in Saudi; different prices/currency.
      if (lower.contains('.ae') || lower.contains('/uae')) {
        _log('  → skipped (UAE link)');
        continue;
      }

      final ex = await _extractWithTiers(
        resultUrl,
        barcode,
        strategy,
        cancelToken: cancelToken,
      );

      if (ex != null && ex.hasUsableName) {
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

      if (resultTitle.isNotEmpty &&
          !resultTitle.toLowerCase().contains('untitled') &&
          resultTitle != 'بلا عنوان') {
        _log('  → using SearXNG title as fallback name');
        return ScrapedProduct(
          name: resultTitle,
          nameAr: offBase?.nameAr,
          currency: 'SAR',
          source: 'SearXNG',
          imageUrl: r['img_src'] as String?,
        );
      }
    }

    _log('✗ No usable product data found across ${allResults.length} results');
    return offBase;
  }

  /// Run SearXNG (both query passes), deduplicated by URL.
  Future<List<Map<String, dynamic>>> _searxngResults(
    String searxngUrl,
    String barcode,
  ) async {
    final queries = [barcode, '$barcode (site:.sa OR SAR OR "السعودية")'];
    final all = <Map<String, dynamic>>[];
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
        final results =
            (json['results'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        _log('  → ${results.length} results');
        final seen = all.map((r) => r['url']).toSet();
        for (final r in results) {
          if (!seen.contains(r['url'])) all.add(r);
        }
        if (all.length >= 5) break;
      } catch (e) {
        _log('  → error: $e');
      }
    }
    return all;
  }

  /// Fetch one result URL and run Tier 1 → 2 → 3 per the strategy,
  /// merging as each tier fills gaps.
  Future<ExtractedProduct?> _extractWithTiers(
    String resultUrl,
    String barcode,
    ExtractionStrategy strategy, {
    CancelToken? cancelToken,
  }) async {
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
          _log('  → Tier 1 schema: name=${ex?.name}, price=${ex?.price}');
        } else {
          _log('  → Tier 1 HTTP ${pageRes.statusCode}');
        }
      } catch (e) {
        _log('  → Tier 1 error: $e');
      }
    }

    if ((ex == null || !ex.hasUsableName || ex.price == null) &&
        strategy.usesCloudLlm) {
      if (cancelToken?.isCancelled ?? false) return ex;
      if (html == null || html.isEmpty) {
        _log('  → Tier 2 skipped: no HTML to feed the LLM');
      } else {
        _log('  → Tier 2 calling ${config.provider.name}…');
        try {
          final llmResult = await LlmExtractor.extract(
            provider: config.provider,
            html: html,
            barcode: barcode,
            modelOverride: config.model.isEmpty ? null : config.model,
            baseUrlOverride: config.baseUrl.isEmpty ? null : config.baseUrl,
          );
          if (llmResult != null && llmResult.hasUsableName) {
            _log('  → Tier 2 result: ${llmResult.name}');
            ex = _mergeExtracted(ex, llmResult);
          }
        } catch (e) {
          _log('  → Tier 2 error: $e');
        }
      }
    }

    if ((ex == null || !ex.hasUsableName || ex.price == null) &&
        strategy.usesOnDevice) {
      if (cancelToken?.isCancelled ?? false) return ex;
      if (html == null || html.isEmpty) {
        _log('  → Tier 3 skipped: no HTML');
      } else {
        _log('  → Tier 3 calling on-device LLM…');
        try {
          final local = await OnDeviceLlm.instance.extract(
            html: html,
            barcode: barcode,
          );
          if (local != null && local.hasUsableName) {
            _log('  → Tier 3 result: ${local.name}');
            ex = _mergeExtracted(ex, local);
          }
        } catch (e) {
          _log('  → Tier 3 error: $e');
        }
      }
    }
    return ex;
  }

  static ExtractedProduct _mergeExtracted(
    ExtractedProduct? base,
    ExtractedProduct extra,
  ) => ExtractedProduct(
    name: base?.name ?? extra.name,
    brand: base?.brand ?? extra.brand,
    price: base?.price ?? extra.price,
    currency: base?.currency ?? extra.currency,
    imageUrl: base?.imageUrl ?? extra.imageUrl,
  );

  /// Debug logger — kDebugMode-gated so release builds are silent
  /// (audit Finding 2: queries/titles leaked to logcat in v1 release logs).
  static void _log(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[scraper] $msg');
    }
  }

  // ── Pipeline debugger ──────────────────────────────────────────────────
  // Runs the full pipeline against [barcode] and returns a step-by-step
  // breakdown. Pure observability — no caching, no DB writes.

  Future<PipelineDebugResult> debugPipeline(String barcode) async {
    final result = PipelineDebugResult(barcode: barcode);
    final sw = Stopwatch()..start();

    sw.reset();
    try {
      final off = await _tryOpenFoodFacts(barcode);
      result.steps.add(
        PipelineDebugStep(
          name: 'Open Food Facts',
          status: off != null
              ? PipelineStepStatus.success
              : PipelineStepStatus.noData,
          duration: sw.elapsed,
          data: off?.toJson(),
        ),
      );
      result.offResult = off;
    } catch (e) {
      result.steps.add(
        PipelineDebugStep(
          name: 'Open Food Facts',
          status: PipelineStepStatus.failed,
          duration: sw.elapsed,
          error: e.toString(),
        ),
      );
    }

    final searxngUrl = config.searxngUrl;
    if (searxngUrl.isEmpty) {
      result.steps.add(
        PipelineDebugStep(
          name: 'SearXNG',
          status: PipelineStepStatus.failed,
          duration: Duration.zero,
          error: 'SearXNG URL is not configured. Open Settings → Search & AI.',
        ),
      );
      return result..finalProduct = result.offResult;
    }

    final queries = [barcode, '$barcode (site:.sa OR SAR OR "السعودية")'];
    final allResults = <Map<String, dynamic>>[];
    for (final q in queries) {
      sw.reset();
      try {
        final url = Uri.parse(
          '$searxngUrl/search?q=${Uri.encodeComponent(q)}&format=json&locale=ar-SA',
        );
        final res = await http.get(url, headers: _headers).timeout(_timeout);
        List<Map<String, dynamic>> results = [];
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          results =
              (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        }
        final seen = allResults.map((r) => r['url']).toSet();
        for (final r in results) {
          if (!seen.contains(r['url'])) allResults.add(r);
        }
        result.steps.add(
          PipelineDebugStep(
            name: 'SearXNG query: "$q"',
            status: results.isEmpty
                ? PipelineStepStatus.noData
                : PipelineStepStatus.success,
            duration: sw.elapsed,
            data: {
              'count': results.length,
              'titles': results.take(5).map((r) {
                return {
                  'title': r['title'],
                  'url': r['url'],
                  'engine': r['engine'],
                };
              }).toList(),
            },
          ),
        );
        if (allResults.length >= 5) break;
      } catch (e) {
        result.steps.add(
          PipelineDebugStep(
            name: 'SearXNG query: "$q"',
            status: PipelineStepStatus.failed,
            duration: sw.elapsed,
            error: e.toString(),
          ),
        );
      }
    }
    result.searxngResults = allResults;
    result.browserCompareUrl =
        '$searxngUrl/search?q=${Uri.encodeComponent(barcode)}';

    if (allResults.isEmpty) {
      return result..finalProduct = result.offResult;
    }

    final strategy = config.strategy;
    for (final r in allResults.take(5)) {
      final resultUrl = r['url'] as String?;
      if (resultUrl == null || resultUrl.isEmpty) continue;
      final lower = resultUrl.toLowerCase();
      if (lower.contains('.ae') || lower.contains('/uae')) continue;

      final stepBase = 'Result: ${Uri.parse(resultUrl).host}';
      String? html;
      ExtractedProduct? ex;

      sw.reset();
      if (strategy.usesSchema) {
        try {
          final pageRes = await http
              .get(Uri.parse(resultUrl), headers: _headers)
              .timeout(_timeout);
          if (pageRes.statusCode == 200) {
            html = pageRes.body;
            ex = ProductSchemaParser.fromHtml(html);
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 1 (schema)',
                status: ex.hasUsableName
                    ? PipelineStepStatus.success
                    : PipelineStepStatus.noData,
                duration: sw.elapsed,
                data: ex.toJson(),
              ),
            );
          } else {
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 1 (schema)',
                status: PipelineStepStatus.failed,
                duration: sw.elapsed,
                error: 'HTTP ${pageRes.statusCode}',
              ),
            );
          }
        } catch (e) {
          result.steps.add(
            PipelineDebugStep(
              name: '$stepBase — Tier 1 (schema)',
              status: PipelineStepStatus.failed,
              duration: sw.elapsed,
              error: e.toString(),
            ),
          );
        }
      }

      if ((ex == null || !ex.hasUsableName || ex.price == null) &&
          strategy.usesCloudLlm) {
        sw.reset();
        if (html == null || html.isEmpty) {
          result.steps.add(
            PipelineDebugStep(
              name: '$stepBase — Tier 2 (${config.provider.name})',
              status: PipelineStepStatus.skipped,
              duration: Duration.zero,
              error: 'No HTML available (Tier 1 did not fetch the page)',
            ),
          );
        } else {
          try {
            final llmResult = await LlmExtractor.extract(
              provider: config.provider,
              html: html,
              barcode: barcode,
              modelOverride: config.model.isEmpty ? null : config.model,
              baseUrlOverride: config.baseUrl.isEmpty ? null : config.baseUrl,
            );
            if (llmResult != null && llmResult.hasUsableName) {
              ex = _mergeExtracted(ex, llmResult);
            }
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 2 (${config.provider.name})',
                status: llmResult?.name != null
                    ? PipelineStepStatus.success
                    : PipelineStepStatus.noData,
                duration: sw.elapsed,
                data: llmResult?.toJson(),
              ),
            );
          } catch (e) {
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 2 (${config.provider.name})',
                status: PipelineStepStatus.failed,
                duration: sw.elapsed,
                error: e.toString(),
              ),
            );
          }
        }
      }

      if ((ex == null || !ex.hasUsableName || ex.price == null) &&
          strategy.usesOnDevice) {
        sw.reset();
        if (html == null || html.isEmpty) {
          result.steps.add(
            PipelineDebugStep(
              name: '$stepBase — Tier 3 (on-device)',
              status: PipelineStepStatus.skipped,
              duration: Duration.zero,
              error: 'No HTML available',
            ),
          );
        } else {
          try {
            final local = await OnDeviceLlm.instance.extract(
              html: html,
              barcode: barcode,
            );
            if (local != null && local.hasUsableName) {
              ex = _mergeExtracted(ex, local);
            }
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 3 (on-device)',
                status: local?.name != null
                    ? PipelineStepStatus.success
                    : PipelineStepStatus.noData,
                duration: sw.elapsed,
                data: local?.toJson(),
              ),
            );
          } catch (e) {
            result.steps.add(
              PipelineDebugStep(
                name: '$stepBase — Tier 3 (on-device)',
                status: PipelineStepStatus.failed,
                duration: sw.elapsed,
                error: e.toString(),
              ),
            );
          }
        }
      }

      if (ex != null && ex.hasUsableName) {
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

    if (result.finalProduct == null && allResults.isNotEmpty) {
      final first = allResults.first;
      final title = (first['title'] as String? ?? '').trim();
      if (title.isNotEmpty &&
          !title.toLowerCase().contains('untitled') &&
          title != 'بلا عنوان') {
        result.finalProduct = ScrapedProduct(
          name: title,
          currency: 'SAR',
          source: 'SearXNG (title-only fallback)',
          imageUrl: first['img_src'] as String?,
        );
      }
    }

    return result;
  }
}

/// Cooperative cancellation for long scraper chains.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

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

  Duration get totalDuration =>
      steps.fold(Duration.zero, (a, s) => a + s.duration);
}
