/// ============================================================
/// 收藏模型（美食 / 景点通用）
/// 对应小程序存储键 travel_favoriteFood / travel_favoriteScenery
/// ============================================================
enum FavoriteType { food, scenery }

class FavoriteItem {
  FavoriteItem({
    required this.id,
    required this.type,
    required this.name,
    this.image = '',
    this.desc = '',
    this.address = '',
    this.rating = '',
    this.city = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final FavoriteType type;
  final String name;
  final String image; // 图片 URL（可为空，UI 用渐变占位）
  final String desc;
  final String address;
  final String rating;
  final String city;
  final DateTime createdAt;

  factory FavoriteItem.fromMap(Map<String, dynamic> map, {required FavoriteType type}) =>
      FavoriteItem(
        id: map['id']?.toString() ?? '',
        type: type,
        name: map['name']?.toString() ?? '',
        image: map['image']?.toString() ?? '',
        desc: map['desc']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        rating: map['rating']?.toString() ?? '',
        city: map['city']?.toString() ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'image': image,
        'desc': desc,
        'address': address,
        'rating': rating,
        'city': city,
        'createdAt': createdAt.toIso8601String(),
      };
}
