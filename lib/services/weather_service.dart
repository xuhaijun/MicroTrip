import '../core/config/app_config.dart';
import '../core/http/http_client.dart';
import '../core/storage/app_storage.dart';
import '../models/city_info.dart';
import '../models/weather.dart';

/// ============================================================
/// 天气服务（和风天气 QWeather）
/// 迁移自小程序 utils/weather.js：
///  - GeoAPI 城市名/区县 → LocationID
///  - /v7/weather/now、/10d、/24h
///  - 请求失败 / Key 失效 / Host 失效 → 自动降级 Mock 并标记 isMock
///  - 30 分钟缓存（getWithCache）
/// ============================================================
class WeatherService {
  WeatherService._();

  /// 读取当前生效的天气配置（用户设置页覆盖 > 内置默认）
  static ({String apiHost, String apiKey}) get config {
    final saved = AppStorage.getObject(AppStorage.kWeatherConfig);
    String host = AppConfig.weatherApiHost;
    String key = AppConfig.weatherApiKey;
    if (saved is Map) {
      host = saved['apiHost']?.toString() ?? host;
      key = saved['apiKey']?.toString() ?? key;
    }
    if (!host.contains('://')) host = 'https://$host';
    return (apiHost: host, apiKey: key);
  }

  /// 配置是否有效（排除占位符）
  static bool get isConfigured {
    final c = config;
    if (c.apiKey.isEmpty || c.apiHost.isEmpty) return false;
    if (c.apiKey.contains('YOUR_') || c.apiHost.contains('YOUR_')) return false;
    return true;
  }

  /// 城市名 → LocationID（GeoAPI）
  static Future<String> _lookupLocationId(String name,
      {String adm = ''}) async {
    if (!isConfigured || name.isEmpty) return '';
    try {
      final data = await HttpClient.get(
        '${config.apiHost}/geo/v2/city/lookup',
        query: {'location': name, if (adm.isNotEmpty) 'adm': adm, 'key': config.apiKey},
      );
      final list = data?['location'];
      if (data?['code'] == '200' && list is List && list.isNotEmpty) {
        return list.first['id']?.toString() ?? '';
      }
    } catch (_) {/* 失败回退坐标/城市名 */}
    return '';
  }

  /// 解析 location 参数：区县 ID > 经纬度 > 城市 LocationID
  static Future<String> resolveLocationId(CityInfo city) async {
    if (city.district.isNotEmpty) {
      final did = await _lookupLocationId(city.district, adm: city.name);
      if (did.isNotEmpty) return did;
    }
    if (city.lat != 0 && city.lng != 0) {
      return '${city.lng.toStringAsFixed(2)},${city.lat.toStringAsFixed(2)}';
    }
    final id = await _lookupLocationId(city.name);
    return id.isNotEmpty ? id : city.name;
  }

  /// 实时天气（带 30 分钟缓存 + Mock 降级）
  static Future<WeatherNow> getNowWeather(CityInfo city) async {
    final locationId = await resolveLocationId(city);
    try {
      final data = await HttpClient.getWithCache(
        '${config.apiHost}/v7/weather/now',
        query: {'location': locationId, 'key': config.apiKey},
        cacheKey: 'weather_$locationId',
        ttl: AppConfig.weatherCache,
      );
      if (data?['now'] is Map) {
        return WeatherNow.fromMap(Map<String, dynamic>.from(data['now']));
      }
      throw ServiceException('获取天气失败');
    } catch (_) {
      return _mockNow();
    }
  }

  /// 每日预报（10 天，Mock 降级）
  static Future<List<WeatherDaily>> getForecast(CityInfo city,
      {int days = 10}) async {
    final locationId = await resolveLocationId(city);
    try {
      final data = await HttpClient.getWithCache(
        '${config.apiHost}/v7/weather/${days}d',
        query: {'location': locationId, 'key': config.apiKey},
        cacheKey: 'forecast_$locationId',
        ttl: AppConfig.weatherCache,
      );
      final daily = data?['daily'];
      if (daily is List) {
        return daily
            .map((e) => WeatherDaily.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      throw ServiceException('获取预报失败');
    } catch (_) {
      return _mockForecast(days);
    }
  }

  /// 逐小时预报（24h，Mock 降级）
  static Future<List<WeatherHourly>> getHourly(CityInfo city) async {
    final locationId = await resolveLocationId(city);
    try {
      final data = await HttpClient.get(
        '${config.apiHost}/v7/weather/24h',
        query: {'location': locationId, 'key': config.apiKey},
      );
      final hourly = data?['hourly'];
      if (hourly is List) {
        return hourly
            .map((e) => WeatherHourly.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      throw ServiceException('获取逐小时失败');
    } catch (_) {
      return _mockHourly();
    }
  }

  /// 清除该城市天气缓存（下拉刷新用）
  static Future<void> clearCache(CityInfo city) async {
    final id = await resolveLocationId(city);
    await HttpClient.clearCache('weather_$id');
    await HttpClient.clearCache('forecast_$id');
  }

  // ---------------- Mock 数据 ----------------

  static WeatherNow _mockNow() {
    final temps = [15, 18, 20, 22, 25, 28, 30, 32];
    final texts = ['晴', '多云', '阴', '小雨'];
    final codes = {'晴': '100', '多云': '101', '阴': '104', '小雨': '305'};
    temps.shuffle();
    texts.shuffle();
    final t = temps.first;
    final text = texts.first;
    return WeatherNow(
      temp: '$t',
      text: text,
      // 与和风 v7 代码对齐，保证 Mock 降级时首页/详情页图标仍一致
      icon: codes[text] ?? '100',
      windDir: '东南风',
      windScale: '2',
      humidity: '${40 + DateTime.now().second % 40}',
      feelsLike: '$t',
      obsTime: DateTime.now().toIso8601String(),
      isMock: true,
    );
  }

  static List<WeatherDaily> _mockForecast(int days) {
    final texts = ['晴', '多云', '阴'];
    final codes = {'晴': '0', '多云': '1', '阴': '4'};
    return List.generate(days, (i) {
      final d = DateTime.now().add(Duration(days: i));
      final text = texts[(d.day + i) % 3];
      return WeatherDaily(
        fxDate:
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        tempMax: '${20 + (d.day % 12)}',
        tempMin: '${8 + (d.day % 10)}',
        textDay: text,
        textNight: '晴',
        iconDay: codes[text] ?? '0',
      );
    });
  }

  static List<WeatherHourly> _mockHourly() {
    final base = 20 + DateTime.now().hour % 8;
    return List.generate(24, (i) {
      final t = DateTime.now().add(Duration(hours: i));
      final isRain = i == 5; // 模拟第 6 小时有小雨，其余多云
      return WeatherHourly(
        fxTime: t.toIso8601String(),
        temp: '${base + (i % 5)}',
        text: isRain ? '小雨' : '多云',
        // 与和风 v7 代码对齐（小雨 305 / 多云 101），保证降级时图标与文字一致
        icon: isRain ? '305' : '101',
        pop: isRain ? '60' : '0',
      );
    });
  }
}
