import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Fields extracted from a product page. All nullable — the parser returns
/// whatever it can find, never invents values.
class ExtractedProduct {
  final String? name;
  final String? brand;
  final double? price;
  final String? currency;
  final String? imageUrl;

  const ExtractedProduct({
    this.name,
    this.brand,
    this.price,
    this.currency,
    this.imageUrl,
  });

  bool get isEmpty =>
      name == null && brand == null && price == null && imageUrl == null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'price': price,
        'currency': currency,
        'image_url': imageUrl,
      };
}

/// Tier 1 extractor: parses the product page directly for structured data.
///
/// Strategy, in order of preference:
///   1. `<script type="application/ld+json">` containing a `Product` schema.
///      This is the schema.org vocabulary Google requires for rich results,
///      and almost every Saudi e-commerce site (Noon, Amazon.sa, Carrefour,
///      Panda, Jarir, Extra, Namshi) emits it.
///   2. OpenGraph + Twitter + `product:*` meta tags. Common on Shopify and
///      WooCommerce stores.
///   3. Last-resort regex on `<title>` for `… SAR` / `… ر.س`.
///
/// No per-site selectors. One parser handles every store that follows the
/// schema.org spec.
class ProductSchemaParser {
  ProductSchemaParser._();

  static const _timeout = Duration(seconds: 12);
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
  };

  /// Fetch [url] and try to extract product fields.
  /// Returns `null` only if the page can't be fetched at all; returns an
  /// [ExtractedProduct] with all-null fields if fetched but unparseable
  /// (so the caller can decide whether to fall back to Tier 2).
  static Future<ExtractedProduct?> fromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200 || res.body.isEmpty) return null;
    return fromHtml(res.body);
  }

  /// Pure function — useful for tests and for Tier 2 (LLM) re-use.
  static ExtractedProduct fromHtml(String html) {
    final doc = html_parser.parse(html);

    // ── 1. JSON-LD ────────────────────────────────────────────────────
    for (final el
        in doc.querySelectorAll('script[type="application/ld+json"]')) {
      final raw = el.text.trim();
      if (raw.isEmpty) continue;
      try {
        final parsed = jsonDecode(raw);
        for (final p in _findProductObjects(parsed)) {
          final ex = _fromSchema(p);
          if (ex.name != null && ex.name!.isNotEmpty) return ex;
        }
      } catch (_) {
        // Malformed JSON-LD — skip, try next.
      }
    }

    // ── 2. OpenGraph / product:* meta tags ────────────────────────────
    final ogTitle = _meta(doc, 'og:title');
    final ogImage = _meta(doc, 'og:image');
    final productPriceAmount = _meta(doc, 'product:price:amount');
    final productCurrency = _meta(doc, 'product:price:currency');
    final twitterTitle = _meta(doc, 'twitter:title');

    final title = ogTitle ?? twitterTitle;
    if (title != null) {
      return ExtractedProduct(
        name: title,
        price: productPriceAmount != null
            ? double.tryParse(productPriceAmount)
            : _regexPrice(title),
        currency: productCurrency,
        imageUrl: ogImage,
      );
    }

    // ── 3. Last resort: parse <title> for "Foo 12.34 SAR" ─────────────
    final pageTitle = doc.querySelector('title')?.text.trim();
    if (pageTitle != null && pageTitle.isNotEmpty) {
      return ExtractedProduct(
        name: pageTitle,
        price: _regexPrice(pageTitle),
        imageUrl: ogImage,
      );
    }

    return const ExtractedProduct();
  }

  // ── JSON-LD walker ─────────────────────────────────────────────────────
  /// Recursively walks the JSON-LD tree and collects every object whose
  /// `@type` is `Product` (or a list containing `Product`). Handles the
  /// common `{"@graph": [...]}` wrapper used by WordPress / WooCommerce.
  static List<Map<String, dynamic>> _findProductObjects(dynamic node) {
    final out = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map<String, dynamic>) {
        final type = n['@type'];
        if (type == 'Product' || (type is List && type.contains('Product'))) {
          out.add(n);
        }
        if (n['@graph'] is List) (n['@graph'] as List).forEach(walk);
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return out;
  }

  static ExtractedProduct _fromSchema(Map<String, dynamic> s) {
    final offers = s['offers'];
    double? price;
    String? currency;
    if (offers is Map) {
      price = _toDouble(offers['price'] ?? offers['lowPrice']);
      currency = offers['priceCurrency'] as String?;
    } else if (offers is List && offers.isNotEmpty) {
      final o = offers.first;
      if (o is Map) {
        price = _toDouble(o['price'] ?? o['lowPrice']);
        currency = o['priceCurrency'] as String?;
      }
    }

    final brand = s['brand'];
    String? brandName;
    if (brand is Map) {
      brandName = brand['name'] as String?;
    } else if (brand is String) {
      brandName = brand;
    }

    // image can be a string, a list of strings, or a list of ImageObject
    String? image;
    final img = s['image'];
    if (img is String) {
      image = img;
    } else if (img is List && img.isNotEmpty) {
      final first = img.first;
      if (first is String) {
        image = first;
      } else if (first is Map) {
        image = first['url'] as String?;
      }
    }

    return ExtractedProduct(
      name: s['name'] as String?,
      brand: brandName,
      price: price,
      currency: currency,
      imageUrl: image,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  static String? _meta(doc, String prop) =>
      doc.querySelector('meta[property="$prop"]')?.attributes['content'];

  /// Matches `12.34 SAR`, `SAR 12.34`, `12.34 ر.س`, `12.34 ﷼`, `12.34 SR`.
  static double? _regexPrice(String s) {
    final m = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:SAR|AED|USD|ر\.س|﷼|SR)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) return double.tryParse(m.group(1)!);
    // also try "SAR 12.34"
    final m2 = RegExp(
      r'(?:SAR|AED|USD|SR|ر\.س|﷼)\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(s);
    return m2 == null ? null : double.tryParse(m2.group(1)!);
  }

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString().replaceAll(',', ''));
}
