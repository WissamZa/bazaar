import 'package:flutter/material.dart';
import '../constants/currencies.dart';

class ItemPriceHistory {
  final int? id;
  final int itemStoreId;
  final double price;
  final AppCurrency currency;
  final DateTime recordedAt;

  const ItemPriceHistory({
    this.id,
    required this.itemStoreId,
    required this.price,
    required this.currency,
    required this.recordedAt,
  });

  ItemPriceHistory copyWith({
    int? id,
    int? itemStoreId,
    double? price,
    AppCurrency? currency,
    DateTime? recordedAt,
  }) {
    return ItemPriceHistory(
      id: id ?? this.id,
      itemStoreId: itemStoreId ?? this.itemStoreId,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_store_id': itemStoreId,
        'price': price,
        'currency': currency.code,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory ItemPriceHistory.fromJson(Map<String, dynamic> json) {
    return ItemPriceHistory(
      id: json['id'] as int?,
      itemStoreId: (json['item_store_id'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: CurrencyExtension.fromCode(
        (json['currency'] as String?) ?? 'SAR',
      ),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  factory ItemPriceHistory.fromDb(Map<String, dynamic> row) {
    return ItemPriceHistory(
      id: row['id'] as int?,
      itemStoreId: row['item_store_id'] as int,
      price: (row['price'] as num?)?.toDouble() ?? 0.0,
      currency: CurrencyExtension.fromCode(
        (row['currency'] as String?) ?? 'SAR',
      ),
      recordedAt: DateTime.parse(row['recorded_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'item_store_id': itemStoreId,
        'price': price,
        'currency': currency.code,
        'recorded_at': recordedAt.toIso8601String(),
      };
}
