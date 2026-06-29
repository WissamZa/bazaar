import 'package:flutter_test/flutter_test.dart';

import 'package:bazaar/core/models/item.dart';
import 'package:bazaar/core/models/store.dart';
import 'package:bazaar/core/models/shopping_list.dart';
import 'package:bazaar/core/models/list_item.dart';

void main() {
  group('Item toJson / fromJson round-trip', () {
    test('preserves all fields', () {
      final now = DateTime.utc(2025, 1, 1);
      final a = Item(
        id: 7,
        barcode: '6281007021234',
        nameEn: 'Milk 1L',
        nameAr: 'حليب 1 لتر',
        price: 5.75,
        imageUrl: 'https://example.com/milk.png',
        createdAt: now,
        updatedAt: now,
      );
      final json = a.toJson();
      final b = Item.fromJson(json);
      expect(b.id, a.id);
      expect(b.barcode, a.barcode);
      expect(b.nameEn, a.nameEn);
      expect(b.nameAr, a.nameAr);
      expect(b.price, a.price);
      expect(b.imageUrl, a.imageUrl);
    });

    test('displayName falls back to English when AR is null', () {
      final a = Item(
        nameEn: 'Bread',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(a.displayName('ar'), 'Bread');
    });
  });

  group('Store', () {
    test('round-trip', () {
      final s = Store(
        id: 1,
        name: 'Panda',
        nameAr: 'بنده',
        website: 'https://pandamart.com',
        createdAt: DateTime.utc(2024, 6, 1),
      );
      expect(Store.fromJson(s.toJson()).name, 'Panda');
    });
  });

  group('ShoppingList + ListItem', () {
    test('round-trip', () {
      final now = DateTime.now();
      final list = ShoppingList(
        id: 3,
        name: 'Weekly',
        nameAr: 'أسبوعي',
        owner: 'sara',
        createdAt: now,
        updatedAt: now,
      );
      expect(ShoppingList.fromJson(list.toJson()).owner, 'sara');

      const li = ListItem(
        id: 1,
        listId: 3,
        itemId: 7,
        quantity: 2,
        isChecked: true,
        note: 'low fat',
      );
      final rt = ListItem.fromJson(li.toJson());
      expect(rt.quantity, 2);
      expect(rt.isChecked, true);
      expect(rt.note, 'low fat');
    });
  });
}
