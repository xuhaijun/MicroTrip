// ============================================================
// 一日游攻略模型（迁移自小程序 subpackages/travel/pages/oneday/oneday.js）
// 5 段式时间轴：上午历史 → 中午美食 → 下午公园 → 傍晚日落 → 晚上夜市
// ============================================================

/// 时间轴单段行程
class OneDayPlanItem {
  const OneDayPlanItem({
    required this.time,
    required this.period,
    required this.icon,
    required this.title,
    required this.desc,
  });

  /// 时间点，如「09:00」
  final String time;

  /// 时段，如「上午」「中午」
  final String period;

  /// emoji 图标
  final String icon;

  /// 标题
  final String title;

  /// 描述
  final String desc;
}
