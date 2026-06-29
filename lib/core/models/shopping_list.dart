/// A named collection of items belonging to a single user (identified by
/// the locally-stored username).
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

  ShoppingList copyWith({
    int? id,
    String? name,
    String? nameAr,
    String? owner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String displayName(String localeCode) {
    if (localeCode == 'ar' && (nameAr?.isNotEmpty ?? false)) {
      return nameAr!;
    }
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
    return ShoppingList(
      id: json['id'] as int?,
      name: (json['name'] as String?) ?? '',
      nameAr: json['name_ar'] as String? ?? json['nameAr'] as String?,
      owner: (json['owner'] as String?) ?? 'local',
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

  factory ShoppingList.fromDb(Map<String, dynamic> row) {
    return ShoppingList(
      id: row['id'] as int?,
      name: row['name'] as String,
      nameAr: row['name_ar'] as String?,
      owner: row['owner'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'name': name,
        'name_ar': nameAr,
        'owner': owner,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
