import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ============================================================
/// 「休 / 班」小标签（法定假日 / 调休补班）
///
/// 万年历页（calendar_page）与行程页迷你日历（mini_calendar）共用，
/// 保证两处语义与配色完全一致：
/// - 红 = 法定放假（休）
/// - 橙 = 调休补班（班）
/// - 非本月补位格降透明度，避免抢走当月的视觉重心
///
/// 位置约定（2026-09-10）：放在日期格**顶部**（数字上方）——
/// 「今天到底休不休」是用户看月历的第一诉求，顶部比底部更先入眼；
/// 与之配套的优先级规则：同一格里「休/班 > 农历」，有休/班时农历让位。
/// ============================================================
class ArrangementBadge extends StatelessWidget {
  const ArrangementBadge({
    super.key,
    required this.label,
    required this.isHoliday,
    this.inMonth = true,
    this.fontSize = 9,
  });

  /// 标签文本：休 / 班
  final String label;

  /// true=法定放假（红），false=调休补班（橙）
  final bool isHoliday;

  /// 是否本月格子（补位格整体降透明度）
  final bool inMonth;

  /// 字号：万年历 9，迷你日历可传更小值
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final Color color = isHoliday ? AppColors.danger : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: inMonth ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: inMonth ? 1.0 : 0.5),
        ),
      ),
    );
  }
}
