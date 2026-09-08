import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// 【包体积/启动优化】仅加载 ±5 年时区数据（latest_10y，约为完整库的 25%），
// 足以支撑「每日 08:00 本地时间」调度；避免 latest_all 把整库 IANA 数据
// 以 base64 编入 Dart 源码（约 1.8MB），既减小包体又加快启动时解析。
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/storage/app_storage.dart';
import '../models/city_info.dart';
import '../models/weather.dart';
import 'weather_service.dart';

/// ============================================================
/// 天气提醒本地通知服务（Phase 4，对应小程序 utils/weatherPush.js）
///
/// 小程序端因「无后端」只能本地 toast 兜底提示；
/// Flutter 端升级为真实系统通知：
///   - flutter_local_notifications 每日 08:00 定时推送
///   - 每次 App 启动 / 开关开启时拉取最新天气重排内容（天气按天变化）
///   - 设置页「天气提醒」开关 → userSettings.weatherNotif
///
/// 关键 API（flutter_local_notifications 22.3.0 实证）：
///   zonedSchedule(id, title, body, scheduledDate: TZDateTime,
///     notificationDetails, androidScheduleMode, matchDateTimeComponents)
///   - matchDateTimeComponents: DateTimeComponents.time → 每天同一时刻重复
///   - AndroidScheduleMode.inexactAllowWhileIdle → 无需精确闹钟权限
/// ============================================================
class WeatherPushService {
  WeatherPushService._();

  /// 通知 ID（取消 / 重排用同一 ID 即可覆盖旧通知）
  static const int _notifId = 1001;

  /// Android 通知渠道（首次调度时自动创建）
  static const String _channelId = 'weather_daily';
  static const String _channelName = '天气提醒';
  static const String _channelDesc = '每天早上推送当日天气与出行提示';

  /// 每日推送时间（24h 制）
  static const int _pushHour = 8;
  static const int _pushMinute = 0;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 设置页开关是否开启（userSettings.weatherNotif == true）
  static bool get isEnabled {
    final s = AppStorage.getObject(AppStorage.kUserSettings);
    return s is Map && s['weatherNotif'] == true;
  }

  /// 启动初始化（main.dart 调用，内部异步不阻塞首帧）
  ///
  /// 步骤：时区初始化 → 插件初始化 → Android 13+ 通知权限 →
  ///       开关开启则恢复每日调度（内容用最新天气）
  static Future<void> init() async {
    // 1. 时区初始化（zonedSchedule 依赖 tz.local 为设备真实时区）
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 获取时区失败时回退 UTC，避免后续调度抛异常
      tz.setLocalLocation(tz.UTC);
    }

    // 2. 插件初始化（Android 图标用启动图标；iOS 申请基础权限；
    //    Windows 桌面端必须提供 Windows 设置，否则 initialize 会抛
    //    "Windows settings must be set when targeting Windows platform"）
    final settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      windows: const WindowsInitializationSettings(
        appName: '微旅途',
        appUserModelId: 'Xuhai.MicroTrip.App',
        guid: '9c5e8e6b-2b4a-4f1c-9d3e-7f6a5b4c3d2e',
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;

    // 3. Android 13+（API 33+）运行时通知权限
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // 4. 恢复调度：开关开启则用最新天气重排每日通知
    if (isEnabled) {
      await scheduleDaily();
    }
  }

  /// 开启 / 关闭天气提醒（设置页开关联动）
  ///
  /// [city] 显式传入当前城市（不传则读持久化城市）
  static Future<void> setEnabled(bool enabled, {CityInfo? city}) async {
    // 读写 userSettings，保留其它字段（如后续的其它开关）
    final raw = AppStorage.getObject(AppStorage.kUserSettings);
    final s = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    s['weatherNotif'] = enabled;
    await AppStorage.setObject(AppStorage.kUserSettings, s);

    if (enabled) {
      await scheduleDaily(city: city);
    } else {
      await cancel();
    }
  }

  /// 重新排程每日 08:00 通知（内容为当前城市最新天气）
  ///
  /// 幂等：每次调用都用同一 [_notifId] 覆盖旧调度。
  /// 拉取天气失败不阻塞调度（内容回退为通用文案）。
  static Future<void> scheduleDaily({CityInfo? city}) async {
    if (!_initialized) return;
    try {
      final c = city ?? _currentCity();
      // 拉取最新天气（30 分钟缓存；失败自动降级 mock，不抛错）
      final now = await WeatherService.getNowWeather(c);
      final forecast = await WeatherService.getForecast(c, days: 1);
      final today = forecast.isNotEmpty ? forecast.first : null;
      final (title, body) = _compose(now, today, c);

      // 目标时刻：今天 08:00，若已过则顺延至明天
      final tzNow = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
          tz.local, tzNow.year, tzNow.month, tzNow.day, _pushHour, _pushMinute);
      if (!scheduled.isAfter(tzNow)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _notifId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        // 按「时分」组件每日重复，触发后自动顺延到次日同一时刻
        matchDateTimeComponents: DateTimeComponents.time,
        // 非精确闹钟（无需 SCHEDULE_EXACT_ALARM 权限，省电）
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('WeatherPushService.scheduleDaily 失败: $e');
    }
  }

  /// 取消提醒（开关关闭时调用）
  static Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notifId);
  }

  /// 组装通知文案，返回 (标题, 内容)
  ///
  /// 例：
  ///   标题：今日天气 · 成都
  ///   内容：多云 25°C，体感 27°C，20~30°C
  ///         湿度 60% · 东南风 · 2 级
  static (String, String) _compose(
      WeatherNow now, WeatherDaily? today, CityInfo city) {
    final title = '今日天气 · ${city.name}';
    final buf = StringBuffer();
    buf.write('${now.text} ${now.temp}°C');
    if (now.feelsLike.isNotEmpty) buf.write('，体感 ${now.feelsLike}°C');
    if (today != null) buf.write('，${today.tempMin}~${today.tempMax}°C');
    buf.write('\n');
    final parts = <String>[
      if (now.humidity.isNotEmpty) '湿度 ${now.humidity}%',
      if (now.windDir.isNotEmpty) now.windDir,
      if (now.windScale.isNotEmpty) '${now.windScale} 级',
    ];
    buf.write(parts.join(' · '));
    return (title, buf.toString());
  }

  /// 读取持久化当前城市（与 CityNotifier 默认值一致）
  static CityInfo _currentCity() {
    final raw = AppStorage.getObject(AppStorage.kCurrentCity);
    if (raw is Map) return CityInfo.fromMap(Map<String, dynamic>.from(raw));
    return CityInfo(name: '成都', province: '四川', lat: 30.57, lng: 104.07);
  }
}
