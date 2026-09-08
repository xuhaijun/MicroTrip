import '../models/city_info.dart';

/// ============================================================
/// 城市静态数据（迁移自小程序 utils/cityData.js / config.js 热门城市）
/// 覆盖全国主要旅游城市，旅游大省重点覆盖。
/// ============================================================
class CityData {
  CityData._();

  /// 热门城市（首页/城市选择页顶部快速入口）
  static const List<Map<String, dynamic>> hotCities = [
    {'name': '北京', 'province': '北京', 'lat': 39.90, 'lng': 116.41},
    {'name': '上海', 'province': '上海', 'lat': 31.23, 'lng': 121.47},
    {'name': '广州', 'province': '广东', 'lat': 23.13, 'lng': 113.26},
    {'name': '深圳', 'province': '广东', 'lat': 22.54, 'lng': 114.06},
    {'name': '成都', 'province': '四川', 'lat': 30.57, 'lng': 104.07},
    {'name': '杭州', 'province': '浙江', 'lat': 30.27, 'lng': 120.15},
    {'name': '重庆', 'province': '重庆', 'lat': 29.56, 'lng': 106.55},
    {'name': '西安', 'province': '陕西', 'lat': 34.34, 'lng': 108.94},
    {'name': '昆明', 'province': '云南', 'lat': 24.88, 'lng': 102.83},
    {'name': '厦门', 'province': '福建', 'lat': 24.48, 'lng': 118.09},
    {'name': '三亚', 'province': '海南', 'lat': 18.25, 'lng': 109.51},
    {'name': '拉萨', 'province': '西藏', 'lat': 29.65, 'lng': 91.14},
    {'name': '哈尔滨', 'province': '黑龙江', 'lat': 45.80, 'lng': 126.53},
    {'name': '青岛', 'province': '山东', 'lat': 36.07, 'lng': 120.38},
    {'name': '苏州', 'province': '江苏', 'lat': 31.30, 'lng': 120.58},
    {'name': '南京', 'province': '江苏', 'lat': 32.06, 'lng': 118.80},
    {'name': '武汉', 'province': '湖北', 'lat': 30.59, 'lng': 114.31},
    {'name': '长沙', 'province': '湖南', 'lat': 28.23, 'lng': 112.94},
    {'name': '贵阳', 'province': '贵州', 'lat': 26.65, 'lng': 106.63},
    {'name': '兰州', 'province': '甘肃', 'lat': 36.06, 'lng': 103.83},
    {'name': '乌鲁木齐', 'province': '新疆', 'lat': 43.83, 'lng': 87.62},
    {'name': '桂林', 'province': '广西', 'lat': 25.28, 'lng': 110.29},
    {'name': '大理', 'province': '云南', 'lat': 25.61, 'lng': 100.27},
    {'name': '张家界', 'province': '湖南', 'lat': 29.12, 'lng': 110.48},
  ];

  /// 按省份分组（城市选择页右侧分组视图）
  static const Map<String, List<String>> provinceCities = {
    '华北': ['北京', '天津', '石家庄', '太原', '呼和浩特', '承德', '秦皇岛'],
    '东北': ['哈尔滨', '长春', '沈阳', '大连', '延吉', '漠河'],
    '华东': ['上海', '杭州', '苏州', '南京', '无锡', '宁波', '温州', '合肥', '黄山',
        '福州', '厦门', '泉州', '南昌', '景德镇', '济南', '青岛', '烟台', '威海',
        '泰安', '曲阜'],
    '华中': ['武汉', '宜昌', '襄阳', '长沙', '张家界', '岳阳', '常德', '郑州', '洛阳',
        '开封', '焦作'],
    '华南': ['广州', '深圳', '珠海', '佛山', '汕头', '湛江', '南宁', '桂林', '北海',
        '海口', '三亚', '万宁'],
    '西南': ['成都', '绵阳', '乐山', '宜宾', '南充', '重庆', '贵阳', '遵义', '昆明',
        '大理', '丽江', '西双版纳', '香格里拉', '拉萨', '林芝', '日喀则'],
    '西北': ['西安', '宝鸡', '咸阳', '汉中', '兰州', '天水', '敦煌', '嘉峪关', '西宁',
        '银川', '中卫', '乌鲁木齐', '吐鲁番', '喀纳斯', '伊犁'],
  };

  /// Map -> CityInfo
  static CityInfo toCity(Map<String, dynamic> m) => CityInfo.fromMap(m);

  /// 城市名 -> CityInfo（优先热门城市表，含坐标）
  static CityInfo cityByName(String name) {
    for (final m in hotCities) {
      if (m['name'] == name) return toCity(m);
    }
    return CityInfo(name: name);
  }

  /// 搜索过滤（热门 + 分组数据合并去重）
  static List<CityInfo> search(String keyword) {
    if (keyword.isEmpty) return allCities;
    return allCities
        .where((c) => c.name.contains(keyword) || c.province.contains(keyword))
        .toList();
  }

  /// 全量城市（热门 + 省份分组去重合并）
  static final List<CityInfo> allCities = _buildAll();

  static List<CityInfo> _buildAll() {
    final seen = <String>{};
    final list = <CityInfo>[];
    for (final m in hotCities) {
      final c = toCity(m);
      if (seen.add(c.name)) list.add(c);
    }
    provinceCities.forEach((province, cities) {
      for (final name in cities) {
        if (seen.add(name)) list.add(CityInfo(name: name, province: province));
      }
    });
    return list;
  }
}
