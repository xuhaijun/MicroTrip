import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/theme/app_theme.dart';
import 'package:micro_trip/pages/calendar/calendar_page.dart';
import 'package:micro_trip/pages/shared/widgets/arrangement_badge.dart';
import 'package:micro_trip/services/lunar_service.dart';

/// 万年历日期格「休 / 班」标签回归测试（2026-09-10）。
///
/// 需求：如果是法定假日或调班，日期格底部小标签显示休/班提示，
/// 阴历标签在底部**并存显示**（标签在上、农历在下，不互相让位）。
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

  testWidgets('法定假期显示「休」，且阴历并存显示', (tester) async {
    await pumpCalendar(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 25));
    final cell = dayCell('25');

    expect(find.descendant(of: cell, matching: find.text('休')), findsOneWidget,
        reason: '09-25 中秋节应显示「休」标签');
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsOneWidget,
        reason: '有「休」时阴历标签仍并存显示（标签在上、农历在下）');
  });

  testWidgets('调休补班显示「班」，且阴历并存显示', (tester) async {
    await pumpCalendar(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 19));
    final cell = dayCell('19');

    expect(find.descendant(of: cell, matching: find.text('班')), findsOneWidget,
        reason: '09-19 国庆调休应显示「班」标签');
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsOneWidget,
        reason: '有「班」时阴历标签仍并存显示');
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

  testWidgets('休/班标签位于日期格顶部（数字上方）', (tester) async {
    await pumpCalendar(tester);

    // 2026-09-10 需求：标签从底部移到日期格顶部 —— 徽章的纵坐标必须小于日期数字
    final badge = find.descendant(
      of: dayCell('25'),
      matching: find.byType(ArrangementBadge),
    );
    expect(badge, findsOneWidget);

    final badgeTop = tester.getTopLeft(badge).dy;
    final numberTop = tester.getTopLeft(find.text('25')).dy;
    expect(badgeTop, lessThan(numberTop),
        reason: '「休」标签应显示在日期数字上方');

    // 数字下方的阴历标签仍并存显示（顶部标签 + 数字 + 阴历）
    final cell = dayCell('25');
    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 25));
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsOneWidget,
        reason: '「休」标签下方仍显示阴历标签，两者并存');
  });

  /// 2026-09-14 修复：有「休/班」的格子比普通格子多一行标签，内容更高；
  /// 在「内容居中」的格子里，多出来的高度会把整列内容顶偏，表现为**同一行日期数字高低不齐**
  /// （真机量化：带标签行的数字低 20px）。
  ///
  /// 修法不是调间距，而是给标签套 `Visibility(maintainSize: true)`——
  /// 无标签的格子也保留同样高度的空槽，两列内容高度一致 → 居中后数字同高。
  /// 这个用例把「同一行日期数字必须同高」钉成契约，防止以后被改回条件渲染
  /// （条件渲染观感上"少一个空盒子"，但会重新引回错位，肉眼还不容易发现）。
  testWidgets('同一行内：有休/班与无休/班格子的日期数字纵向对齐', (tester) async {
    await pumpCalendar(tester);

    double numberTop(String dayText) => tester
        .getTopLeft(find.descendant(
          of: dayCell(dayText),
          matching: find.text(dayText),
        ))
        .dy;

    // 2026-09 网格（周日起始）：第 3 行 = 09-13(日) ~ 09-19(六)
    //   09-19 是国庆调休补班 → 带「班」标签，09-13 是普通周日 → 无标签
    expect(numberTop('13'), closeTo(numberTop('19'), 0.5),
        reason: '同行内「有班」的格子不应把日期数字顶偏');

    // 第 4 行 = 09-20(日) ~ 09-26(六)
    //   09-25/26 是中秋节 → 带「休」标签，09-20 是普通周日 → 无标签
    expect(numberTop('20'), closeTo(numberTop('25'), 0.5),
        reason: '同行内「有休」的格子不应把日期数字顶偏');
  });
}
