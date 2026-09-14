import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/lunar_service.dart';
import 'arrangement_badge.dart';
import 'common_widgets.dart';

/// ============================================================
/// 迷你日历（行程页「今日速览」使用）
/// - 复用 LunarService.generateCalendar 得到农历 / 节假日标签
/// - 支持上 / 下月切换，今天渐变高亮、周末红色
/// - 日期格顶部「休 / 班」标签（与万年历共用 ArrangementBadge，2026-09-10 需求）：
///   法定放假红、调休补班橙，与阴历标签并存显示；补班的周末数字不标红
/// - 点击日期或底部「查看完整万年历」→ 打开完整万年历页
/// ============================================================
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({super.key, this.onOpenFull, this.initialDate});

  /// 打开完整万年历（点击任意日期或底部入口时回调）
  final VoidCallback? onOpenFull;

  /// 初始日期。默认取「今天」；测试注入固定日期，避免用例随真实月份漂移。
  final DateTime? initialDate;

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  static const List<String> _weekHeaders = ['日', '一', '二', '三', '四', '五', '六'];

  /// 「休 / 班」标签字号：迷你日历格子比万年历矮（aspect 0.78），故比默认 9 略小。
  /// 单独提出来是因为「空槽位高度」也要用它算（ArrangementBadge.slotHeight），
  /// 两处字号必须是同一个值，否则槽高与标签实际高度脱钩、日期数字重新错位。
  static const double _kBadgeFontSize = 8.5;

  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() => setState(() {
        if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final days = LunarService.generateCalendar(_year, _month);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: widget.onOpenFull,
      child: Column(
        children: [
          // 月份切换栏
          Row(
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textPrimary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '$_year年$_month月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.textPrimary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 星期表头
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekHeaders[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (i == 0 || i == 6)
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 日期网格：用 MediaQuery 把本网格文本缩放上限钳到 1.3，
          // 防止华为等机型系统大字体把固定像素布局撑爆（垂直溢出）。
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                (MediaQuery.of(context).textScaler.scale(16) / 16) > 1.3
                    ? 1.3
                    : (MediaQuery.of(context).textScaler.scale(16) / 16),
              ),
            ),
            child: GridView.builder(
              // padding 显式置零：GridView 默认套用 MediaQuery.padding（状态栏 + 导航栏），
              // 嵌套非滚动网格会在顶部多出一段空白（2026-09-14 实测修复）。
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
                childAspectRatio: 0.78,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) => _buildDayCell(days[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(dynamic day) {
    final inMonth = day.isCurrentMonth as bool;
    final isToday = day.isToday as bool;
    final isWeekend = day.isWeekend as bool;
    final lunarLabel = day.lunarLabel as String;
    final holiday = day.holiday; // HolidayInfo?
    // 法定放假 / 调休补班：顶部「休 / 班」标签，优先级高于农历（与万年历一致）
    final bool isArrangement = holiday != null &&
        (holiday.isHoliday as bool || holiday.isWorkday as bool);

    return GestureDetector(
      onTap: widget.onOpenFull,
      // 内容垂直水平居中（2026-09-14 修正：原 topCenter+top 留白使日期贴顶、下方留空、
      // 视觉错位；华为大字体下尤明显）。溢出改由下方 GridView 的 MediaQuery 文本缩放上限(1.3)承担，
      // 不再整格 FittedBox 缩小（避免把日期数字缩到很小）；FittedBox 仅作极端兜底、居中。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              // 「休 / 班」小标签（顶部，与万年历共用同一组件）
              // 固定高度槽位：无休/班时也占同样高度，保证同一行所有格子的日期
              // 数字 y 坐标一致（与万年历同一修法，2026-09-14）。
              // 用「空 SizedBox + 条件渲染」而非 Visibility(maintainSize:true)：
              // 后者会把不可见的「休」字留在 widget 树里，污染无障碍语义与文本查找。
              SizedBox(
                height: ArrangementBadge.slotHeight(
                  _kBadgeFontSize,
                  MediaQuery.of(context).textScaler,
                ),
                child: isArrangement
                    ? ArrangementBadge(
                        // isArrangement 已保证 holiday 非空
                        label: holiday!.label,
                        isHoliday: holiday.isHoliday,
                        inMonth: inMonth,
                        // 迷你日历格子较矮（aspect 0.78），字号略小
                        fontSize: _kBadgeFontSize,
                      )
                    : null,
              ),
              // 直径 26 → 24（与万年历同一收紧幅度，保持两处观感一致）
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? Colors.white
                        : !inMonth
                            ? AppColors.textTertiary
                            // 周末红色；但调休补班的周末是「要上班的」，标红会自相矛盾
                            // （与万年历页同一规则，2026-09-10 对齐）
                            : (isWeekend && holiday?.isWorkday != true)
                                ? AppColors.danger
                                : AppColors.textPrimary,
                  ),
                ),
              ),
              // 日期数字 → 农历：2 → 1
              const SizedBox(height: 1),
              // 农历小标签（与休/班并存，始终显示）；限宽避免长标签横向撑大格子
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 36),
                child: Text(
                  lunarLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: !inMonth
                        ? AppColors.textTertiary.withValues(alpha: 0.6)
                        : (holiday != null ||
                                ['初一', '初二'].contains(lunarLabel))
                            ? AppColors.primary
                            : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
