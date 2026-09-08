// ============================================================
// 后台轨迹录制保活服务（Phase 5）
//
// 目标：App 退到后台/锁屏时 GPS 轨迹仍持续记录。
//
// 方案（与用户确认）：
//  - Android：前台 Service 保活（flutter_background_service）——
//    isForegroundMode=true + foregroundServiceType=location，
//    通知栏常驻显示「轨迹录制中」；进程被系统标记为前台，不会被 LMK 杀掉，
//    现有 TrajectoryService 的 geolocator 流（UI isolate）持续接收 GPS 点。
//  - iOS：系统级后台定位（UIBackgroundModes=location），由系统向 App 持续
//    投递位置更新，无需前台服务（iOS 不允许任意长时后台 Dart 执行）。
//
// 停止方式：UI 调 invoke('stop')，Service isolate 内监听后 stopSelf()。
// ============================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 后台录制保活服务
class BackgroundRecorderService {
  BackgroundRecorderService._();

  /// 常驻通知渠道 ID（与 flutter_local_notifications 共用体系）
  static const String channelId = 'trajectory_recording';

  /// 常驻通知 ID
  static const int notificationId = 1002;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// 是否已配置（防止重复 configure）
  static bool _configured = false;

  /// 是否处于后台录制中（UI 侧标志）
  static bool _active = false;

  /// main() 启动时调用一次：注册后台回调 + 创建通知渠道
  static Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    // flutter_background_service 仅支持 Android / iOS；
    // 在 Windows / Linux / macOS / Web 上调用 configure 会抛平台异常，
    // 导致 App 启动崩溃。桌面端无后台录制需求，直接跳过配置。
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // 创建前台服务通知渠道（Android 8+ 必需，渠道为系统级，创建一次全局生效）
    const channel = AndroidNotificationChannel(
      channelId,
      '轨迹录制',
      description: '轨迹后台录制时的常驻通知',
      importance: Importance.low, // 低重要度：常驻但静默
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false, // 仅录制时手动启动，不随开机/配置自动启动
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: '轨迹录制中',
        initialNotificationContent: '正在后台记录您的出行轨迹',
        foregroundServiceNotificationId: notificationId,
        // Android 14+ 要求声明前台服务类型；location 与轨迹录制用途匹配
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// 开始录制时调用：启动前台服务（仅 Android；iOS 走系统后台定位）
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    _active = true;
    await _service.startService();
  }

  /// 停止录制时调用：通知 Service 自杀（Android）
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _active = false;
    // UI isolate → Service isolate：invoke 通知停止
    _service.invoke('stop');
  }

  /// 当前是否处于后台录制状态
  static bool get isActive => _active;

  // ---- Service isolate 回调（与 UI isolate 不共享内存） ----

  /// Android 前台服务入口（独立 isolate 中执行）
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    // 注册插件（如需在 Service 中使用 geolocator/notifications 等）
    DartPluginRegistrant.ensureInitialized();

    // 监听 UI 的停止指令
    service.on('stop').listen((event) {
      service.stopSelf();
    });

    // 轻量心跳：保持 Service isolate 事件循环活跃（前台服务本身由系统持有，
    // 此 Timer 仅兜底防止部分 ROM 将空闲 isolate 挂起）
    Timer.periodic(const Duration(seconds: 30), (_) {});
  }

  /// iOS 后台周期回调（Background Fetch，本项目轨迹录制主要靠系统后台定位，
  /// 此回调仅作保底占位，返回 true 表示任务完成）
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
