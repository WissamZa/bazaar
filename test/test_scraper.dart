import 'dart:io';
import 'dart:convert';

void main() async {
  const testBarcode = '6221143094686';

  // We append country/domain rules right into the query string.
  // This explicitly instructs the search engine indexes to look for Saudi domains (.sa) or Saudi text identifiers.
  final strictQuery = '$testBarcode (site:.sa OR "السعودية" OR "SAR")';

  final url = Uri.parse(
      'https://searxng.home/search?q=${Uri.encodeComponent(strictQuery)}&format=json&locale=ar-SA');

  print('Sending strict Saudi Arabia search request to SearXNG...');

  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.set('Accept', 'application/json');
    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0');

    final response = await request.close();

    if (response.statusCode != 200) {
      print('❌ Request failed with status code: ${response.statusCode}');
      return;
    }

    final responseBody = await response.transform(utf8.decoder).join();

    final Map<String, dynamic> data = jsonDecode(responseBody);
    final List<dynamic> results = data['results'] ?? [];

    // Filter results programmatically to drop obvious UAE links just in case
    final saudiResults = results.where((item) {
      final urlStr = (item['url'] ?? '').toString().toLowerCase();
      // Drop common UAE endpoints if they sneak through
      if (urlStr.contains('.ae') || urlStr.contains('/uae')) {
        return false;
      }
      return true;
    }).toList();

    if (saudiResults.isNotEmpty) {
      print('\n🎉 Successfully parsed matching Saudi item!');
      print('--------------------------------------------------');

      final Map<String, dynamic> firstItem =
          saudiResults.first as Map<String, dynamic>;

      String title = firstItem['title'] ?? 'Unknown Product';
      final String productUrl = firstItem['url'] ?? 'No URL';
      final String description = firstItem['content'] ?? '';
      final String engine = firstItem['engine'] ?? 'unknown';

      if (title.trim() == 'بلا عنوان' ||
          title.toLowerCase().contains('debug mode')) {
        title = "Product associated with barcode $testBarcode";
      }

      String price = 'Price hidden or unavailable';
      if (firstItem.containsKey('price')) {
        price = "${firstItem['price']} SAR";
      } else {
        final arabicPriceMatch =
            RegExp(r'(?:السعر|سعر)\s*(?:\d+)?\s*(\d+(?:\.\d+)?)')
                .firstMatch(description);
        final englishPriceMatch = RegExp(
                r'(\d+(?:\.\d+)?\s*SAR|SAR\s*\d+(?:\.\d+)?)',
                caseSensitive: false)
            .firstMatch(description);

        if (arabicPriceMatch != null) {
          price = "${arabicPriceMatch.group(1)} SAR";
        } else if (englishPriceMatch != null) {
          price = englishPriceMatch.group(0) ?? price;
        }
      }

      print('📦 Product Title : $title');
      print('💰 Extracted Price: $price');
      print('🔗 Target URL    : $productUrl');
      print('📝 Description   : $description');
      print('⚙️ Source Engine  : $engine');
      print('--------------------------------------------------');
    } else {
      print(
          '\n❌ No strict Saudi results returned from SearXNG for barcode: $testBarcode.');
    }
  } catch (e) {
    print('Engine connection error: $e');
  } finally {
    client.close();
  }
}
