// ============================================================
// 步数数据模型（Phase 2）
//
// 对应小程序中步数展示需求。Phase 4 将接入微信运动解密，
// 当前 Phase 2 先用本地传感器 / mock 数据支持首页步数卡片展示。
// ============================================================

/// 单日步数统计
class StepData {
  StepData({
    required this.date,
    required this.steps,
    this.distance,
    this.calories,
    this.source = StepDataSource.local,
  });

  /// 日期（YYYY-MM-DD）
  final String date;
  /// 步数
  final int steps;
  /// 距离（米，按步幅 0.7m 估算）
  final double? distance;
  /// 消耗热量（千卡，按体重 70kg / 步幅 0.7m / 速度 1.4m/s 估算）
  final double? calories;
  /// 数据来源
  final StepDataSource source;

  /// 距离格式化
  String get distanceText {
    final d = distance ?? steps * 0.7;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)} km';
    return '${d.round()} m';
  }

  /// 热量格式化
  String get caloriesText {
    final c = calories ?? _estimateCalories(steps);
    return '${c.toStringAsFixed(0)} kcal';
  }

  /// 步数格式化（千位分隔）
  String get stepsText => steps.toString();

  /// 估算热量（基于经验公式：步数 × 0.04 kcal）
  static double _estimateCalories(int steps) => steps * 0.04;

  /// 根据步数返回运动等级
  StepLevel get level {
    if (steps >= 10000) return StepLevel.excellent;
    if (steps >= 7000) return StepLevel.good;
    if (steps >= 4000) return StepLevel.normal;
    return StepLevel.low;
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'steps': steps,
        'dist': distance,
        'cal': calories,
        'src': source.name,
      };

  factory StepData.fromMap(Map<String, dynamic> m) => StepData(
        date: m['date'].toString(),
        steps: (m['steps'] as num).toInt(),
        distance: m['dist'] != null ? (m['dist'] as num).toDouble() : null,
        calories: m['cal'] != null ? (m['cal'] as num).toDouble() : null,
        source: StepDataSource.values.firstWhere(
          (e) => e.name == m['src']?.toString(),
          orElse: () => StepDataSource.local,
        ),
      );
}

/// 步数数据来源
enum StepDataSource {
  /// 本地传感器 / pedomometer
  local,
  /// 微信运动（Phase 4 接入，Flutter 端不可用，保留枚举兼容小程序数据）
  wechat,
  /// mock 数据（未配置时降级）
  mock,
  /// 系统健康数据（Phase 4：iOS HealthKit / Android Health Connect）
  health,
}

/// 运动等级
enum StepLevel {
  low,       // < 4000
  normal,    // 4000-7000
  good,      // 7000-10000
  excellent, // >= 10000
}

extension StepLevelExt on StepLevel {
  String get label => switch (this) {
        StepLevel.low => '久坐',
        StepLevel.normal => '一般',
        StepLevel.good => '活跃',
        StepLevel.excellent => '运动达人',
      };

  /// 进度百分比（对应首页环形进度条）
  double get progress => switch (this) {
        StepLevel.low => 0.3,
        StepLevel.normal => 0.55,
        StepLevel.good => 0.8,
        StepLevel.excellent => 1.0,
      };
}
