// ============================================================
// iOS 后台轨迹定位桥接（lib/services/ios_background_location.dart）
//
// 通过 MethodChannel('microtrip/location') 与 iOS 原生 BackgroundLocationManager 通信。
// 仅 iOS 生效；Android 走平台自身的后台定位/前台服务，调用本类会被安全忽略。
//
// ⚠️ 集成位置：已在 lib/providers/app_providers.dart 的
//    TrajectoryRecordingNotifier.start()（录制开始：start() + scheduleBackgroundRefresh()）
//    与 .stop()（录制结束：stop()）中接入，与 Android 前台保活服务并列调用。
//    非 iOS 平台在下面各方法内通过 Platform.isIOS 守卫安全忽略，不影响 Android 业务。
// ============================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 后台轨迹定位控制（单例通道）
class IosBackgroundLocation {
  IosBackgroundLocation._();

  static const _channel = MethodChannel('microtrip/location');

  /// 开始后台定位（iOS 调用原生 startBackgroundLocation；其余平台安全忽略）
  static Future<void> start() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('startBackgroundLocation');
    } on PlatformException catch (e) {
      // 原生未实现 / 权限被拒：仅记录，不中断上层业务
      debugPrint('[IosBackgroundLocation] start 失败: ${e.message}');
    }
  }

  /// 停止后台定位
  static Future<void> stop() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('stopBackgroundLocation');
    } on PlatformException catch (e) {
      debugPrint('[IosBackgroundLocation] stop 失败: ${e.message}');
    }
  }

  /// 注册并提交一次后台刷新任务（建议开始录制时调用一次）
  static Future<void> scheduleBackgroundRefresh() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('scheduleBackgroundRefresh');
    } on PlatformException catch (e) {
      debugPrint('[IosBackgroundLocation] schedule 失败: ${e.message}');
    }
  }
}
