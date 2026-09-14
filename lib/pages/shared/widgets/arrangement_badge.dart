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
/// 阴历/农历与休/班**并存**（标签在上、农历在下），两者同时显示，不互相让位。
/// ============================================================
class ArrangementBadge extends StatelessWidget {
  const ArrangementBadge({
    super.key,
    required this.label,
    required this.isHoliday,
    this.inMonth = true,
    this.fontSize = defaultFontSize,
  });

  /// 万年历默认字号；迷你日历格子较矮，传更小值。
  static const double defaultFontSize = 9;

  /// 行高倍数与上下内边距。
  /// **必须与 [build] 里实际用的值同源**——一旦分开写死，日历的「空槽位」高度
  /// 就会和标签真实高度脱钩，日期数字又会重新错位（见 [slotHeight]）。
  static const double _lineHeight = 1.1;
  static const double _verticalPadding = 0.5;

  /// 标签在给定字号 / 文本缩放下的**真实高度**（文字行高 + 上下内边距）。
  ///
  /// 用途：万年历 / 迷你日历要在「当天没有休/班」的格子里放一个**等高的空槽位**，
  /// 使同一行所有格子内容高度一致 → 日期数字纵向对齐（2026-09-14 修复）。
  /// 因为 [build] 的 TextStyle 显式设了 `height`，行高 = `scale(fontSize) * 1.1`
  /// 与字体度量无关，所以这个高度可以精确算出来，不用猜。
  static double slotHeight(double fontSize, TextScaler textScaler) =>
      textScaler.scale(fontSize) * _lineHeight + _verticalPadding * 2;

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
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: inMonth ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          height: _lineHeight,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: inMonth ? 1.0 : 0.5),
        ),
      ),
    );
  }
}
