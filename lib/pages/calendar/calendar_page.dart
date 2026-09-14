import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/calendar_models.dart';
import '../../services/holiday_data.dart';
import '../../services/lunar_service.dart';
import '../shared/widgets/arrangement_badge.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 万年历页（迁移自小程序 subpackages/tools/pages/calendar/calendar.js）
/// - 6x7 月历网格：日期格顶部「休/班」小标签 + 底部阴历标签**并存显示**
///   （标签在上、阴历在下；旧版「有休/班时农历让位」已弃用，假日格不再留白）
/// - 「休 / 班」标签：法定放假红、调休补班橙，与阴历标签同时显示
/// - 今天渐变高亮、周末红色（补班日不再标红）
/// - 左右滑动 / 卡片内按钮切换月份、「今天」一键回位
/// - 点击日期 → 老黄历详情面板（干支/生肖/宜忌/冲煞/纳音/彭祖/星宿/建除/星座）
/// - 即将到来的假期列表（倒计时）
/// ============================================================
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialDate});

  /// 初始定位日期（yyyy-MM-dd）：从首页节假倒计时卡跳入时携带，
  /// 页面直接定位到该日期（如「国庆节」→ 直接展示 10 月并选中当天）。
  final String? initialDate;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const List<String> _weekHeaders = ['日', '一', '二', '三', '四', '五', '六'];

  /// 页面主列表滚动控制器：点击「即将到来的假期」条目后平滑回顶，
  /// 让头部月份网格中的选中日期可见。
  final ScrollController _scrollController = ScrollController();

  late int _year; // 当前展示的年份
  late int _month; // 当前展示的月份（1-12）
  late DateTime _selected; // 选中的日期

  @override
  void initState() {
    super.initState();
    // 优先定位到传入日期；无参数时默认今天
    final target = DateTime.tryParse(widget.initialDate ?? '') ??
        DateTime.now();
    _year = target.year;
    _month = target.month;
    _selected = DateTime(target.year, target.month, target.day);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== 月份切换 ====================

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

  void _backToToday() {
    final now = DateTime.now();
    setState(() {
      _year = now.year;
      _month = now.month;
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  /// 点击网格日期：选中（含上月/下月补位格）
  void _selectDay(CalendarDayInfo day) {
    setState(() => _selected = DateTime.parse(day.dateStr));
  }

  @override
  Widget build(BuildContext context) {
    final days = LunarService.generateCalendar(_year, _month);
    final detail = LunarService.getLunarInfo(_selected);
    final upcoming = HolidayData.getUpcomingHolidays(4);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: '$_year年$_month月',
            // 月份切换已下移到日历卡片顶部（紧贴网格，单手可达），
            // 标题栏只留返回，避免同一功能两处入口的视觉噪音
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              // 左右滑动切换月份
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200) {
                  _nextMonth();
                } else if (velocity > 200) {
                  _prevMonth();
                }
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                children: [
                  FadeSlideIn(delay: 0, child: _buildCalendarCard(days)),
                  const SizedBox(height: AppSpacing.lg),
                  // 选中日期变化时重新进场
                  FadeSlideIn(
                    key: ValueKey(detail.dateStr),
                    delay: 0,
                    child: _buildDetailPanel(detail),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(delay: 60, child: _buildUpcomingHolidays(upcoming)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 月历卡片 ====================

  Widget _buildCalendarCard(List<CalendarDayInfo> days) => AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // 月份切换条：左右箭头 + 中间「今天」回位。
            // 由标题栏下移到网格正上方，视线不必上下跳，单手也够得着。
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _monthNavButton(
                  icon: Icons.chevron_left,
                  tooltip: '上个月',
                  onPressed: _prevMonth,
                ),
                TextButton.icon(
                  onPressed: _backToToday,
                  icon: const Icon(Icons.today, size: 16, color: AppColors.primary),
                  label: const Text('今天',
                      style: TextStyle(fontSize: 13, color: AppColors.primary)),
                ),
                _monthNavButton(
                  icon: Icons.chevron_right,
                  tooltip: '下个月',
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildWeekHeader(),
            _buildGrid(days),
          ],
        ),
      );

  /// 月份切换按钮：主色浅底圆形，与网格同处一张卡内，形成明确的可点暗示
  Widget _monthNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.primary),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.10),
          minimumSize: const Size(40, 40),
        ),
      );

  // ==================== 星期表头 ====================

  Widget _buildWeekHeader() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                _weekHeaders[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  // 周末红色表头
                  color: (i == 0 || i == 6)
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== 月历网格 ====================

  Widget _buildGrid(List<CalendarDayInfo> days) {
    // 文本缩放上限：华为等机型系统字体缩放 >1.0 时，固定像素的日期/农历字号被放大、
    // 整格内容总高超出格子 → 垂直溢出。把本网格文本缩放钳到 1.3，既保证任意系统缩放下
    // 都不溢出，又让日期数字保持清晰（不靠整格 FittedBox 模糊缩放）。
    final factor = MediaQuery.of(context).textScaler.scale(16) / 16;
    final capped = factor > 1.3 ? 1.3 : factor;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(capped)),
      child: GridView.builder(
      // padding 必须显式置零：GridView 默认会套用 MediaQuery.padding（本机 = 状态栏
      // 138px + 底部导航栏），而这个网格是非滚动的嵌套网格，于是顶部凭空多出一大段空白
      // ——正是「星期栏与日期内容间距过大」的根因（2026-09-14 实测修复）。
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.74,
      ),
      itemCount: days.length,
      itemBuilder: (context, i) => _buildDayCell(days[i]),
      ),
    );
  }

  Widget _buildDayCell(CalendarDayInfo day) {
    // 是否选中
    final isSelected = day.dateStr == LunarService.fmt(_selected);
    final inMonth = day.isCurrentMonth;
    final holiday = day.holiday;
    // 法定放假 / 调休补班：日期格**顶部**小标签显示「休 / 班」，优先级高于农历——
    // 农历日属于背景信息（下方老黄历卡片里还有完整版），
    // 而「今天到底休不休」是用户看月历的第一诉求，顶部比底部更先入眼。
    final isArrangement =
        holiday != null && (holiday.isHoliday || holiday.isWorkday);

    return GestureDetector(
      onTap: () => _selectDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.2)
              : null,
        ),
        // 垂直排布：休/班（顶部）→ 公历日数字 → 农历
        // - 「休 / 班」置于数字上方（2026-09-10 需求）；
        // - 阴历/农历**始终显示**，与休/班并存（标签在上、农历在下）；
        //   旧版「有休/班时农历让位」会让假日格下方留白、信息缺失，已改为两者同显。
        // - 内容**垂直水平居中**（mainAxisAlignment:center + FittedBox 居中）：
        //   早期用 topCenter+顶部留白让日期贴顶，但格子下方留空、与星期表头/邻格视觉错位，
        //   华为大字体下更明显 → 改为居中（这是修复「显示有问题」的关键）。
        // - 溢出防护：不再依赖整格 FittedBox 等比缩小（会把日期数字一起缩到很小、观感差），
        //   改由 _buildGrid 用 MediaQuery 把本网格文本缩放上限钳到 1.3——系统字体再大也不会
        //   撑爆固定像素布局，且日期保持清晰不模糊（2026-09-14 修复）。
        //   FittedBox 仅作极端情况兜底（scaleDown 居中），正常缩放下 scale=1 原样居中。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                // 「休 / 班」小标签（顶部）
                // 固定高度槽位：当天没有休/班时也占同样高度。
                // 否则「有标签的格子内容更高 → 整列居中后被整体顶下去」，
                // 同一行里日期数字的 y 坐标不一致，看起来就是"日期没对齐"（2026-09-14 修复）。
                //
                // 这里用「空 SizedBox + 条件渲染」，**不要**改成 Visibility(maintainSize:true)：
                // 后者虽然也占位，但会把一个不可见的「休」字留在 widget 树里，
                // 无障碍语义与 find.text 都会撞见这个幽灵文本（2026-09-14 单测抓到）。
                // 槽高由 ArrangementBadge.slotHeight 精确算出，与标签真实高度同源。
                SizedBox(
                  height: ArrangementBadge.slotHeight(
                    ArrangementBadge.defaultFontSize,
                    MediaQuery.of(context).textScaler,
                  ),
                  child: isArrangement
                      ? ArrangementBadge(
                          // isArrangement 为真时 holiday 必非空（流分析已确认）
                          label: holiday.label,
                          isHoliday: holiday.isHoliday,
                          inMonth: inMonth,
                        )
                      : null,
                ),
                // 休/班标签 → 日期数字：2 → 1
                const SizedBox(height: 1),
                // 公历日数字（今天渐变圆底）；直径 28 → 26 → 24，
                // 数字四周留白越少，「休/班标签↔数字」「数字↔农历」的视觉间距就越紧
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: day.isToday
                      ? BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                      color: day.isToday
                          ? Colors.white
                          : !inMonth
                              ? AppColors.textTertiary
                              // 周末红色；但调休补班的周末是「要上班的」，标红会自相矛盾
                              : (day.isWeekend && holiday?.isWorkday != true)
                                  ? AppColors.danger
                                  : AppColors.textPrimary,
                    ),
                  ),
                ),
                // 日期数字 → 农历：2 → 1
                const SizedBox(height: 1),
                // 农历小标签（与休/班并存，始终显示）；限宽保证长标签不把格子横向撑大
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 40),
                  child: Text(
                    day.lunarLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.0,
                      color: !inMonth
                          ? AppColors.textTertiary.withValues(alpha: 0.6)
                          : (day.holiday != null ||
                                  ['初一', '初二'].contains(day.lunarLabel))
                              ? AppColors.primary
                              : AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  // ==================== 老黄历详情面板 ====================

  Widget _buildDetailPanel(LunarDayInfo info) {
    final isToday = info.dateStr == LunarService.fmt(DateTime.now());
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：日期 + 周X + 节日 chip（节日移至行尾显示，与以前一致）
          // 垂直对齐：整行中线对齐（center），日期/周X/节日 chip 三元素中线一致
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${_selected.month}月${_selected.day}日',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 周X · 今天：用 Expanded + 省略号，避免长文案把整行撑破（之前右侧溢出 26px）
              Expanded(
                child: Text(
                  '周${LunarService.getWeekDay(_selected).replaceAll('周', '')}'
                  '${isToday ? ' · 今天' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              // 节日 chip：移至行尾展示（与以前一致）
              if (info.holidayName.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradientWith(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '🎉 ${info.holidayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.lunarFull,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${info.ganzhiYear}年 ${info.ganzhiMonth}月 ${info.ganzhiDay}日'
            ' · 属${info.zodiac} · ${info.constellation}'
            '${info.jieqi.isNotEmpty ? ' · ${info.jieqi}' : ''}'
            '${info.festivalsText.isNotEmpty ? ' · ${info.festivalsText}' : ''}',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          // 宜 / 忌
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildYiJiBox('宜', info.yiText, AppColors.success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildYiJiBox('忌', info.jiText, AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 老黄历信息行
          _buildInfoRow(Icons.shield_outlined, '冲煞', info.chongSha),
          _buildInfoRow(Icons.music_note_outlined, '纳音', info.naYin),
          _buildInfoRow(Icons.self_improvement, '彭祖', info.pengZu),
          _buildInfoRow(Icons.star_outline, '星宿', info.xiu.isEmpty
              ? ''
              : '${info.xiu}（${info.xiuLuck}）'),
          _buildInfoRow(Icons.schedule, '值星', info.zhiXing),
          _buildInfoRow(Icons.calendar_view_day, '周数',
              '第${info.weekOfYear}周 · 年内第${info.dayOfYear}天 · ${info.diffText}'),
          const SizedBox(height: 12),
          // 贴心建议
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientWith(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: AppColors.primary),
                Expanded(
                  child: Text(
                    info.suggestion,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 宜 / 忌 彩色块
  Widget _buildYiJiBox(String title, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              )),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? '—' : text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 老黄历信息行
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 即将到来的假期 ====================

  Widget _buildUpcomingHolidays(
      List<({String date, String name, int daysFromNow})> upcoming) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '即将到来的假期'),
        const SizedBox(height: 4),
        if (upcoming.isEmpty)
          const AppCard(
            child: Text('暂无更多假期数据',
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  _buildHolidayRow(upcoming[i]),
                  if (i != upcoming.length - 1)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHolidayRow(
      ({String date, String name, int daysFromNow}) item) {
    final parts = item.date.split('-');
    return InkWell(
      onTap: () {
        final target = DateTime.parse(item.date);
        setState(() {
          _year = target.year;
          _month = target.month;
          _selected = target;
        });
        // 切换月份/选中日期后平滑滚动回页面头部，
        // 让用户看到月份网格中高亮的对应日期（含休/班标签）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            );
          }
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradientWith(0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '${parts[1]}/${parts[2]}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // 倒计时
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: item.daysFromNow == 0
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Text(
                item.daysFromNow == 0
                    ? '今天！'
                    : '还有 ${item.daysFromNow} 天',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.daysFromNow == 0
                      ? AppColors.danger
                      : AppColors.warning,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
