import 'package:intl/intl.dart';

class Category {
  final int? id;
  final String name;
  final String? nameAr;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    this.nameAr,
    required this.createdAt,
  });

  Category copyWith({
    int? id,
    String? name,
    String? nameAr,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'created_at': createdAt.toIso8601String(),
      };

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  factory Category.fromDb(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as int?,
      name: row['name'] as String,
      nameAr: row['name_ar'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'name': name,
        'name_ar': nameAr,
        'created_at': createdAt.toIso8601String(),
      };

  String displayName(String localeCode) {
    if (localeCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    return name;
  }
}
