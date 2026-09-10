import 'secrets.dart';

/// ============================================================
/// 全局配置中心
/// 迁移自小程序 utils/config.js，结构 1:1 对齐。
///
/// 优先级：用户在「设置」页保存的覆盖配置 > 此处内置默认值。
/// API Key 未配置 / 失效时，服务层自动降级为 Mock 数据。
/// ============================================================
class AppConfig {
  AppConfig._();

  // ==================== 天气 API（和风天气 QWeather）====================
  // 申请/管理地址: https://dev.qweather.com/
  // 新版和风天气（2026 起）：每个账号使用独立「专属 API Host」，
  // 公共域名 api.qweather.com / geoapi.qweather.com 已停服（403 Invalid Host）。
  static const String weatherApiHost =
      'https://kd436kad6u.re.qweatherapi.com';
  static const String weatherApiKey = Secrets.weatherApiKey;

  // ==================== AI 大模型 API（OpenAI 兼容格式）====================
  // 默认智谱 GLM；可切换 DeepSeek / 通义千问等
  static const String aiApiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String aiApiKey = Secrets.aiApiKey;
  static const String aiModel = 'glm-4.7-flash';
  // 拍照识物（视觉模型，Phase 2 启用）
  static const String aiVisionModel = 'glm-4.6v-flash';
  static const String aiSystemPrompt =
      '你是一个专业的微旅途旅行助手「小途」，擅长为用户提供旅游建议、行程规划、美食推荐、景点介绍等服务。请用简洁、友好、实用的语气回答问题，适合在手机上阅读。';
  static const int aiMaxTokens = 2000;
  static const double aiTemperature = 0.7;

  // ==================== 腾讯地图（逆地理编码）====================
  // 申请地址: https://lbs.qq.com/
  static const String tencentMapKey = Secrets.tencentMapKey;

  // ==================== 天地图（瓦片源，CGCS2000≈WGS-84，无需坐标偏移）====================
  // 申请地址: https://console.tianditu.gov.cn/api/key （创建「浏览器端」应用获取 tk）
  // 说明：天地图使用 CGCS2000 坐标系，Web 墨卡托瓦片(vec_w / cva_w)与 WGS-84 基本重合
  // （差异 < 1m），本 App 坐标（GPS / POI / 城市 / 轨迹）为 WGS-84，直接显示即可，
  // 无需 GCJ-02 转换（GCJ-02 是高德/腾讯的火星坐标偏移，套在天地图上会反向错几百米）。
  // 天地图瓦片【必须】带 tk（token），否则返回 403；tk 填到 [tdtKey]，URL 已内置拼接。
  static const String tdtKey = Secrets.tdtKey;
  // 矢量底图（Web 墨卡托 EPSG:3857）+ 矢量注记（路名/地名，透明底叠加）
  static const String tdtVecUrl =
      'https://t{s}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=$tdtKey';
  static const String tdtCvaUrl =
      'https://t{s}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=$tdtKey';
  static const List<String> tdtSubdomains = ['0', '1', '2', '3', '4', '5', '6', '7'];

  // ==================== 应用信息 ====================
  static const String appName = '微旅途';

  /// 运营联系邮箱：隐私政策 / 用户协议 / 各应用商店备案信息统一引用此处，
  /// 换邮箱只需改这一行（发版前务必确认与商店后台填写的一致）。
  static const String contactEmail = 'xuhaijun5382@163.com';

  /// 应用版本号：与 pubspec.yaml 的 version 保持一致（发版时两处同步改）。
  static const String appVersion = '3.0.0';

  /// 渠道号：由构建脚本通过 --dart-define=CHANNEL=huawei 注入，
  /// 本地直跑 / 未注入时为 official（官网直装包）。
  /// 各商店上架包使用 scripts/build_channels.ps1 一键产出。
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'official',
  );
  static const String storagePrefix = 'travel_';

  // ==================== 缓存过期时间 ====================
  static const Duration weatherCache = Duration(minutes: 30); // 天气 30 分钟
  static const Duration cityInfoCache = Duration(hours: 24); // 城市信息 24 小时

  // ==================== 轨迹记录（停留点检测，Phase 2）====================
  static const double trackStayRadiusMeters = 100; // 同一地点半径（米）
  static const Duration trackStayMinDuration = Duration(minutes: 10); // 最短停留
  static const double trackElevationThreshold = 5; // 爬升噪声阈值（米）
}
