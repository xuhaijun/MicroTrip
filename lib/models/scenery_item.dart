// ============================================================
// 景点模型（迁移自小程序 subpackages/city/pages/scenery/scenery.js）
// - SceneryItem：景点条目（列表卡片 + 详情通用）
// - NearbyScenery：周边推荐（详情页底部横向列表）
// ============================================================

/// 景点条目
class SceneryItem {
  const SceneryItem({
    required this.id,
    required this.name,
    this.image = '',
    this.rating = 0,
    this.ticket = '',
    this.duration = '',
    this.openTime = '',
    this.tag = '',
    this.tags = const [],
    this.desc = '',
    this.address = '',
    this.latitude = 0,
    this.longitude = 0,
  });

  final int id;
  final String name;

  /// 展示图（当前为 emoji 占位）
  final String image;

  /// 评分（0-5）
  final double rating;

  /// 门票文本，如「免费」/「50元」
  final String ticket;

  /// 建议游玩时长，如「2-3小时」
  final String duration;

  /// 开放时间，如「09:00 - 17:00（周一闭馆）」
  final String openTime;

  /// 列表分类标签（用于筛选）
  final String tag;

  /// 详情标签集合
  final List<String> tags;

  /// 描述
  final String desc;

  /// 地址
  final String address;

  /// 坐标（用于导航）
  final double latitude;
  final double longitude;

  /// 评分文本（保留 1 位小数）
  String get ratingText => rating.toStringAsFixed(1);

  /// 由服务端 JSON 构造（字段与 MicroTripServer /scenery 接口对齐）
  factory SceneryItem.fromJson(Map<String, dynamic> json) => SceneryItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        image: (json['image'] as String?) ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        ticket: (json['ticket'] as String?) ?? '',
        duration: (json['duration'] as String?) ?? '',
        openTime: (json['openTime'] as String?) ?? '',
        tag: (json['tag'] as String?) ?? '',
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        desc: (json['desc'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      );
}

/// 周边推荐（景点详情页「周边逛逛」）
class NearbyScenery {
  const NearbyScenery({
    required this.id,
    required this.name,
    this.image = '',
    this.rating = 0,
    this.distance = '',
  });

  final int id;
  final String name;
  final String image;
  final double rating;
  final String distance;

  /// 由服务端 JSON 构造（字段与 MicroTripServer /scenery/nearby 接口对齐）
  factory NearbyScenery.fromJson(Map<String, dynamic> json) => NearbyScenery(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        image: (json['image'] as String?) ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        distance: (json['distance'] as String?) ?? '',
      );
}
