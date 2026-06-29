import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

/// Result of a successful online scrape.
class ScrapedProduct {
  final String name;
  final String? nameAr;
  final double? price;
  final String currency;
  final String source;
  final String? imageUrl;

  const ScrapedProduct({
    required this.name,
    this.nameAr,
    this.price,
    required this.currency,
    required this.source,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'name_ar': nameAr,
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
  amazonSa,
  noon,
  panda,
  carrefourSa,
}

extension LookupSourceX on LookupSource {
  String get label {
    switch (this) {
      case LookupSource.auto:
        return 'Auto (all sources)';
      case LookupSource.openFoodFacts:
        return 'Open Food Facts';
      case LookupSource.amazonSa:
        return 'Amazon SA';
      case LookupSource.noon:
        return 'Noon';
      case LookupSource.panda:
        return 'Panda';
      case LookupSource.carrefourSa:
        return 'Carrefour SA';
    }
  }

  String get labelAr {
    switch (this) {
      case LookupSource.auto:
        return 'تلقائي (كل المصادر)';
      case LookupSource.openFoodFacts:
        return 'أوبن فود فاكتس';
      case LookupSource.amazonSa:
        return 'أمازون السعودية';
      case LookupSource.noon:
        return 'نون';
      case LookupSource.panda:
        return 'بندا';
      case LookupSource.carrefourSa:
        return 'كارفور السعودية';
    }
  }

  String displayName(String localeCode) => localeCode == 'ar' ? labelAr : label;
}

/// Tries multiple stores + Open Food Facts to resolve a barcode to a product
/// name + price. All requests are wrapped in try/catch so a single failing
/// store never breaks the chain.
///
/// NOTE: Store HTML selectors WILL break over time as sites change. Open Food
/// Facts is the most reliable source (structured JSON API) so it is always
/// tried last as a name fallback.
class ScraperService {
  ScraperService._();
  static final ScraperService instance = ScraperService._();

  static const _timeout = Duration(seconds: 10);
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'Accept': 'text/html,application/json,application/xhtml+xml',
  };

  /// All single-source scrapers keyed by their [LookupSource].
  static final Map<LookupSource, Future<ScrapedProduct?> Function(String)>
      _sourceScrapers = {
    LookupSource.openFoodFacts: _tryOpenFoodFacts,
    LookupSource.amazonSa: _tryAmazonSA,
    LookupSource.noon: _tryNoon,
    LookupSource.panda: _tryPanda,
    LookupSource.carrefourSa: _tryCarrefourSA,
  };

  /// The default ordered chain used by [searchBarcode].
  final _scrapers = <Future<ScrapedProduct?> Function(String)>[
    _tryOpenFoodFacts, // first — fast JSON, gives name (no price)
    _tryAmazonSA,
    _tryNoon,
    _tryPanda,
    _tryCarrefourSA,
  ];

  /// Run scrapers in order, return the first non-null result. If only Open
  /// Food Facts returns data (no price), keep iterating so a store scraper
  /// can fill in the price.
  Future<ScrapedProduct?> searchBarcode(String barcode) async {
    ScrapedProduct? base;
    for (final scraper in _scrapers) {
      try {
        final result = await scraper(barcode);
        if (result == null) continue;
        if (base == null) {
          base = result;
        } else {
          // Merge: keep base name, prefer a real price.
          if (base.price == null && result.price != null) {
            base = ScrapedProduct(
              name: base.name,
              nameAr: base.nameAr ?? result.nameAr,
              price: result.price,
              currency: result.currency,
              source: '${base.source} + ${result.source}',
              imageUrl: base.imageUrl ?? result.imageUrl,
            );
          }
        }
        if (base.price != null && base.name.isNotEmpty) {
          return base;
        }
      } catch (_) {
        continue;
      }
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

  // ───────────────────────── Open Food Facts ──────────────────────────
  /// Free, no key, returns structured JSON. The most reliable source for the
  /// product NAME (and AR name when available). Price is intentionally null
  /// — OFF is a food database, not a marketplace.
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

  // ───────────────────────── Amazon SA ────────────────────────────────
  static Future<ScrapedProduct?> _tryAmazonSA(String barcode) async {
    final html = await _fetchHtml('https://www.amazon.sa/s?k=$barcode');
    if (html == null) return null;
    final doc = parse(html);

    final nameEl = doc.querySelector(
            'div.s-result-item h2 a span, span.a-size-medium.a-color-base',) ??
        doc.querySelectorAll('h2 a span').firstOrNull;
    final priceWhole =
        doc.querySelector('span.a-price-whole')?.text.trim() ?? '';
    final priceFrac =
        doc.querySelector('span.a-price-fraction')?.text.trim() ?? '';
    final priceStr = '$priceWhole$priceFrac'.replaceAll(RegExp(r'[^0-9.]'), '');

    final name = nameEl?.text.trim() ?? '';
    if (name.isEmpty) return null;
    return ScrapedProduct(
      name: name,
      price: double.tryParse(priceStr),
      currency: 'SAR',
      source: 'Amazon SA',
    );
  }

  // ───────────────────────── Noon ─────────────────────────────────────
  /// Noon is a JS-heavy SPA — the static HTML rarely contains the product
  /// card. We still attempt it because some crawlers cache a SSR fallback.
  static Future<ScrapedProduct?> _tryNoon(String barcode) async {
    final html = await _fetchHtml(
      'https://www.noon.com/saudi-en/search/?q=$barcode',
    );
    if (html == null) return null;
    final doc = parse(html);

    final nameEl = doc.querySelector('[data-qa="product-name"]') ??
        doc.querySelector('.productContainer .name');
    final priceEl = doc.querySelector('[data-qa="product-price"]') ??
        doc.querySelector('.price');

    if (nameEl == null) return null;
    final priceStr = (priceEl?.text ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
    return ScrapedProduct(
      name: nameEl.text.trim(),
      price: double.tryParse(priceStr),
      currency: 'SAR',
      source: 'Noon',
    );
  }

  // ───────────────────────── Panda ────────────────────────────────────
  static Future<ScrapedProduct?> _tryPanda(String barcode) async {
    final html = await _fetchHtml(
      'https://www.pandamart.com/search?query=$barcode',
    );
    if (html == null) return null;
    final doc = parse(html);
    final nameEl = doc.querySelector('.product-name, .product-title');
    final priceEl = doc.querySelector('.price, .product-price');
    if (nameEl == null) return null;
    final priceStr = (priceEl?.text ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
    return ScrapedProduct(
      name: nameEl.text.trim(),
      price: double.tryParse(priceStr),
      currency: 'SAR',
      source: 'Panda',
    );
  }

  // ───────────────────────── Carrefour SA ─────────────────────────────
  static Future<ScrapedProduct?> _tryCarrefourSA(String barcode) async {
    final html = await _fetchHtml(
      'https://www.carrefourksa.com/mafsau/en/search?keyword=$barcode',
    );
    if (html == null) return null;
    final doc = parse(html);
    final nameEl = doc.querySelector('.product-title, .cmp-product-card__name');
    final priceEl =
        doc.querySelector('.product-price, .cmp-product-card__price');
    if (nameEl == null) return null;
    final priceStr = (priceEl?.text ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
    return ScrapedProduct(
      name: nameEl.text.trim(),
      price: double.tryParse(priceStr),
      currency: 'SAR',
      source: 'Carrefour',
    );
  }

  // ───────────────────────── Shared helpers ───────────────────────────
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
