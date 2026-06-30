import 'dart:convert';
import 'package:http/http.dart' as http;

// 1. Standalone ScrapedProduct model
class ScrapedProduct {
  final String name;
  final double? price;
  final String currency;
  final String source;
  final String? imageUrl;

  ScrapedProduct({
    required this.name,
    this.price,
    required this.currency,
    required this.source,
    this.imageUrl,
  });

  @override
  String toString() {
    return 'ScrapedProduct(\n  Name: $name,\n  Price: $price,\n  Currency: $currency,\n  Source: $source,\n  Image: $imageUrl\n)';
  }
}

// Dummy configuration variables
final Map<String, String> _headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
};
final Duration _timeout = Duration(seconds: 10);

// 2. The parser function with debugging prints
Future<ScrapedProduct?> trySearXNG(String query) async {
  final url = Uri.parse(
    'https://cachyos-nitro.tail3d23b7.ts.net:8080/search?q=$query&format=json',
  );

  print('Sending request to Tailscale SearXNG for query: "$query"...');
  print('URL: $url\n');

  try {
    final res = await http.get(url, headers: _headers).timeout(_timeout);
    print('Response status code: ${res.statusCode}');

    if (res.statusCode != 200) {
      print('Error: Non-200 response.');
      return null;
    }

    // Print raw body to inspect exactly what your SearXNG instance sends back
    print('\n[RAW RESPONSE BODY]:');
    print(res.body);
    print('---------------------\n');

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List?;
    if (results == null || results.isEmpty) {
      print('Parser Error: No results array found or it is empty.');
      return null;
    }

    final first = results.first as Map<String, dynamic>;
    final title = first['title'] as String? ?? '';
    if (title.isEmpty) {
      print('Parser Error: First result found, but the title field is empty.');
      return null;
    }

    return ScrapedProduct(
      name: title,
      price: null,
      currency: 'SAR',
      source: 'SearXNG',
      imageUrl: first['img_src'] as String?,
    );
  } catch (e) {
    print('An error or timeout occurred: $e');
    return null;
  }
}

// 3. Execution entry point
void main() async {
  // Swapped to a generic text query to test engine response.
  // Change this back to your barcode once you confirm the instance is pulling results!
  const testQuery = '6281804001262';

  final product = await trySearXNG(testQuery);

  print('--- FINAL RESULT ---');
  if (product != null) {
    print(product);
  } else {
    print('Failed to retrieve or parse product data.');
  }
}
