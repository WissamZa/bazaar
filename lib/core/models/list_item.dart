/// M2M bridge: a [ShoppingList] contains an [Item] with a quantity, optional
/// preferred store, free-form note, and a "got it" flag.
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

  ListItem copyWith({
    int? id,
    int? listId,
    int? itemId,
    int? quantity,
    bool? isChecked,
    int? preferredStoreId,
    String? note,
  }) {
    return ListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
      preferredStoreId: preferredStoreId ?? this.preferredStoreId,
      note: note ?? this.note,
    );
  }

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
    return ListItem(
      id: json['id'] as int?,
      listId: (json['list_id'] as num?)?.toInt() ??
          (json['listId'] as num?)?.toInt() ??
          0,
      itemId: (json['item_id'] as num?)?.toInt() ??
          (json['itemId'] as num?)?.toInt() ??
          0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isChecked: ((json['is_checked'] ?? json['isChecked']) ?? 0) == 1 ||
          ((json['is_checked'] ?? json['isChecked']) == true),
      preferredStoreId: (json['preferred_store_id'] as num?)?.toInt() ??
          (json['preferredStoreId'] as num?)?.toInt(),
      note: json['note'] as String?,
    );
  }

  factory ListItem.fromDb(Map<String, dynamic> row) {
    return ListItem(
      id: row['id'] as int?,
      listId: row['list_id'] as int,
      itemId: row['item_id'] as int,
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
      isChecked: (row['is_checked'] as int?) == 1,
      preferredStoreId: row['preferred_store_id'] as int?,
      note: row['note'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'list_id': listId,
        'item_id': itemId,
        'quantity': quantity,
        'is_checked': isChecked ? 1 : 0,
        'preferred_store_id': preferredStoreId,
        'note': note,
      };
}
