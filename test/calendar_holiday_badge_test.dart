import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/theme/app_theme.dart';
import 'package:micro_trip/pages/calendar/calendar_page.dart';
import 'package:micro_trip/services/lunar_service.dart';

/// 万年历日期格「休 / 班」标签回归测试（2026-09-10）。
///
/// 需求：如果是法定假日或调班，日期格底部小标签显示休/班提示，
/// 且优先级高于农历日期（同一位置只能放一个，休/班赢）。
///
/// 固定 initialDate=2026-09-25，该月数据：
///   09-19 国庆调休（班，周六）
///   09-25 / 26 / 27 中秋节（休）
///   10-01 ~ 10-03 国庆节（休）→ 作为下月补位格出现在同一屏（降透明度）
void main() {
  /// 定位某一天所在的日期格（AnimatedContainer = 格的背景容器）
  Finder dayCell(String dayText) => find
      .ancestor(
        of: find.text(dayText),
        matching: find.byType(AnimatedContainer),
      )
      .first;

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CalendarPage(initialDate: '2026-09-25'),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('法定假期显示「休」，并让位掉农历标签', (tester) async {
    await pumpCalendar(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 25));
    final cell = dayCell('25');

    expect(find.descendant(of: cell, matching: find.text('休')), findsOneWidget,
        reason: '09-25 中秋节应显示「休」标签');
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsNothing,
        reason: '有「休」时农历标签应让位（优先级：休/班 > 农历）');
  });

  testWidgets('调休补班显示「班」，并让位掉农历标签', (tester) async {
    await pumpCalendar(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 19));
    final cell = dayCell('19');

    expect(find.descendant(of: cell, matching: find.text('班')), findsOneWidget,
        reason: '09-19 国庆调休应显示「班」标签');
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsNothing,
        reason: '有「班」时农历标签应让位');
  });

  testWidgets('普通日期仍显示农历标签，不出现休/班', (tester) async {
    await pumpCalendar(tester);

    // 09-20（周日）既非法定假期也非调休
    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 20));
    final cell = dayCell('20');

    expect(find.descendant(of: cell, matching: find.text(lunar)), findsOneWidget,
        reason: '普通日期底部应仍是农历标签');
    expect(find.descendant(of: cell, matching: find.text('休')), findsNothing);
    expect(find.descendant(of: cell, matching: find.text('班')), findsNothing);
  });

  testWidgets('休=红、班=橙；补班的周末日期数字不再标红', (tester) async {
    await pumpCalendar(tester);

    // ---- 休：danger 色 ----
    final restBadge = tester.widget<Text>(find
        .descendant(of: dayCell('25'), matching: find.text('休'))
        .first);
    expect(restBadge.style?.color, AppColors.danger, reason: '「休」应为红色');

    // ---- 班：accent 色 ----
    final workBadge = tester.widget<Text>(find
        .descendant(of: dayCell('19'), matching: find.text('班'))
        .first);
    expect(workBadge.style?.color, AppColors.accent, reason: '「班」应为橙色');

    // ---- 09-19 是周六（补班）→ 数字用普通色，避免「周末红」自相矛盾 ----
    final workDayNum = tester.widget<Text>(find.text('19'));
    expect(workDayNum.style?.color, isNot(AppColors.danger),
        reason: '调休补班的周末不应把日期数字标红');

    // ---- 09-20 是周日（正常休息）→ 数字仍标红 ----
    final weekendNum = tester.widget<Text>(find.text('20'));
    expect(weekendNum.style?.color, AppColors.danger,
        reason: '正常周末日期数字仍应标红');
  });

  testWidgets('下月补位格同样显示休/班（覆盖跨月假期）', (tester) async {
    await pumpCalendar(tester);

    // 2026-09 网格为 35 格：2 个上月补位 + 30 天 + 3 个下月补位（10-01~03，国庆节）
    // → 休 共 6 处（09-25/26/27 + 10-01/02/03），班 共 1 处（09-19）
    expect(find.text('休'), findsNWidgets(6),
        reason: '中秋节 3 天 + 下月补位的国庆节 3 天，共 6 个「休」');
    expect(find.text('班'), findsOneWidget, reason: '9 月仅 09-19 一天调休补班');
  });
}
