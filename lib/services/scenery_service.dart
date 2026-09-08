import '../core/config/data_config.dart';
import '../core/http/http_client.dart';
import '../models/scenery_item.dart';
import '../services/auth_service.dart';

/// ============================================================
/// 景点服务（迁移自小程序 subpackages/city/pages/scenery/scenery.js）
///
/// 数据源由「模拟数据总开关」[DataConfig.useMockData] 决定：
///  - 开关开启（默认）或 未配置后端地址 → 使用 App 内置示例数据（离线可用）；
///  - 开关关闭且已配置 [AuthService.serverUrl] → 从服务端拉取真实数据；
///  - 请求失败自动降级为本地示例数据，保证页面永不可用。
///
/// 服务端接口（MicroTripServer）：
///  - GET {apiBase}/scenery/list?city=xxx    → { list: [SceneryItem] }
///  - GET {apiBase}/scenery/detail/:id?city=xxx → { item: SceneryItem }
///  - GET {apiBase}/scenery/nearby/:id?city=xxx → { list: [NearbyScenery] }
/// ============================================================

/// 数据来源包装：携带 [fromServer] 便于 UI 展示「本地模拟 / 服务端」
class SceneryResult<T> {
  const SceneryResult(this.data, this.fromServer);
  final T data;
  final bool fromServer;
}

class SceneryService {
  SceneryService._();

  /// 服务端响应缓存时长（城市维度静态数据，10 分钟内复用，减少服务端请求）
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// 是否应走本地模拟（开关开，或未配置后端地址）
  static bool _shouldUseMock({bool? mock}) =>
      (mock ?? DataConfig.useMockData) || AuthService.serverUrl.isEmpty;

