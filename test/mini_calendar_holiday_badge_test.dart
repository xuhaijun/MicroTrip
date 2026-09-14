import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/theme/app_theme.dart';
import 'package:micro_trip/pages/shared/widgets/arrangement_badge.dart';
import 'package:micro_trip/pages/shared/widgets/mini_calendar.dart';
import 'package:micro_trip/services/lunar_service.dart';

/// 行程页迷你日历「休 / 班」标签回归测试（2026-09-10）。
///
/// 需求：行程页的日历控件也要有休/班标签 —— 与万年历页共用 [ArrangementBadge]，
/// 同一套规则：顶部标签、休红/班橙、阴历与休/班并存显示、补班的周末数字不标红。
///
/// 固定 initialDate=2026-09-25（该月数据与万年历用例一致）：
///   09-19 国庆调休（班，周六）/ 09-25 / 26 / 27 中秋节（休）/ 09-20 普通周日
void main() {
  Finder dayCell(String dayText) => find
      .ancestor(
        of: find.text(dayText),
        matching: find.byType(Column),
      )
      .first;

  Future<void> pumpMini(WidgetTester tester) async {
    // initialDate 非 const 构造，整棵树不能用 const
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MiniCalendar(initialDate: DateTime(2026, 9, 25)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('法定假期显示「休」，且阴历并存显示', (tester) async {
    await pumpMini(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 25));
    final cell = dayCell('25');

    expect(find.descendant(of: cell, matching: find.byType(ArrangementBadge)),
        findsOneWidget, reason: '09-25 中秋节应显示「休」标签');
    expect(find.descendant(of: cell, matching: find.text('休')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text(lunar)), findsOneWidget,
        reason: '有「休」时阴历标签仍并存显示（标签在上、农历在下）');
  });

  testWidgets('调休补班显示「班」，且补班周六的数字不标红', (tester) async {
    await pumpMini(tester);

    final cell = dayCell('19');
    expect(find.descendant(of: cell, matching: find.text('班')), findsOneWidget,
        reason: '09-19 国庆调休补班应显示「班」');

    final workDayNum = tester.widget<Text>(find.text('19'));
    expect(workDayNum.style?.color, isNot(AppColors.danger),
        reason: '补班周六不应标红（与万年历页同一规则）');

    // 09-20 普通周日仍标红
    final weekendNum = tester.widget<Text>(find.text('20'));
    expect(weekendNum.style?.color, AppColors.danger,
        reason: '正常周末日期数字仍应标红');
  });

  testWidgets('休/班标签位于日期格顶部（数字上方）', (tester) async {
    await pumpMini(tester);

    final badge = find.descendant(
      of: dayCell('25'),
      matching: find.byType(ArrangementBadge),
    );
    expect(badge, findsOneWidget);

    final badgeTop = tester.getTopLeft(badge).dy;
    final numberTop = tester.getTopLeft(find.text('25')).dy;
    expect(badgeTop, lessThan(numberTop), reason: '「休」应在日期数字上方');
  });

  /// 同万年历页：给「休/班」标签套 Visibility(maintainSize) 固定槽位，
  /// 避免有标签的格子内容更高、居中后把日期数字顶偏（同一行数字高低不齐）。
  testWidgets('同一行内：有休/班与无休/班格子的日期数字纵向对齐', (tester) async {
    await pumpMini(tester);

    double numberTop(String dayText) => tester
        .getTopLeft(find.descendant(
          of: dayCell(dayText),
          matching: find.text(dayText),
        ))
        .dy;

    // 2026-09 网格（周日起始）：09-13(普通日) 与 09-19(调休补班) 同行
    expect(numberTop('13'), closeTo(numberTop('19'), 0.5),
        reason: '同行内「有班」的格子不应把日期数字顶偏');
    // 09-20(普通日) 与 09-25(中秋「休」) 同行
    expect(numberTop('20'), closeTo(numberTop('25'), 0.5),
        reason: '同行内「有休」的格子不应把日期数字顶偏');
  });

  testWidgets('普通日期仍显示农历标签，不出现休/班', (tester) async {
    await pumpMini(tester);

    final lunar = LunarService.getLunarDayLabel(DateTime(2026, 9, 20));
    final cell = dayCell('20');

    expect(find.descendant(of: cell, matching: find.text(lunar)),
        findsOneWidget, reason: '普通日期仍是农历标签');
    expect(find.descendant(of: cell, matching: find.byType(ArrangementBadge)),
        findsNothing);
  });
}
