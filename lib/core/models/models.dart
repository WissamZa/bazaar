import '../constants/currencies.dart';
import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart'
    show
        ItemsCompanion,
        StoresCompanion,
        CategoriesCompanion,
        ShoppingListsCompanion,
        ListItemsCompanion,
        ItemStoresCompanion,
        ItemRow,
        StoreRow,
        CategoryRow,
        ShoppingListRow,
        ListItemRow,
        ItemStoreRow,
        PriceHistoryRow;

/// Domain entities with **byte-compatible JSON** for the v1.x wire formats
/// (share/import v2 list format, backup ZIP table dumps). The keys below
/// are the compatibility contract — do not rename them.
///
/// Each entity also maps to/from its drift row ([ItemRow] etc.), which is
/// the on-disk format. JSON models are only used at the import/export/
/// backup boundary; the UI and DAOs speak rows.

class Item {
  final int? id;
  final String? barcode;
  final String? brand;
  final String nameEn;
  final String? nameAr;
  final String? note;
  final double? price;
  final AppCurrency currency;
  final String? imageUrl;
  final int? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Item({
    this.id,
    this.barcode,
    this.brand,
    required this.nameEn,
    this.nameAr,
    this.note,
    this.price,
    this.currency = AppCurrency.sar,
    this.imageUrl,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Localised display name for [localeCode], falling back to the other
  /// language when the preferred one is missing.
  String displayName(String localeCode) {
    final en = nameEn.trim();
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar') {
      if (ar.isNotEmpty) return ar;
      return en;
    }
    if (en.isNotEmpty) return en;
    return ar;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'barcode': barcode,
    'brand': brand,
    'name_en': nameEn,
    'name_ar': nameAr,
    'note': note,
    'price': price,
    'currency': currency.code,
    'image_url': imageUrl,
    'category_id': categoryId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Item.fromJson(Map<String, dynamic> json) {
    final created =
        (json['created_at'] as String?) ??
        (json['createdAt'] as String?) ??
        DateTime.now().toIso8601String();
    final updated =
        (json['updated_at'] as String?) ??
        (json['updatedAt'] as String?) ??
        created;
    return Item(
      id: (json['id'] as num?)?.toInt(),
      barcode: json['barcode'] as String?,
      brand: json['brand'] as String?,
      nameEn: ((json['name_en'] ?? json['nameEn']) as String?) ?? '',
      nameAr: (json['name_ar'] ?? json['nameAr']) as String?,
      note: json['note'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      currency: currencyFromCode((json['currency'] as String?) ?? 'SAR'),
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      categoryId: (json['category_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(created) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updated) ?? DateTime.now(),
    );
  }

  factory Item.fromRow(ItemRow row) => Item(
    id: row.id,
    barcode: row.barcode,
    brand: row.brand,
    nameEn: row.nameEn,
    nameAr: row.nameAr,
    note: row.note,
    price: row.price,
    currency: currencyFromCode(row.currency),
    imageUrl: row.imageUrl,
    categoryId: row.categoryId,
    createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
    updatedAt: DateTime.tryParse(row.updatedAt) ?? DateTime.now(),
  );

  ItemsCompanion toInsertCompanion() => ItemsCompanion.insert(
    nameEn: nameEn,
    createdAt: createdAt.toIso8601String(),
    updatedAt: updatedAt.toIso8601String(),
    barcode: Value((barcode?.isEmpty ?? true) ? null : barcode),
    brand: Value(brand),
    nameAr: Value(nameAr),
    note: Value(note),
    price: Value(price),
    currency: Value(currency.code),
    imageUrl: Value(imageUrl),
    categoryId: Value(categoryId),
  );

  Item copyWith({
    Object? id = _sentinel,
    Object? barcode = _sentinel,
    String? brand,
    String? nameEn,
    Object? nameAr = _sentinel,
    Object? note = _sentinel,
    double? price,
    AppCurrency? currency,
    Object? imageUrl = _sentinel,
    Object? categoryId = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Item(
    id: id == _sentinel ? this.id : id as int?,
    barcode: barcode == _sentinel ? this.barcode : barcode as String?,
    brand: brand ?? this.brand,
    nameEn: nameEn ?? this.nameEn,
    nameAr: nameAr == _sentinel ? this.nameAr : nameAr as String?,
    note: note == _sentinel ? this.note : note as String?,
    price: price ?? this.price,
    currency: currency ?? this.currency,
    imageUrl: imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
    categoryId: categoryId == _sentinel ? this.categoryId : categoryId as int?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static const _sentinel = Object();
}

class Store {
  final int? id;
  final String name;
  final String? nameAr;
  final String? website;
  final String? address;
  final String? imageUrl;
  final DateTime createdAt;

  const Store({
    this.id,
    required this.name,
    this.nameAr,
    this.website,
    this.address,
    this.imageUrl,
    required this.createdAt,
  });

  String displayName(String localeCode) {
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar' && ar.isNotEmpty) return ar;
    return name;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ar': nameAr,
    'website': website,
    'address': address,
    'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
  };

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: (json['id'] as num?)?.toInt(),
    name: (json['name'] as String?) ?? '',
    nameAr: (json['name_ar'] ?? json['nameAr']) as String?,
    website: json['website'] as String?,
    address: json['address'] as String?,
    imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
    createdAt:
        DateTime.tryParse(
          (json['created_at'] ?? json['createdAt']) as String? ?? '',
        ) ??
        DateTime.now(),
  );

  factory Store.fromRow(StoreRow row) => Store(
    id: row.id,
    name: row.name,
    nameAr: row.nameAr,
    website: row.website,
    address: row.address,
    imageUrl: row.imageUrl,
    createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
  );

  StoresCompanion toInsertCompanion() => StoresCompanion.insert(
    name: name,
    createdAt: createdAt.toIso8601String(),
    nameAr: Value(nameAr),
    website: Value(website),
    address: Value(address),
    imageUrl: Value(imageUrl),
  );
}

class Category {
  final int? id;
  final String name;
  final String? nameAr;
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    this.nameAr,
    required this.createdAt,
  });

  String displayName(String localeCode) {
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar' && ar.isNotEmpty) return ar;
    return name;
  }

  Category copyWith({String? name, String? nameAr}) => Category(
    id: id,
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ar': nameAr,
    'created_at': createdAt.toIso8601String(),
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['id'] as num?)?.toInt(),
    name: (json['name'] as String?) ?? '',
    nameAr: (json['name_ar'] ?? json['nameAr']) as String?,
    createdAt:
        DateTime.tryParse(
          (json['created_at'] ?? json['createdAt']) as String? ?? '',
        ) ??
        DateTime.now(),
  );

  factory Category.fromRow(CategoryRow row) => Category(
    id: row.id,
    name: row.name,
    nameAr: row.nameAr,
    createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
  );

  CategoriesCompanion toInsertCompanion() => CategoriesCompanion.insert(
    name: name,
    createdAt: createdAt.toIso8601String(),
    nameAr: Value(nameAr),
  );

  CategoriesCompanion toUpdateCompanion() =>
      CategoriesCompanion(name: Value(name), nameAr: Value(nameAr));
}

class ShoppingList {
  final int? id;
  final String name;
  final String? nameAr;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingList({
    this.id,
    required this.name,
    this.nameAr,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
  });

  String displayName(String localeCode) {
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar' && ar.isNotEmpty) return ar;
    return name;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ar': nameAr,
    'owner': owner,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final created =
        (json['created_at'] as String?) ??
        (json['createdAt'] as String?) ??
        now.toIso8601String();
    final updated =
        (json['updated_at'] as String?) ??
        (json['updatedAt'] as String?) ??
        created;
    return ShoppingList(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name'] as String?) ?? '',
      nameAr: (json['name_ar'] ?? json['nameAr']) as String?,
      owner: (json['owner'] as String?) ?? '',
      createdAt: DateTime.tryParse(created) ?? now,
      updatedAt: DateTime.tryParse(updated) ?? now,
    );
  }

  factory ShoppingList.fromRow(ShoppingListRow row) => ShoppingList(
    id: row.id,
    name: row.name,
    nameAr: row.nameAr,
    owner: row.owner,
    createdAt: DateTime.tryParse(row.createdAt) ?? DateTime.now(),
    updatedAt: DateTime.tryParse(row.updatedAt) ?? DateTime.now(),
  );

  ShoppingListsCompanion toInsertCompanion() => ShoppingListsCompanion.insert(
    name: name,
    owner: owner,
    createdAt: createdAt.toIso8601String(),
    updatedAt: updatedAt.toIso8601String(),
    nameAr: Value(nameAr),
  );

  ShoppingList copyWith({
    int? id,
    String? name,
    String? nameAr,
    String? owner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ShoppingList(
    id: id ?? this.id,
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    owner: owner ?? this.owner,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class ListItem {
  final int? id;
  final int listId;
  final int itemId;
  final int quantity;
  final bool isChecked;
  final int? preferredStoreId;
  final String? note;

  const ListItem({
    this.id,
    required this.listId,
    required this.itemId,
    this.quantity = 1,
    this.isChecked = false,
    this.preferredStoreId,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'list_id': listId,
    'item_id': itemId,
    'quantity': quantity,
    'is_checked': isChecked ? 1 : 0,
    'preferred_store_id': preferredStoreId,
    'note': note,
  };

  factory ListItem.fromJson(Map<String, dynamic> json) {
    final checkedRaw = (json['is_checked'] ?? json['isChecked']) ?? 0;
    return ListItem(
      id: (json['id'] as num?)?.toInt(),
      listId: ((json['list_id'] ?? json['listId']) as num?)?.toInt() ?? 0,
      itemId: ((json['item_id'] ?? json['itemId']) as num?)?.toInt() ?? 0,
      quantity: ((json['quantity']) as num?)?.toInt() ?? 1,
      isChecked: checkedRaw == 1 || checkedRaw == true,
      preferredStoreId:
          ((json['preferred_store_id'] ?? json['preferredStoreId']) as num?)
              ?.toInt(),
      note: json['note'] as String?,
    );
  }

  factory ListItem.fromRow(ListItemRow row) => ListItem(
    id: row.id,
    listId: row.listId,
    itemId: row.itemId,
    quantity: row.quantity,
    isChecked: row.isChecked == 1,
    preferredStoreId: row.preferredStoreId,
    note: row.note,
  );

  ListItemsCompanion toInsertCompanion() => ListItemsCompanion.insert(
    listId: listId,
    itemId: itemId,
    quantity: Value(quantity),
    isChecked: Value(isChecked ? 1 : 0),
    preferredStoreId: Value(preferredStoreId),
    note: Value(note),
  );

  ListItem copyWith({
    int? id,
    int? listId,
    int? itemId,
    int? quantity,
    bool? isChecked,
    int? preferredStoreId,
    String? note,
  }) => ListItem(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    itemId: itemId ?? this.itemId,
    quantity: quantity ?? this.quantity,
    isChecked: isChecked ?? this.isChecked,
    preferredStoreId: preferredStoreId ?? this.preferredStoreId,
    note: note ?? this.note,
  );
}

class ItemStore {
  final int? id;
  final int itemId;
  final int storeId;
  final double? price;
  final AppCurrency currency;
  final String? url;

  const ItemStore({
    this.id,
    required this.itemId,
    required this.storeId,
    this.price,
    this.currency = AppCurrency.sar,
    this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'store_id': storeId,
    'price': price,
    'currency': currency.code,
    'url': url,
  };

  factory ItemStore.fromJson(Map<String, dynamic> json) => ItemStore(
    id: (json['id'] as num?)?.toInt(),
    itemId: ((json['item_id'] ?? json['itemId']) as num?)?.toInt() ?? 0,
    storeId: ((json['store_id'] ?? json['storeId']) as num?)?.toInt() ?? 0,
    price: (json['price'] as num?)?.toDouble(),
    currency: currencyFromCode((json['currency'] as String?) ?? 'SAR'),
    url: json['url'] as String?,
  );

  factory ItemStore.fromRow(ItemStoreRow row) => ItemStore(
    id: row.id,
    itemId: row.itemId,
    storeId: row.storeId,
    price: row.price,
    currency: currencyFromCode(row.currency),
    url: row.url,
  );

  ItemStoresCompanion toInsertCompanion() => ItemStoresCompanion.insert(
    itemId: itemId,
    storeId: storeId,
    price: Value(price),
    currency: Value(currency.code),
    url: Value(url),
  );
}

class PricePoint {
  final int? id;
  final int itemStoreId;
  final double? price;
  final AppCurrency currency;
  final DateTime recordedAt;

  const PricePoint({
    this.id,
    required this.itemStoreId,
    this.price,
    this.currency = AppCurrency.sar,
    required this.recordedAt,
  });

  factory PricePoint.fromRow(PriceHistoryRow row) => PricePoint(
    id: row.id,
    itemStoreId: row.itemStoreId,
    price: row.price,
    currency: currencyFromCode(row.currency),
    recordedAt: DateTime.tryParse(row.recordedAt) ?? DateTime.now(),
  );
}

/// Display-name convenience on drift rows — keeps screens terse while the
/// localisation rules live in the model layer.
extension ItemRowDisplay on ItemRow {
  String displayName(String localeCode) =>
      Item.fromRow(this).displayName(localeCode);
}

extension StoreRowDisplay on StoreRow {
  String displayName(String localeCode) =>
      Store.fromRow(this).displayName(localeCode);
}

extension CategoryRowDisplay on CategoryRow {
  String displayName(String localeCode) =>
      Category.fromRow(this).displayName(localeCode);
}

extension ShoppingListRowDisplay on ShoppingListRow {
  String displayName(String localeCode) =>
      ShoppingList.fromRow(this).displayName(localeCode);
}
