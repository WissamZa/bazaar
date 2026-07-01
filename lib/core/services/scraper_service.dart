import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

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

  String displayName(String localeCode) => localeCode == 'ar' ? labelAr : label;
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

  /// All single-source scrapers keyed by their [LookupSource].
  Map<LookupSource, Future<ScrapedProduct?> Function(String)>
      get _sourceScrapers => {
            LookupSource.openFoodFacts: _tryOpenFoodFacts,
            LookupSource.searxng: _trySearXNG,
          };

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
    final scraper = _sourceScrapers[source];
    if (scraper == null) return null;
    try {
      return await scraper(barcode);
    } catch (_) {
      return null;
    }
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
  Future<ScrapedProduct?> _trySearXNG(String barcode) async {
    return _trySearXNGChain(barcode, null);
  }

  /// The full chain. [offBase] is the OFF result we already have, used to
  /// short-circuit if SearXNG returns nothing useful.
  Future<ScrapedProduct?> _trySearXNGChain(
    String barcode,
    ScrapedProduct? offBase,
  ) async {
    final strategy = config?.strategy ?? ExtractionStrategy.schemaThenCloudLlm;
    final searxngUrl =
        config?.searxngUrl ?? 'https://cachyos-nitro.tail3d23b7.ts.net:8080';

    // Build a Saudi-focused query — same trick as test_scraper.dart.
    final query = '$barcode (site:.sa OR SAR OR "السعودية")';
    final url = Uri.parse(
      '$searxngUrl/search?q=${Uri.encodeComponent(query)}&format=json&locale=ar-SA',
    );

    final res = await http.get(url, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) {
      return offBase; // can't search — return whatever OFF gave us
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (json['results'] as List?)?.cast<Map<String, dynamic>>();
    if (results == null || results.isEmpty) return offBase;

    // Try the top 3 result URLs in order; first one that yields data wins.
    for (final r in results.take(3)) {
      final resultUrl = r['url'] as String?;
      final resultTitle = r['title'] as String? ?? '';
      if (resultUrl == null || resultUrl.isEmpty) continue;

      // Drop obvious UAE links.
      final lower = resultUrl.toLowerCase();
      if (lower.contains('.ae') || lower.contains('/uae')) continue;

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
          }
        } catch (_) {
          ex = null;
        }
      }

      // ── Tier 2: cloud LLM ────────────────────────────────────────────
      if ((ex == null || ex.name == null || ex.price == null) &&
          strategy.usesCloudLlm &&
          config != null) {
        try {
          final llmResult = await LlmExtractor.extract(
            provider: config!.provider,
            html: html ?? '',
            barcode: barcode,
            modelOverride: config!.model.isEmpty ? null : config!.model,
            baseUrlOverride: config!.baseUrl.isEmpty ? null : config!.baseUrl,
          );
          if (llmResult != null && llmResult.name != null) {
            // Merge: prefer schema's structured fields, fill gaps from LLM.
            ex = ExtractedProduct(
              name: ex?.name ?? llmResult.name,
              brand: ex?.brand ?? llmResult.brand,
              price: ex?.price ?? llmResult.price,
              currency: ex?.currency ?? llmResult.currency,
              imageUrl: ex?.imageUrl ?? llmResult.imageUrl,
            );
          }
        } catch (_) {}
      }

      // ── Tier 3: on-device LLM ────────────────────────────────────────
      if ((ex == null || ex.name == null || ex.price == null) &&
          strategy.usesOnDevice) {
        try {
          final local = await OnDeviceLlm.instance.extract(
            html: html ?? '',
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
        } catch (_) {}
      }

      // Got something usable? Build the ScrapedProduct and stop.
      if (ex != null && ex.name != null && ex.name!.isNotEmpty) {
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
    }

    // No structured data found. Fall back to the old behaviour: use the
    // first SearXNG result's title as the name (price will be null).
    final first = results.first;
    final title = (first['title'] as String? ?? '').trim();
    if (title.isEmpty) return offBase;
    return ScrapedProduct(
      name: title,
      nameAr: offBase?.nameAr,
      price: null,
      currency: 'SAR',
      source: 'SearXNG',
      imageUrl: first['img_src'] as String?,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ───────────────────────────────────────────────────────────────────────
  static Future<String?> _fetchHtml(String url) async {
    try {
      final res =
          await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) return res.body;
    } catch (_) {
      return null;
    }
    return null;
  }
}
