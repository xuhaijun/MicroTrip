import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/pages/calendar/calendar_page.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';

/// 回归（2026-09-10 界面优化）：
/// 1) 月份切换从标题栏下移到日历卡片顶部（贴近网格），标题栏只留返回；
/// 2) 日期格顶部不再挂节日/休班角标 —— 农历标签（节气 > 节日 > 初一月份 > 农历日）
///    与下方老黄历卡片已承载同一信息，小格里重复显示只会挤压日期数字。
///
/// 用固定 initialDate=2026-09-25 让断言与「今天」无关：该月数据里
/// 09-19 为国庆调休（班）、09-25~27 为中秋节（休），正好覆盖两类角标。
void main() {
  testWidgets('月份切换位于日历卡片内，日期格不再显示假日角标', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CalendarPage(initialDate: '2026-09-25'),
    ));
    await tester.pumpAndSettle();

    // ---------------- 1. 标题栏不再有月份切换箭头 ----------------
    final header = find.byType(GradientHeader);
    expect(
      find.descendant(of: header, matching: find.byIcon(Icons.chevron_left)),
      findsNothing,
      reason: '标题栏应去掉「上个月」箭头',
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(Icons.chevron_right)),
      findsNothing,
      reason: '标题栏应去掉「下个月」箭头',
    );

    // ---------------- 2. 日历卡片内提供切换 ----------------
    final card = find.byType(AppCard).first; // 日历卡片位于页面首位
    final prevBtn =
        find.descendant(of: card, matching: find.byIcon(Icons.chevron_left));
    final nextBtn =
        find.descendant(of: card, matching: find.byIcon(Icons.chevron_right));
    expect(prevBtn, findsOneWidget, reason: '日历卡片内应有「上个月」');
    expect(nextBtn, findsOneWidget, reason: '日历卡片内应有「下个月」');
    expect(find.descendant(of: card, matching: find.text('今天')), findsOneWidget,
        reason: '「今天」回位应仍在日历卡片内');

    expect(find.text('2026年9月'), findsOneWidget, reason: '初始应展示 2026 年 9 月');

    // ---------------- 3. 日期格不再有假日角标 ----------------
    expect(find.text('休'), findsNothing,
        reason: '中秋节假期（09-25~27）不应再显示「休」角标');
    expect(find.text('班'), findsNothing,
        reason: '国庆调休（09-19）不应再显示「班」角标');
    // 信息并未丢失：节日名仍由农历小标签承载
    expect(find.text('中秋节'), findsWidgets,
        reason: '农历标签仍应显示节日名（下面卡片之外的第二处呈现）');

    // ---------------- 4. 卡片内切换月份可用 ----------------
    await tester.tap(prevBtn);
    await tester.pumpAndSettle();
    expect(find.text('2026年8月'), findsOneWidget, reason: '点左箭头应切到上个月');

    await tester.tap(nextBtn);
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget, reason: '点右箭头应切到下个月');

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget, reason: '「今天」应回到本月');
  });
}
