import 'dart:io';

import 'package:health/health.dart';

/// ============================================================
/// 系统健康数据服务（Phase 4）
/// - iOS：HealthKit（需 Info.plist 声明 NSHealthShareUsageDescription）
/// - Android：Health Connect（需 manifest 声明 health.READ_STEPS + minSdk 26）
///
/// 设计原则（避免骚扰用户）：
///  - [syncTodaySteps] / [syncStepsForDate]：仅当用户已授权时静默读取，
///    未授权返回 null（不主动弹权限框）；
///  - [requestAuthorization]：由步数页/设置页的显式按钮触发授权。
/// 任何平台异常均返回 null，由 StepService 降级到 mock，保证离线可跑。
/// ============================================================
class HealthService {
  HealthService._();

  static Health? _health;

  /// 当前平台是否支持健康数据（iOS / Android）
  static bool get platformSupported => Platform.isIOS || Platform.isAndroid;

  /// 懒初始化 health 单例（13.x singleton 模型）
  static Health _instance() {
    _health ??= Health();
    _health!.configure();
    return _health!;
  }

  /// 是否已授予步数读取权限（不弹窗）
  static Future<bool> hasPermission() async {
    if (!platformSupported) return false;
    try {
      // 13.x 返回 bool?，统一归一为 false
      return (await _instance().hasPermissions([HealthDataType.STEPS])) == true;
    } catch (_) {
      return false;
    }
  }

  /// 请求步数读取权限（需在用户手势中调用）
  static Future<bool> requestAuthorization() async {
    if (!platformSupported) return false;
    try {
      return await _instance().requestAuthorization([HealthDataType.STEPS]);
    } catch (_) {
      return false;
    }
  }

  /// 同步今日步数（已授权则返回真实步数，否则返回 null）
  static Future<int?> syncTodaySteps() async {
    if (!platformSupported) return null;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    try {
      if ((await _instance().hasPermissions([HealthDataType.STEPS])) != true) {
        return null;
      }
      return await _readStepsInRange(dayStart, now);
    } catch (_) {
      return null;
    }
  }

  /// 同步指定日期步数（已授权则返回真实步数，否则返回 null）
  static Future<int?> syncStepsForDate(DateTime date) async {
    if (!platformSupported) return null;
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    try {
      if ((await _instance().hasPermissions([HealthDataType.STEPS])) != true) {
        return null;
      }
      return await _readStepsInRange(dayStart, dayEnd);
    } catch (_) {
      return null;
    }
  }

  /// 读取时间区间内步数（优先 getTotalStepsInInterval 汇总接口）
  static Future<int?> _readStepsInRange(DateTime start, DateTime end) async {
    // 汇总接口：直接返回区间总步数（iOS HealthKit / Android Health Connect 均支持）
    final total = await _instance().getTotalStepsInInterval(start, end);
    if (total != null && total > 0) return total;

    // 兜底：逐条累加（部分平台汇总接口返回 0 时）
    // 注意 13.x 参数名是 startTime / endTime；value 需转型 NumericHealthValue
    final points = await _instance().getHealthDataFromTypes(
      types: [HealthDataType.STEPS],
      startTime: start,
      endTime: end,
    );
    if (points.isEmpty) return null;
    var sum = 0;
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) sum += v.numericValue.round();
    }
    return sum > 0 ? sum : null;
  }
}
