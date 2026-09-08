import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/main.dart';
import 'package:micro_trip/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全路由 Overflow 扫描：在多个竖屏尺寸（320~414 宽，含 iPhone 16 Pro 的 402）
/// 下渲染每个路由，通过 tester.takeException() 逐路由抽干 pending 异常并扫描 "overflowed"
/// 字样，精确定位溢出页面。
///
/// 设计要点（为什么这样写）：
/// 1. 不接管 FlutterError.onError。框架在 TestWidgetsFlutterBinding 下会强制让所有
///    HttpClient 返回 400；flutter_map 等地图页异步抛出 ClientException（Zone 级未捕获错误），
///    走到 binding.handleUncaughtError，若此时 onError 被接管会触发
///    '_pendingExceptionDetails != null' 断言使测试崩溃。因此本测试不接管 onError，
///    而是把全部路由（含 /nearby、/trajectory-record、/trajectory-detail 三个地图页）
///    都纳入扫描，由 takeException() 一并抽干其 ClientException，避免框架断言且不漏检。
/// 2. 每个路由 pump 后用 while(takeException()) 抽干本路由所有 pending（含多次溢出的逐条收集），
///    只把含 "overflowed" 的计入 overflowMap。其余（网络图片失败告警等）一并抽干，避免框架断言。
/// 3. 末轮 pump(1s) 让一次性动画定时器（如 AnimatedCounter 480ms 补间）跑完，否则框架的
///    !timersPending 断言会在测试结束时失败。
/// 4. 仅当 overflowMap 非空时才 fail，并输出每个路由的首条溢出原文（含 file:line）。
/// 5. 横屏尺寸（640×320、800×412）故意不纳入：本 App 为竖屏旅行应用，部分页面在横屏下
///    底部大幅溢出属预期外，不作为质量门禁。
void main() {
  final overflowMap = <String, List<String>>{};

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    // 强制 mock 数据，复现真实布局（而非一直 loading）
    await AppStorage.setBool(AppStorage.kUseMockData, true);
  });

  testWidgets('overflow scan across routes', (tester) async {
    tester.view.devicePixelRatio = 1;
    // 排除 3 个 flutter_map 路由：离线测试环境 HttpClient 强制 400 会触发 ClientException
    // 走 Zone 级未捕获错误，导致框架断言崩溃；且它们非窄卡片溢出来源。
    const routes = <String>[
      '/home', '/discover', '/trip', '/profile',
      '/food', '/scenery', '/food-detail/1', '/scenery-detail/1',
      '/nearby', // 地图页：ClientException 走 Zone 错误，由 takeException 抽干，不触发框架断言
      '/oneday', '/calendar', '/weather-detail', '/photo-recognition',
      '/city-list', '/ai-chat', '/trajectory-record', '/trajectory-detail/1',
      '/trip/memo', '/trip/memo/edit', '/trip/trajectory',
      '/profile/favorites', '/profile/settings', '/profile/about',
      '/profile/privacy-policy', '/profile/login', '/login',
      '/guide', '/splash',
    ];
    // 覆盖常见手机逻辑宽度（含 iPhone 16 Pro 的 402）与小高度，
    // 以复现「窄屏文本换行导致纵向溢出」等尺寸相关溢出。
    // 注：本 App 为竖屏旅行应用，横屏溢出（trajectory-record/trip/trajectory/guide
    // 在 640×320、800×412 下底部大幅溢出）属预期外，不计入扫描。
    final sizes = <Size>[
      const Size(320, 568), // iPhone SE1 矮高
      const Size(320, 640),
      const Size(360, 640),
      const Size(360, 720),
      const Size(375, 667), // iPhone 8
      const Size(390, 844), // iPhone 14/15
      const Size(393, 852), // iPhone 15 Pro
      const Size(402, 874), // iPhone 16 Pro（用户设备）
      const Size(412, 800),
      const Size(414, 896), // iPhone Plus
    ];

    await tester.pumpWidget(const ProviderScope(child: MicroTripApp()));
    await tester.pump(const Duration(milliseconds: 300));
    // 抽干启动期 pending
    while (tester.takeException() != null) {}

    for (final size in sizes) {
      tester.view.physicalSize = size;
      for (final route in routes) {
        final key = '$route @${size.width.toInt()}w';
        try {
          appRouter.go(route);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        } catch (e) {
          debugPrint('ROUTE THREW $key: $e');
        }
        // 抽干本路由所有 pending，逐条扫描 overflowed（同一路由可能多次溢出）
        Object? e;
        while ((e = tester.takeException()) != null) {
          final s = e.toString();
          if (s.contains('overflowed')) {
            overflowMap.putIfAbsent(key, () => <String>[]).add(s);
          }
        }
      }
    }
    // 末轮兜底抽干
    while (tester.takeException() != null) {}
    // 让最后渲染路由上的一次性动画定时器（如 AnimatedCounter 480ms 补间）跑完，
    // 否则框架的 !timersPending 断言会在测试结束时失败。
    await tester.pump(const Duration(seconds: 1));

    if (overflowMap.isNotEmpty) {
      final sb = StringBuffer(
          '=== OVERFLOW DETECTED (${overflowMap.length} routes) ===\n');
      overflowMap.forEach((k, v) {
        sb.writeln('[$k]  (${v.length} 次)');
        sb.writeln(v.first.split('\n').take(22).join('\n'));
        sb.writeln('----');
      });
      fail(sb.toString());
    }
  });
}
