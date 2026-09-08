/// ============================================================
/// 城市模型
/// 对应小程序存储键 travel_currentCity / travel_recentCities 的结构：
/// { name, province, lat, lng, district, address, adcode }
/// ============================================================
class CityInfo {
  CityInfo({
    required this.name,
    this.province = '',
    this.lat = 0,
    this.lng = 0,
    this.district = '',
    this.address = '',
    this.adcode = '',
  });

  final String name; // 城市名，如「成都」
  final String province; // 省份，如「四川」
  final double lat;
  final double lng;
  final String district; // 区县，如「武侯区」（用于天气精确到区县）
  final String address; // 逆地理推荐地址名
  final String adcode; // 行政区划代码

  factory CityInfo.fromMap(Map<String, dynamic> map) => CityInfo(
        name: map['name']?.toString() ?? '',
        province: map['province']?.toString() ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        district: map['district']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        adcode: map['adcode']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'province': province,
        'lat': lat,
        'lng': lng,
        'district': district,
        'address': address,
        'adcode': adcode,
      };

  /// 展示名：优先「省 · 市」，无省时直接显示市名
  String get displayName =>
      province.isNotEmpty && province != name ? '$province · $name' : name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityInfo &&
          other.name == name &&
          other.district == district &&
          other.adcode == adcode;

  @override
  int get hashCode => Object.hash(name, district, adcode);
}
