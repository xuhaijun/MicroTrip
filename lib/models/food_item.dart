// ============================================================
// 美食模型（迁移自小程序 subpackages/city/pages/food/food.js）
// - FoodItem：美食条目（列表卡片 + 详情通用）
// - FoodShop：推荐店铺（详情页内展示，含模拟坐标）
// ============================================================

/// 美食条目
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    this.image = '',
    this.rating = 0,
    this.price = '',
    this.tag = '',
    this.tags = const [],
    this.desc = '',
    this.tips = '',
  });

  final int id;
  final String name;

  /// 展示图（当前为 emoji 占位，未来可换网络图片 URL）
  final String image;

  /// 评分（0-5）
  final double rating;

  /// 价格区间文本，如「15-30元」
  final String price;

  /// 列表分类标签（用于筛选）
  final String tag;

  /// 详情标签集合
  final List<String> tags;

  /// 描述
  final String desc;

  /// 小贴士
  final String tips;

  /// 评分文本（保留 1 位小数）
  String get ratingText => rating.toStringAsFixed(1);

  /// 评分星级描述（半星用 ± 近似，用于详情页视觉）
  String get starText {
    final full = rating.floor();
    final half = (rating - full) >= 0.25 && (rating - full) < 0.75;
    final empty = 5 - full - (half ? 1 : 0);
    return '★' * full + (half ? '☆' : '') + '☆' * empty;
  }

  /// 由服务端 JSON 构造（字段与 MicroTripServer /food 接口对齐）
  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        image: (json['image'] as String?) ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        price: (json['price'] as String?) ?? '',
        tag: (json['tag'] as String?) ?? '',
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        desc: (json['desc'] as String?) ?? '',
        tips: (json['tips'] as String?) ?? '',
      );
}

/// 推荐店铺（美食详情页「去哪吃」）
class FoodShop {
  const FoodShop({
    required this.id,
    required this.name,
    this.rating = 0,
    this.distance = '',
    this.avgPrice = '',
    this.address = '',
    this.latitude = 0,
    this.longitude = 0,
  });

  final int id;
  final String name;
  final double rating;
  final String distance;
  final String avgPrice;
  final String address;
  final double latitude;
  final double longitude;

  /// 由服务端 JSON 构造（字段与 MicroTripServer /food/shops 接口对齐）
  factory FoodShop.fromJson(Map<String, dynamic> json) => FoodShop(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        distance: (json['distance'] as String?) ?? '',
        avgPrice: (json['avgPrice'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      );
}
