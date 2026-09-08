import '../core/config/data_config.dart';
import '../core/http/http_client.dart';
import '../models/food_item.dart';
import '../services/auth_service.dart';

/// ============================================================
/// 美食服务（迁移自小程序 subpackages/city/pages/food/food.js）
///
/// 数据源由「模拟数据总开关」[DataConfig.useMockData] 决定：
///  - 开关开启（默认）或 未配置后端地址 → 使用 App 内置示例数据（离线可用）；
///  - 开关关闭且已配置 [AuthService.serverUrl] → 从服务端拉取真实数据；
///  - 请求失败自动降级为本地示例数据。
///
/// 服务端接口（MicroTripServer）：
///  - GET {apiBase}/food/list?city=xxx      → { list: [FoodItem] }
///  - GET {apiBase}/food/detail/:id?city=xxx → { item: FoodItem }
///  - GET {apiBase}/food/shops?city=xxx      → { list: [FoodShop] }（推荐门店，详情页「去哪吃」）
///
/// 推荐门店同样走「模拟数据总开关」：开关开启或无后端地址时用本地示例，
/// 关闭且已配置后端时从服务端拉取，失败自动降级本地示例。
/// ============================================================

/// 数据来源包装：携带 [fromServer] 便于 UI 展示「本地模拟 / 服务端」
class FoodResult<T> {
  const FoodResult(this.data, this.fromServer);
  final T data;
  final bool fromServer;
}

class FoodService {
  FoodService._();

  /// 服务端响应缓存时长（城市维度静态数据，10 分钟内复用，减少服务端请求）
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// 是否应走本地模拟（开关开，或未配置后端地址）
  static bool _shouldUseMock({bool? mock}) =>
      (mock ?? DataConfig.useMockData) || AuthService.serverUrl.isEmpty;

  /// 获取美食列表（异步；按开关决定 mock / server）
  static Future<FoodResult<List<FoodItem>>> fetchList(String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return FoodResult(_mockItems(city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/food/list',
        query: {'city': city},
        cacheKey: 'food_list_$city',
        ttl: _cacheTtl,
      );
      final list = (resp['list'] as List? ?? [])
          .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return FoodResult(list, true);
    } catch (_) {
      return FoodResult(_mockItems(city), false); // 降级
    }
  }

  /// 按 id 获取美食详情（异步）
  static Future<FoodResult<FoodItem>> fetchDetail(int id, String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return FoodResult(_mockDetail(id, city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/food/detail/$id',
        query: {'city': city},
        cacheKey: 'food_detail_${id}_$city',
        ttl: _cacheTtl,
      );
      final item =
          FoodItem.fromJson(Map<String, dynamic>.from(resp['item'] as Map));
      return FoodResult(item, true);
    } catch (_) {
      return FoodResult(_mockDetail(id, city), false); // 降级
    }
  }

  /// 由已加载列表派生分类筛选标签（去重，前置「全部」）
  static List<String> deriveTags(List<FoodItem> items) {
    final tags = <String>['全部'];
    for (final item in items) {
      if (!tags.contains(item.tag)) tags.add(item.tag);
    }
    return tags;
  }

  /// 关键词 + 分类联合筛选（对已加载列表本地过滤）
  static List<FoodItem> filterList(List<FoodItem> items,
      {String keyword = '', String tag = '全部'}) {
    final kw = keyword.trim().toLowerCase();
    return items.where((item) {
      final matchKw = kw.isEmpty ||
          item.name.toLowerCase().contains(kw) ||
          item.desc.toLowerCase().contains(kw);
      final matchTag = tag == '全部' || item.tag == tag;
      return matchKw && matchTag;
    }).toList();
  }

