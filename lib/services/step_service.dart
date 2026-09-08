import '../core/storage/app_storage.dart';
import '../models/step_data.dart';
import 'health_service.dart';

/// ============================================================
/// 步数服务（Phase 2 → Phase 4 升级）
///
/// 数据源优先级（Phase 4）：
///  1. 系统健康数据（HealthKit / Health Connect，已授权时静默读取）
///  2. 本地缓存（今天已同步过真实数据）
///  3. mock 降级（未授权 / 平台不支持 / 失败，离线可跑）
///
/// 结构上仍保留：
///  - StepDataSource.local  ← 本地传感器（pedometer 插件预留）
///  - StepDataSource.wechat ← 微信运动解密（Flutter 端不可调用小程序
///                             wx.getWeRunData，需后端解密，故仅保留枚举）
///
/// 首页步数卡片直接调用 [getTodaySteps] 即可。
/// ============================================================
class StepService {
  StepService._();

  static const _key = 'travel_step_history';

  /// 获取今日步数（真实健康数据优先，mock 兜底）
  static Future<StepData> getTodaySteps() async {
    final today = _todayStr();
    final data = await _loadByDate(today);
    // 今日已有真实数据（health/local）→ 直接返回，避免重复读健康平台
    if (data != null && data.source != StepDataSource.mock) return data;

    // Phase 4：尝试系统健康数据（仅已授权时读取，不弹窗）
    final healthSteps = await HealthService.syncTodaySteps();
    if (healthSteps != null && healthSteps > 0) {
      final stepData = StepData(
        date: today,
        steps: healthSteps,
        distance: healthSteps * 0.7,
        calories: healthSteps * 0.04,
        source: StepDataSource.health,
      );
      await _saveStepData(stepData);
      return stepData;
    }

    // 今日已有 mock 数据 → 保持（避免每次打开数字跳变）
    if (data != null) return data;

    // 生成 mock 步数（6000-12000 随机）
    final mockSteps = 6000 + DateTime.now().millisecond * 6 + DateTime.now().second * 60;
    final steps = mockSteps.clamp(3000, 15000);
    final stepData = StepData(
      date: today,
      steps: steps,
      distance: steps * 0.7, // 步幅 0.7m
      calories: steps * 0.04, // 0.04 kcal/步
      source: StepDataSource.mock,
    );
    await _saveStepData(stepData);
    return stepData;
  }

  /// 获取最近 7 天步数（用于统计图表）
  static Future<List<StepData>> getRecentSteps({int days = 7}) async {
    final result = <StepData>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      var data = await _loadByDate(dateStr);
      if (data == null) {
        // 历史日期：尝试健康平台真实数据（已授权才读）
        final healthSteps = await HealthService.syncStepsForDate(date);
        if (healthSteps != null && healthSteps > 0) {
          data = StepData(
            date: dateStr,
            steps: healthSteps,
            distance: healthSteps * 0.7,
            calories: healthSteps * 0.04,
            source: StepDataSource.health,
          );
          await _saveStepData(data);
        }
      }
      if (data == null) {
        // 为历史日期生成模拟数据
        final seed = date.day * 100 + date.month * 10;
        final steps = (5000 + (seed % 7000)).clamp(2000, 14000);
        data = StepData(
          date: dateStr,
          steps: steps,
          distance: steps * 0.7,
          calories: steps * 0.04,
          source: StepDataSource.mock,
        );
      }
      result.add(data);
    }
    return result;
  }

  /// 更新今日步数（本地传感器 / 手动记录后调用）
  static Future<void> updateTodaySteps(int steps) async {
    final today = _todayStr();
    final data = StepData(
      date: today,
      steps: steps,
      distance: steps * 0.7,
      calories: steps * 0.04,
      source: StepDataSource.local,
    );
    await _saveStepData(data);
  }

  /// 显式同步健康数据（由步数页/设置页按钮触发，会弹系统授权框）
  /// 返回 true 表示成功读取到真实步数
  static Future<bool> syncFromHealth() async {
    // 请求授权（用户手势中调用）
    final granted = await HealthService.requestAuthorization();
    if (!granted) return false;
    // 读取真实步数并覆盖今日数据
    final steps = await HealthService.syncTodaySteps();
    if (steps == null || steps <= 0) return false;
    await updateTodaySteps(steps);
    // 覆盖 source 为 health
    final today = _todayStr();
    await _saveStepData(StepData(
      date: today,
      steps: steps,
      distance: steps * 0.7,
      calories: steps * 0.04,
      source: StepDataSource.health,
    ));
    return true;
  }

  static Future<StepData?> _loadByDate(String date) async {
    final raw = AppStorage.getObject(_key, defaultValue: {});
    if (raw is Map) {
      final data = raw[date];
      if (data is Map) {
        return StepData.fromMap(Map<String, dynamic>.from(data));
      }
    }
    return null;
  }

  static Future<void> _saveStepData(StepData data) async {
    final raw = AppStorage.getObject(_key, defaultValue: {});
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    map[data.date] = data.toMap();
    await AppStorage.setObject(_key, map);
  }

  static String _todayStr() => _formatDate(DateTime.now());

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
