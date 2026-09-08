import 'package:geolocator/geolocator.dart';

import '../core/config/app_config.dart';
import '../core/http/http_client.dart';
import '../core/storage/app_storage.dart';
import '../models/city_info.dart';

/// ============================================================
/// 定位服务
/// 对应小程序 utils/location.js：
///  - geolocator 获取经纬度（对应 wx.getLocation）
///  - 腾讯地图逆地理编码 → 城市/省份/区县/推荐地址
///  - 权限拒绝 / 失败时返回 null，由上层降级「最近城市」
/// ============================================================
class LocationService {
  LocationService._();

  /// 检查并申请定位权限
  static Future<bool> ensurePermission() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// 单次定位 + 逆地理 → CityInfo；失败返回 null
  static Future<CityInfo?> locateCity() async {
    try {
      if (!await ensurePermission()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // 城市级精度足够，省电
        ),
      );
      return await reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// 腾讯地图逆地理编码（需 WebServiceAPI 权限）
  static Future<CityInfo?> reverseGeocode(double lat, double lng) async {
    try {
      final data = await HttpClient.get(
        'https://apis.map.qq.com/ws/geocoder/v1/',
        query: {
          'location': '$lat,$lng',
          'key': AppConfig.tencentMapKey,
          'get_poi': '0',
        },
      );
      if (data?['status'] == 0 && data?['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final ac = result['ad_info'];
        if (ac is Map) {
          return CityInfo(
            name: ac['city']?.toString().replaceAll('市', '') ?? '',
            province: ac['province']?.toString().replaceAll('省', '') ?? '',
            lat: lat,
            lng: lng,
            district: ac['district']?.toString() ?? '',
            address: result['formatted_recommend_addresses'] != null
                ? ''
                : (result['address']?.toString() ?? ''),
            adcode: ac['adcode']?.toString() ?? '',
          );
        }
      }
    } catch (_) {/* 降级最近城市 */}
    return null;
  }

  /// 保存/读取最近城市（对应 travel_recentCities）
  static Future<List<CityInfo>> loadRecentCities() async {
    final raw = AppStorage.getObject(AppStorage.kRecentCities,
        defaultValue: []);
    if (raw is List) {
      return raw
          .map((e) => CityInfo.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  static Future<void> addRecentCity(CityInfo city) async {
    final list = await loadRecentCities();
    list.removeWhere((c) => c.name == city.name);
    list.insert(0, city);
    if (list.length > 8) list.removeRange(8, list.length);
    await AppStorage.setObject(
        AppStorage.kRecentCities, list.map((c) => c.toMap()).toList());
  }
}
