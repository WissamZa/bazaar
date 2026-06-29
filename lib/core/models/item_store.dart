import '../../core/constants/currencies.dart';

/// M2M bridge: same [Item] sold at a [Store] for a particular price.
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

  ItemStore copyWith({
    int? id,
    int? itemId,
    int? storeId,
    double? price,
    AppCurrency? currency,
    String? url,
  }) {
    return ItemStore(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      storeId: storeId ?? this.storeId,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'store_id': storeId,
        'price': price,
        'currency': currency.code,
        'url': url,
      };

  factory ItemStore.fromJson(Map<String, dynamic> json) {
    return ItemStore(
      id: json['id'] as int?,
      itemId: (json['item_id'] as num?)?.toInt() ??
          (json['itemId'] as num?)?.toInt() ??
          0,
      storeId: (json['store_id'] as num?)?.toInt() ??
          (json['storeId'] as num?)?.toInt() ??
          0,
      price: (json['price'] as num?)?.toDouble(),
      currency: CurrencyExtension.fromCode(
        (json['currency'] as String?) ?? 'SAR',
      ),
      url: json['url'] as String?,
    );
  }

  factory ItemStore.fromDb(Map<String, dynamic> row) {
    return ItemStore(
      id: row['id'] as int?,
      itemId: row['item_id'] as int,
      storeId: row['store_id'] as int,
      price: (row['price'] as num?)?.toDouble(),
      currency: CurrencyExtension.fromCode(
        (row['currency'] as String?) ?? 'SAR',
      ),
      url: row['url'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'store_id': storeId,
        'price': price,
        'currency': currency.code,
        'url': url,
      };
}
