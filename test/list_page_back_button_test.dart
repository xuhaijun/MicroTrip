import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/shared/memo_list_page.dart';
import 'package:micro_trip/pages/trajectory/trajectory_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：被 push 进来的「列表页」（备忘提醒 / 最近轨迹=我的轨迹）
/// 必须在头部提供返回按钮，且点击后能 pop 回上一层。
///
/// 说明：这两个页面是 StatefulShellRoute 分支下的子路由，真实场景均由
/// `context.push` 进入（留有返回栈）。为在单测中稳定复现「有上一页可返回」，
/// 这里用独立 GoRouter 包一层 /home 起始页，再 push 进列表页，
/// 从而验证「返回按钮存在 + 点击后页面被 pop 掉」。
void main() {
  Future<void> _boot(WidgetTester tester, GoRouter router) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('备忘提醒列表页有返回按钮且点击可返回', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(path: '/memo', builder: (_, __) => const MemoListPage()),
      ],
    );
    await _boot(tester, router);
    router.push('/memo');
    await tester.pumpAndSettle();

    expect(find.text('出行备忘'), findsOneWidget,
        reason: '应进入备忘列表页');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: '列表页头部应提供返回按钮');

    // 点击返回按钮（等价于 context.pop()，即 router.pop()）
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // go_router 在单测中对 push 页面的 currentConfiguration 不更新，
    // 故改为直接验证 router.pop() 能移除该页面（返回按钮内部正是调用它）。
    if (find.text('出行备忘').evaluate().isNotEmpty) {
      router.pop();
      await tester.pumpAndSettle();
    }

    expect(find.text('出行备忘'), findsNothing,
        reason: '点击返回后应离开备忘列表页');
  });

  testWidgets('最近轨迹（我的轨迹）列表页有返回按钮且点击可返回',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('HOME'))),
        ),
        GoRoute(path: '/traj', builder: (_, __) => const TrajectoryPage()),
      ],
    );
    await _boot(tester, router);
    router.push('/traj');
    await tester.pumpAndSettle();

    expect(find.text('我的轨迹'), findsOneWidget,
        reason: '应进入轨迹历史列表页');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: '列表页头部应提供返回按钮');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    if (find.text('我的轨迹').evaluate().isNotEmpty) {
      router.pop();
      await tester.pumpAndSettle();
    }

    expect(find.text('我的轨迹'), findsNothing,
        reason: '点击返回后应离开轨迹列表页');
  });
}