  /// 推荐门店（异步；按开关决定 mock / server，失败降级本地示例）
  /// 字段与 MicroTripServer `GET {apiBase}/food/shops?city=` 对齐。
  static Future<FoodResult<List<FoodShop>>> fetchShops(String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return FoodResult(_mockShops(city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/food/shops',
        query: {'city': city},
        cacheKey: 'food_shops_$city',
        ttl: _cacheTtl,
      );
      final list = (resp['list'] as List? ?? [])
          .map((e) => FoodShop.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return FoodResult(list, true);
    } catch (_) {
      return FoodResult(_mockShops(city), false); // 降级
    }
  }

  /// 推荐店铺本地示例（以城市坐标为基准加偏移模拟位置，作为服务端不可达时的兜底）
  static List<FoodShop> _mockShops(String city,
      {double baseLat = 30.5728, double baseLng = 104.0668}) {
    return [
      FoodShop(
          id: 1,
          name: '老$city记·特色餐厅',
          rating: 4.8,
          distance: '800m',
          avgPrice: '25元/人',
          address: '中山路与解放路交叉口东南角',
          latitude: baseLat + 0.005,
          longitude: baseLng + 0.003),
      FoodShop(
          id: 2,
          name: '巷子深处·私房菜',
          rating: 4.6,
          distance: '1.2km',
          avgPrice: '30元/人',
          address: '文庙巷 12 号（近地铁 2 号线文庙站）',
          latitude: baseLat - 0.003,
          longitude: baseLng + 0.007),
      FoodShop(
          id: 3,
          name: '深夜食堂·宵夜铺',
          rating: 4.5,
          distance: '2.5km',
          avgPrice: '22元/人',
          address: '滨江夜市 A 区 08 号摊位',
          latitude: baseLat + 0.008,
          longitude: baseLng - 0.005),
    ];
  }

  // ==================== 本地示例数据（与小程序一致） ====================

  static List<FoodItem> _mockItems(String city) => [
        FoodItem(
            id: 1,
            name: '$city特色小面',
            image: '🍜',
            rating: 4.8,
            price: '15-30元',
            tag: '必吃',
            tags: const ['必吃', '早餐', '面食'],
            desc: '$city特色小面是当地最具代表性的传统早餐。面条劲道爽滑，汤底用骨头和老母鸡慢火熬制数小时，鲜香浓郁。配上秘制辣椒油、葱花和脆花生，一碗下肚，元气满满地开启一天的旅程。',
            tips: '建议早上 7-9 点前往，口味最正宗，避开饭点排队高峰。'),
        FoodItem(
            id: 2,
            name: '老字号砂锅',
            image: '🥘',
            rating: 4.7,
            price: '40-80元',
            tag: '人气',
            tags: const ['人气', '正餐', '老字号'],
            desc: '传承三代的秘制砂锅，选用当天新鲜食材，砂锅慢炖锁住原汁原味。招牌牛肉砂锅肉质软烂入味，汤汁浓郁醇厚，配上米饭堪称一绝，是本地人聚餐的首选。'),
        FoodItem(
            id: 3,
            name: '街头炸串',
            image: '🍢',
            rating: 4.6,
            price: '10-25元',
            tag: '夜市',
            tags: const ['夜市', '小吃', '宵夜'],
            desc: '夜幕降临后的街头宝藏小吃。各类串串现点现炸，外酥里嫩，刷上老板特制的甜辣酱和孜然粉，香气扑鼻。推荐炸茄盒、炸里脊和炸年糕，配一瓶冰饮，快乐加倍。'),
        FoodItem(
            id: 4,
            name: '手工汤圆',
            image: '🧆',
            rating: 4.9,
            price: '8-15元',
            tag: '甜品',
            tags: const ['甜品', '手工', '传统'],
            desc: '坚持手工现做的传统汤圆，糯米皮薄而不破，馅料丰富多样：黑芝麻、花生、豆沙、鲜肉应有尽有。咬上一口，香甜的馅料缓缓流出，软糯香甜，老少皆宜。'),
        FoodItem(
            id: 5,
            name: '本地烤鱼',
            image: '🐟',
            rating: 4.7,
            price: '60-120元',
            tag: '聚餐',
            tags: const ['聚餐', '夜宵', '香辣'],
            desc: '选用鲜活江鱼现杀现烤，炭火烤制外皮焦香，鱼肉鲜嫩多汁。配上豆芽、土豆、藕片等十余种配菜，淋上秘制香辣酱汁，越煮越入味，是朋友聚餐的绝佳选择。'),
        FoodItem(
            id: 6,
            name: '$city麻辣火锅',
            image: '🌶️',
            rating: 4.8,
            price: '80-180元',
            tag: '必吃',
            tags: const ['必吃', '聚餐', '香辣'],
            desc: '$city麻辣火锅以牛油锅底闻名，红汤翻滚、麻辣鲜香。毛肚、鸭肠、黄喉讲究七上八下，涮至脆嫩最入味；配上蒜泥香油碟解辣提鲜。冬夜围炉而坐，是这座城市最有烟火气的聚餐方式。',
            tips: '建议点半份拼盘尝多种菜，怕辣可选鸳鸯锅，自带饮品更划算。'),
        FoodItem(
            id: 7,
            name: '手工冰粉凉糕',
            image: '🍧',
            rating: 4.7,
            price: '6-12元',
            tag: '甜品',
            tags: const ['甜品', '消暑', '小吃'],
            desc: '炎炎夏日里的一口清凉。冰粉滑嫩如凝脂，淋上红糖水，撒花生碎、葡萄干和山楂丁；凉糕则是用米浆制成的块状甜品，冰凉爽滑，甜而不腻，吃辣后来一碗最是解腻。',
            tips: '街边老摊往往最地道，加醪糟风味更特别。'),
        FoodItem(
            id: 8,
            name: '锅盔夹卤肉',
            image: '🫓',
            rating: 4.6,
            price: '8-15元',
            tag: '早餐',
            tags: const ['早餐', '面食', '小吃'],
            desc: '外脆里软的烤制锅盔从中剖开，夹入卤得入味的五花肉和凉拌蔬菜，肉香与面香交融。一口咬下酥脆掉渣，是当地人钟爱的便携式早餐与加餐。',
            tips: '刚出炉趁热吃最香，可让老板多刷点卤汁。'),
        FoodItem(
            id: 9,
            name: '酸辣粉',
            image: '🍜',
            rating: 4.7,
            price: '12-20元',
            tag: '人气',
            tags: const ['夜市', '人气', '小吃'],
            desc: '红薯粉条爽滑劲道，浸在红油酸汤里，酸辣开胃。花生碎、榨菜末、香菜和酥黄豆点缀其上，吸溜一口粉、喝一口汤，额头微微冒汗，畅快淋漓，是夜市里长盛不衰的人气小吃。',
            tips: '可加肥肠或肉末升级，记得趁热拌开。'),
        FoodItem(
            id: 10,
            name: '钵钵鸡',
            image: '🍢',
            rating: 4.8,
            price: '30-60元',
            tag: '聚餐',
            tags: const ['冷吃', '串串', '聚餐'],
            desc: '将鸡肉与各色配菜煮熟后串签，浸入藤椒或红油钵钵中冷吃。藤椒版麻香清爽，红油版香辣浓郁，按签计价丰俭由人，边聊边吃，最是市井惬意。',
            tips: '藤椒口味更清爽，配冰粉正好一冷一热。'),
      ];

  /// 按 id 获取美食详情（本地回退）
  static FoodItem _mockDetail(int id, String city) {
    final items = _mockItems(city);
    return items.firstWhere((e) => e.id == id, orElse: () => items.first);
  }
}
