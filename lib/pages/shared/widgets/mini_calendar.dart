import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/lunar_service.dart';
import 'common_widgets.dart';

/// ============================================================
/// 迷你日历（行程页「今日速览」使用）
/// - 复用 LunarService.generateCalendar 得到农历 / 节假日标签
/// - 支持上 / 下月切换，今天渐变高亮、周末红色
/// - 点击日期或底部「查看完整万年历」→ 打开完整万年历页
/// ============================================================
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({super.key, this.onOpenFull});

  /// 打开完整万年历（点击任意日期或底部入口时回调）
  final VoidCallback? onOpenFull;

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  static const List<String> _weekHeaders = ['日', '一', '二', '三', '四', '五', '六'];

  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
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
          const SizedBox(height: 6),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 2,
              childAspectRatio: 0.95,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) => _buildDayCell(days[i]),
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

    return GestureDetector(
      onTap: widget.onOpenFull,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
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
                        : isWeekend
                            ? AppColors.danger
                            : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lunarLabel,
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
        ],
      ),
    );
  }
}
