import 'package:bazaar/core/constants/currencies.dart';
import 'package:bazaar/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wire-format compatibility: the JSON keys here are consumed by v1.x apps
/// (and produced by them) — renaming a key silently breaks cross-version
/// import/export.
void main() {
  test('Item JSON round-trip keeps the v1 keys', () {
    final item = Item(
      id: 1,
      barcode: '6281000000015',
      brand: 'Almarai',
      nameEn: 'Milk 1L',
      nameAr: 'حليب',
      price: 6.5,
      currency: AppCurrency.sar,
      createdAt: DateTime.parse('2026-01-01T10:00:00.000'),
      updatedAt: DateTime.parse('2026-01-02T10:00:00.000'),
    );
    final json = item.toJson();
    expect(json.keys, containsAll([
      'barcode', 'brand', 'name_en', 'name_ar', 'price', 'currency',
      'image_url', 'category_id', 'created_at', 'updated_at',
    ]));

    final back = Item.fromJson(json);
    expect(back.barcode, item.barcode);
    expect(back.nameEn, item.nameEn);
    expect(back.nameAr, item.nameAr);
    expect(back.price, item.price);
    expect(back.currency, item.currency);
    expect(back.createdAt, item.createdAt);
  });

  test('Store / ShoppingList / ListItem JSON keep the v1 keys', () {
    final storeJson = Store(
      id: 3,
      name: 'Panda',
      nameAr: 'بندة',
      createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
    ).toJson();
    expect(storeJson['name_ar'], 'بندة');
    final storeBack = Store.fromJson(storeJson);
    expect(storeBack.nameAr, 'بندة');

    final listJson = ShoppingList(
      id: 9,
      name: 'Weekly',
      owner: 'wissam',
      createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00.000'),
    ).toJson();
    expect(listJson['owner'], 'wissam');
    final listBack = ShoppingList.fromJson(listJson);
    expect(listBack.name, 'Weekly');

    final liJson = ListItem(
      id: 11,
      listId: 9,
      itemId: 1,
      quantity: 3,
      isChecked: true,
      preferredStoreId: 3,
    ).toJson();
    expect(liJson['is_checked'], 1);
    expect(liJson['preferred_store_id'], 3);
    final liBack = ListItem.fromJson(liJson);
    expect(liBack.isChecked, isTrue);
    expect(liBack.quantity, 3);
  });

  test('v1 fallback keys (camelCase) still parse', () {
    final item = Item.fromJson({
      'barcode': '1',
      'nameEn': 'Tea',
      'nameAr': 'شاي',
      'price': 3,
      'currency': 'SAR',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    expect(item.nameEn, 'Tea');
    expect(item.nameAr, 'شاي');

    final li = ListItem.fromJson({
      'listId': 1,
      'itemId': 2,
      'isChecked': true,
    });
    expect(li.isChecked, isTrue);
  });

  test('display name falls back across languages', () {
    final item = Item(
      nameEn: 'Rice',
      nameAr: 'أرز',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(item.displayName('ar'), 'أرز');
    expect(item.displayName('en'), 'Rice');
    expect(
        Item(
          nameEn: 'Rice',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).displayName('ar'),
        'Rice');
  });
}
