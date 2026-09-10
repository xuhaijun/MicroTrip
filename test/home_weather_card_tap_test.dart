import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/main.dart';
import 'package:micro_trip/pages/city/city_list_page.dart';
import 'package:micro_trip/pages/shared/weather_detail_page.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';
import 'package:micro_trip/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：首页天气卡（GradientHeader）内任意位置都应跳转天气详情。
///
/// 根因：卡内只有「天气 Row」被 GestureDetector 包住，且默认 HitTestBehavior.deferToChild
/// 只在子节点上命中 —— 点日期副标题、卡片左右/底部留白都没有反应，于是出现
/// 「整张卡看着能点、点偏一点就没反应」的体验断点。
/// 修复：GradientHeader 新增 onCardTap，用 HitTestBehavior.opaque 包住整卡；
/// 标题区（切城市）与刷新按钮层级更深，仍在手势竞技场中优先胜出。
void main() {
  Future<void> boot(WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    // 强制 mock 数据，避免首屏一直 loading
    await AppStorage.setBool(AppStorage.kUseMockData, true);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844); // iPhone 14/15
    await tester.pumpWidget(const ProviderScope(child: MicroTripApp()));
    await tester.pump(const Duration(milliseconds: 300));
    while (tester.takeException() != null) {}

    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    while (tester.takeException() != null) {}
  }

  /// 让 FadeSlideIn 的延迟定时器全部跑完：
  /// 否则测试结束时框架的 !timersPending 断言会失败（与断言内容无关的假失败）。
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    while (tester.takeException() != null) {}
  }

  /// 回到首页（清掉可能的 push 栈）
  Future<void> backHome(WidgetTester tester) async {
    while (appRouter.canPop()) {
      appRouter.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await drainTimers(tester);
  }

  Finder header() => find.byType(GradientHeader).first;

  testWidgets('首页天气卡底部留白点击可跳天气详情', (tester) async {
    await boot(tester);
    expect(header(), findsOneWidget, reason: '首页应有天气卡（渐变头部）');

    final rect = tester.getRect(header());
    // 卡片底部 20px 是 padding、左右 20px 也是 padding：
    // 这些区域没有子节点，旧实现（deferToChild）点这里毫无反应
    await tester.tapAt(Offset(rect.left + 4, rect.bottom - 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WeatherDetailPage), findsOneWidget,
        reason: '点卡片底部留白应进入天气详情页');

    await backHome(tester);
  });

  testWidgets('首页天气卡日期副标题点击可跳天气详情', (tester) async {
    await boot(tester);

    // 日期/农历副标题（卡内、天气 Row 之外的兄弟节点）
    final subtitle = find.descendant(
        of: header(), matching: find.textContaining('农历'));
    expect(subtitle, findsOneWidget, reason: '天气卡应有日期 · 农历副标题');

    await tester.tap(subtitle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WeatherDetailPage), findsOneWidget,
        reason: '点日期副标题应进入天气详情页');

    await backHome(tester);
  });

  testWidgets('天气卡标题（城市名）仍走切城市，不被整卡点击吞掉', (tester) async {
    await boot(tester);

    final rect = tester.getRect(header());
    // 标题行：卡内 padding.top + 16 之下的一行文字，x 取左侧标题文字区域
    await tester.tapAt(Offset(rect.left + 30, rect.top + 28));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CityListPage), findsOneWidget,
        reason: '点城市名应进入城市列表');
    expect(find.byType(WeatherDetailPage), findsNothing,
        reason: '标题区点击不应同时触发整卡跳转');

    await drainTimers(tester);
  });
}