  /// 获取景点列表（异步；按开关决定 mock / server）
  static Future<SceneryResult<List<SceneryItem>>> fetchList(String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return SceneryResult(_mockItems(city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/scenery/list',
        query: {'city': city},
        cacheKey: 'scenery_list_$city',
        ttl: _cacheTtl,
      );
      final list = (resp['list'] as List? ?? [])
          .map((e) =>
              SceneryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return SceneryResult(list, true);
    } catch (_) {
      return SceneryResult(_mockItems(city), false); // 降级
    }
  }

  /// 按 id 获取景点详情（异步）
  static Future<SceneryResult<SceneryItem>> fetchDetail(int id, String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return SceneryResult(_mockDetail(id, city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/scenery/detail/$id',
        query: {'city': city},
        cacheKey: 'scenery_detail_${id}_$city',
        ttl: _cacheTtl,
      );
      final item =
          SceneryItem.fromJson(Map<String, dynamic>.from(resp['item'] as Map));
      return SceneryResult(item, true);
    } catch (_) {
      return SceneryResult(_mockDetail(id, city), false); // 降级
    }
  }

  /// 周边推荐（异步；排除当前景点，取 4 个）
  static Future<SceneryResult<List<NearbyScenery>>> fetchNearby(
      int currentId, String city,
      {bool? mock}) async {
    if (_shouldUseMock(mock: mock)) {
      return SceneryResult(_mockNearby(currentId, city), false);
    }
    try {
      final resp = await HttpClient.getWithCache(
        '${AuthService.apiBase}/scenery/nearby/$currentId',
        query: {'city': city},
        cacheKey: 'scenery_nearby_${currentId}_$city',
        ttl: _cacheTtl,
      );
      final list = (resp['list'] as List? ?? [])
          .map((e) =>
              NearbyScenery.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return SceneryResult(list, true);
    } catch (_) {
      return SceneryResult(_mockNearby(currentId, city), false); // 降级
    }
  }

  /// 由已加载列表派生分类筛选标签（去重，前置「全部」）
  static List<String> deriveTags(List<SceneryItem> items) {
    final tags = <String>['全部'];
    for (final item in items) {
      if (!tags.contains(item.tag)) tags.add(item.tag);
    }
    return tags;
  }

  /// 关键词 + 分类联合筛选（对已加载列表本地过滤）
  static List<SceneryItem> filterList(List<SceneryItem> items,
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

  // ==================== 本地示例数据（与小程序一致） ====================

  static List<SceneryItem> _mockItems(String city) => [
        SceneryItem(
            id: 1,
            name: '$city历史博物馆',
            image: '🏛️',
            rating: 4.7,
            ticket: '免费',
            duration: '2-3小时',
            openTime: '09:00 - 17:00（周一闭馆）',
            tag: '文化',
            tags: const ['文化', '亲子', '室内'],
            desc: '$city历史博物馆是了解这座城市历史文化的最佳去处。馆藏文物数万件，从远古文明到近代风云，系统展示了城市的发展脉络。镇馆之宝不容错过，建议租用讲解器深度游览。',
            address: '$city市博物馆路 1 号',
            latitude: 30.5728,
            longitude: 104.0668),
        SceneryItem(
            id: 2,
            name: '城市中央公园',
            image: '🌳',
            rating: 4.6,
            ticket: '免费',
            duration: '1-2小时',
            openTime: '全天开放',
            tag: '休闲',
            tags: const ['休闲', '拍照', '免费'],
            desc: '城市中央公园绿树成荫，湖光山色相映成趣。清晨有许多市民在此晨练，午后适合在草坪上野餐小憩。湖边的栈道是散步和拍照的绝佳位置，四季景色各有不同。',
            address: '市中心公园路 88 号',
            latitude: 30.5700,
            longitude: 104.0700),
        SceneryItem(
            id: 3,
            name: '山顶观景台',
            image: '🏔️',
            rating: 4.9,
            ticket: '50元',
            duration: '3-4小时',
            openTime: '06:00 - 20:00',
            tag: '日出',
            tags: const ['日出', '登高', '必打卡'],
            desc: '登高望远，俯瞰全城美景。天气晴朗时可将整座城市尽收眼底，是观赏日出和日落的绝佳地点。建议清晨 5 点前到达抢占最佳机位，记得带上外套，山顶风大温差明显。',
            address: '城郊山风景区山顶',
            latitude: 30.5800,
            longitude: 104.0800),
        SceneryItem(
            id: 4,
            name: '滨江步道',
            image: '🌊',
            rating: 4.8,
            ticket: '免费',
            duration: '1-2小时',
            openTime: '全天开放',
            tag: '夜景',
            tags: const ['夜景', '散步', '免费'],
            desc: '沿江而建的景观步道，傍晚漫步最为惬意。夜幕降临后两岸灯光璀璨，江面波光粼粼，是城市夜景的最佳观赏地。步道沿线有多处观景平台和休憩座椅。',
            address: '滨江路沿线',
            latitude: 30.5650,
            longitude: 104.0600),
        SceneryItem(
            id: 5,
            name: '古镇老街',
            image: '🏘️',
            rating: 4.5,
            ticket: '免费',
            duration: '2-3小时',
            openTime: '08:00 - 22:00',
            tag: '打卡',
            tags: const ['打卡', '古韵', '美食'],
            desc: '青砖黛瓦的古建筑群保存完好，漫步老街仿佛穿越回旧时光。街上有众多手工艺店铺、茶馆和特色小吃，适合慢慢逛、细细品，感受浓浓的古韵风情。',
            address: '古镇景区老街 1-100 号',
            latitude: 30.5600,
            longitude: 104.0500),
        SceneryItem(
            id: 6,
            name: '$city湿地公园',
            image: '🦆',
            rating: 4.6,
            ticket: '免费',
            duration: '2-3小时',
            openTime: '07:00 - 19:00',
            tag: '自然',
            tags: const ['自然', '亲子', '免费'],
            desc: '$city湿地公园水网交织，芦苇摇曳，是观鸟与亲近自然的好去处。木栈道穿行其间，春夏荷花亭亭，秋冬候鸟栖息。带孩子来此科普湿地生态，或只是静坐听风，都十分惬意。',
            address: '$city市湿地公园保护区',
            latitude: 30.5550,
            longitude: 104.0450),
        SceneryItem(
            id: 7,
            name: '文创园·旧厂房',
            image: '📚',
            rating: 4.5,
            ticket: '免费',
            duration: '1-2小时',
            openTime: '10:00 - 22:00',
            tag: '文艺',
            tags: const ['文艺', '拍照', '室内'],
            desc: '由老厂房改造的文创聚集地，红砖墙、钢架结构与涂鸦相映成趣。这里有独立书店、手作工坊、咖啡馆和展览空间，是文艺青年打卡拍照、消磨午后时光的宝藏角落。',
            address: '城东文创园区 3 号楼',
            latitude: 30.5750,
            longitude: 104.0850),
        SceneryItem(
            id: 8,
            name: '城市观景塔',
            image: '🗼',
            rating: 4.7,
            ticket: '60元',
            duration: '1小时',
            openTime: '09:00 - 22:00',
            tag: '夜景',
            tags: const ['夜景', '登高', '必打卡'],
            desc: '登上城市观景塔，透过全景玻璃俯瞰全城脉络。白天楼宇鳞次栉比，入夜华灯初上，璀璨夜景尽收眼底，是情侣约会和城市风光摄影的热门地点。',
            address: '中央商务区观景塔',
            latitude: 30.5780,
            longitude: 104.0750),
        SceneryItem(
            id: 9,
            name: '美食夜市',
            image: '🌃',
            rating: 4.6,
            ticket: '免费',
            duration: '2-3小时',
            openTime: '17:00 - 24:00',
            tag: '人气',
            tags: const ['夜景', '小吃', '人气'],
            desc: '华灯初上的美食夜市人声鼎沸，各色摊位烟火升腾。从烤串、炒粉到糖画、奶茶应有尽有，边走边吃边逛，感受最地道的市井烟火与夜生活气息。',
            address: '老城区夜市步行街',
            latitude: 30.5620,
            longitude: 104.0550),
        SceneryItem(
            id: 10,
            name: '环城绿道',
            image: '🚴',
            rating: 4.5,
            ticket: '免费',
            duration: '2-4小时',
            openTime: '全天开放',
            tag: '户外',
            tags: const ['户外', '运动', '免费'],
            desc: '沿河而建的环城绿道平坦宽敞，专为骑行与慢跑道而设。清晨或傍晚在此骑行，微风拂面、绿意相伴，是 locals 最爱的健身放松路线，沿途多处可租借单车。',
            address: '滨河绿道入口（近中央公园）',
            latitude: 30.5680,
            longitude: 104.0720),
      ];

  /// 按 id 获取景点详情（本地回退）
  static SceneryItem _mockDetail(int id, String city) {
    final items = _mockItems(city);
    return items.firstWhere((e) => e.id == id, orElse: () => items.first);
  }

  /// 周边推荐（本地回退，排除当前景点取前 4 个）
  static List<NearbyScenery> _mockNearby(int currentId, String city) {
    const all = [
      NearbyScenery(id: 1, name: '{city}历史博物馆', image: '🏛️', rating: 4.7, distance: '1.5km'),
      NearbyScenery(id: 2, name: '城市中央公园', image: '🌳', rating: 4.6, distance: '900m'),
      NearbyScenery(id: 3, name: '山顶观景台', image: '🏔️', rating: 4.9, distance: '5.2km'),
      NearbyScenery(id: 4, name: '滨江步道', image: '🌊', rating: 4.8, distance: '2.1km'),
      NearbyScenery(id: 5, name: '古镇老街', image: '🏘️', rating: 4.5, distance: '8.6km'),
      NearbyScenery(id: 6, name: '{city}湿地公园', image: '🦆', rating: 4.6, distance: '3.4km'),
      NearbyScenery(id: 7, name: '文创园·旧厂房', image: '📚', rating: 4.5, distance: '2.8km'),
      NearbyScenery(id: 8, name: '城市观景塔', image: '🗼', rating: 4.7, distance: '1.1km'),
      NearbyScenery(id: 9, name: '美食夜市', image: '🌃', rating: 4.6, distance: '4.0km'),
      NearbyScenery(id: 10, name: '环城绿道', image: '🚴', rating: 4.5, distance: '600m'),
    ];
    final resolved = all
        .map((e) => NearbyScenery(
              id: e.id,
              name: e.name.replaceAll('{city}', city),
              image: e.image,
              rating: e.rating,
              distance: e.distance,
            ))
        .toList();
    return resolved.where((e) => e.id != currentId).take(4).toList();
  }
}
