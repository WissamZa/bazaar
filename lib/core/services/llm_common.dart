import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

/// Value shared by Tier 2 (cloud) and Tier 3 (on-device) extraction.
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

  bool get hasUsableName => name != null && name!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'brand': brand,
    'price': price,
    'currency': currency,
    'image_url': imageUrl,
  };
}

/// The canonical extraction prompt shared by both LLM tiers so their
/// outputs stay schema-identical.
abstract final class LlmPrompts {
  static const system =
      'You extract structured product data from raw e-commerce HTML text. '
      'Respond ONLY as JSON with this exact schema: '
      '{"name": string|null, "brand": string|null, "price": number|null, '
      '"currency": "SAR"|"AED"|"USD"|null, "image_url": string|null}. '
      'If a field is missing or uncertain, use null. Do not invent values. '
      'Do not include markdown fences or any text outside the JSON object.';
}

/// HTML → clean text for LLM input.
abstract final class LlmText {
  /// Strips scripts/styles/nav/footer and squashes whitespace so the LLM
  /// sees mostly product copy. Truncates to [maxChars] (free-tier limits).
  static String cleanHtmlForLlm(String html, {int maxChars = 6000}) {
    final doc = html_parser.parse(html);
    doc
        .querySelectorAll(
          'script,style,noscript,nav,footer,header,svg,iframe,form,button',
        )
        .forEach((e) => e.remove());
    final text = doc.body?.text ?? '';
    final squashed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squashed.length <= maxChars) return squashed;
    return squashed.substring(0, maxChars);
  }
}

/// JSON parsing of LLM responses (tolerant of markdown fences).
abstract final class LlmJson {
  static ExtractedProduct? parseExtracted(String raw) {
    final s = _stripFences(raw);
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return null;
    try {
      final json =
          jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
      return ExtractedProduct(
        name: _clean(json['name']),
        brand: _clean(json['brand']),
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        imageUrl: json['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static String _stripFences(String raw) {
    var s = raw.trim();
    final fenceStart = s.indexOf('```');
    if (fenceStart != -1) {
      s = s.substring(fenceStart + 3);
      if (s.toLowerCase().startsWith('json')) s = s.substring(4);
      final fenceEnd = s.lastIndexOf('```');
      if (fenceEnd != -1) s = s.substring(0, fenceEnd);
      s = s.trim();
    }
    return s;
  }

  static String? _clean(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
