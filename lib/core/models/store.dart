/// A retail store (e.g. Amazon SA, Noon, Panda, Carrefour).
///
/// Only [name] is required; [nameAr], [website], and [address] are optional.
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

  Store copyWith({
    int? id,
    String? name,
    String? nameAr,
    String? website,
    String? address,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      website: website ?? this.website,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns the localised name for the active locale, falling back to the
  /// other language if the localised one is missing.
  String displayName(String localeCode) {
    final en = name.trim();
    final ar = nameAr?.trim() ?? '';
    if (localeCode == 'ar') {
      if (ar.isNotEmpty) return ar;
      if (en.isNotEmpty) return en;
    } else {
      if (en.isNotEmpty) return en;
      if (ar.isNotEmpty) return ar;
    }
    return en;
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

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int?,
      name: (json['name'] as String?) ?? '',
      nameAr: json['name_ar'] as String? ?? json['nameAr'] as String?,
      website: json['website'] as String?,
      address: json['address'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  factory Store.fromDb(Map<String, dynamic> row) {
    return Store(
      id: row['id'] as int?,
      name: row['name'] as String,
      nameAr: row['name_ar'] as String?,
      website: row['website'] as String?,
      address: row['address'] as String?,
      imageUrl: row['image_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'name': name,
        'name_ar': nameAr,
        'website': website,
        'address': address,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
