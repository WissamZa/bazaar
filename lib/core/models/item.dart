import '../../core/constants/currencies.dart';

/// A product with an optional barcode, bilingual name, and price.
///
/// At least one of [nameEn] or [nameAr] MUST be non-empty; the other is
/// optional. Validation is enforced in the Add/Edit form, not in the model.
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
  /// The store whose price should be shown as the item's "main" price in
  /// the items list. NULL means "no preference" — the UI falls back to the
  /// lowest available store price.
  final int? preferredStoreId;
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
    this.preferredStoreId,
    required this.createdAt,
    required this.updatedAt,
  });

  Item copyWith({
    int? id,
    String? barcode,
    String? brand,
    String? nameEn,
    String? nameAr,
    String? note,
    double? price,
    AppCurrency? currency,
    String? imageUrl,
    int? categoryId,
    int? preferredStoreId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      note: note ?? this.note,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      // Use the param if explicitly passed, otherwise keep existing.
      // Note: copyWith can't distinguish "null was passed" from "not passed"
      // with nullable types — so passing null here KEEPS the existing value.
      // Use clearPreferredStoreId() to explicitly clear it.
      preferredStoreId: preferredStoreId ?? this.preferredStoreId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy with preferredStoreId explicitly set to null.
  /// (copyWith can't distinguish "null was passed" from "not passed".)
  Item clearPreferredStoreId() => Item(
        id: id,
        barcode: barcode,
        brand: brand,
        nameEn: nameEn,
        nameAr: nameAr,
        note: note,
        price: price,
        currency: currency,
        imageUrl: imageUrl,
        categoryId: categoryId,
        preferredStoreId: null,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Returns the localised name for the active locale, falling back to the
  /// other language if the localised one is missing.
  String displayName(String localeCode) {
    final en = nameEn.trim();
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar') {
      if (ar.isNotEmpty) return ar;
      if (en.isNotEmpty) return en;
    } else {
      if (en.isNotEmpty) return en;
      if (ar.isNotEmpty) return ar;
    }
    return en.isEmpty ? ar : en;
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
        'preferred_store_id': preferredStoreId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as int?,
      barcode: json['barcode'] as String?,
      brand: json['brand'] as String?,
      nameEn: (json['name_en'] as String?) ?? (json['nameEn'] as String?) ?? '',
      nameAr: json['name_ar'] as String? ?? json['nameAr'] as String?,
      note: json['note'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      currency: CurrencyExtension.fromCode(
        (json['currency'] as String?) ?? 'SAR',
      ),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      categoryId: json['category_id'] as int?,
      preferredStoreId: (json['preferred_store_id'] as num?)?.toInt() ??
          (json['preferredStoreId'] as num?)?.toInt(),
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] as String?) ??
            json['updatedAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  factory Item.fromDb(Map<String, dynamic> row) {
    return Item(
      id: row['id'] as int?,
      barcode: row['barcode'] as String?,
      brand: row['brand'] as String?,
      nameEn: row['name_en'] as String,
      nameAr: row['name_ar'] as String?,
      note: row['note'] as String?,
      price: (row['price'] as num?)?.toDouble(),
      currency: CurrencyExtension.fromCode(
        (row['currency'] as String?) ?? 'SAR',
      ),
      imageUrl: row['image_url'] as String?,
      categoryId: row['category_id'] as int?,
      preferredStoreId: (row['preferred_store_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'barcode': barcode,
        'brand': brand,
        'name_en': nameEn,
        'name_ar': nameAr,
        'note': note,
        'price': price,
        'currency': currency.code,
        'image_url': imageUrl,
        'category_id': categoryId,
        'preferred_store_id': preferredStoreId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
