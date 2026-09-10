import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/models/cloud_stats.dart';
import 'package:micro_trip/models/user_profile.dart';
import 'package:micro_trip/pages/shared/widgets/cloud_stats_card.dart';
import 'package:micro_trip/providers/app_providers.dart';
import 'package:micro_trip/providers/auth_provider.dart';

/// ============================================================
/// 「云端足迹」卡片（CloudStatsCard）组件测试
///
/// 重点验证「四种状态都有明确呈现」，不出现白卡片 + 无文案：
///   加载 / 未登录隐藏 / 出错可重试 / 无数据引导 / 正常展示
///
/// 同时覆盖窄屏（320 逻辑像素）下的溢出 —— 卡片里有大号数字（30px）
/// 与三项并排明细，是最容易在窄屏撑破的地方。
/// ============================================================
void main() {
  /// 已登录的假认证状态（不触发任何网络）
  ProviderContainer containerWith({
    required Future<CloudStats> Function() stats,
    bool loggedIn = true,
  }) {
    return ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _FakeAuthNotifier(
            loggedIn
                ? const UserProfile(
                    id: 'u1', nickname: '测试用户', phone: '13800001111',
                    loginType: 'server')
                : null,
          ),
        ),
        cloudStatsProvider.overrideWith((ref) => stats()),
      ],
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    ProviderContainer container, {
    int? localCount,
    double width = 390,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: CloudStatsCard(localRecordCount: localCount),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 造一份有代表性的云端统计：12.3km / 2.5h / 1235m 爬升 / 45678 采样点
  CloudStats sample() => CloudStats(
        count: 8,
        totalDistance: 12345,
        totalDuration: 9000,
        totalAscent: 1234.6,
        totalDescent: 1100.2,
        totalPoints: 45678,
        firstStart: DateTime(2026, 3, 15).millisecondsSinceEpoch,
        lastStart: DateTime(2026, 9, 10).millisecondsSinceEpoch,
        lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
      );

  // ---------------- 1. 正常态 ----------------

  testWidgets('正常态：展示累计里程与三项明细（单位换算正确）', (tester) async {
    await pumpCard(tester, containerWith(stats: () async => sample()));
    await tester.pumpAndSettle();

    expect(find.text('云端足迹'), findsOneWidget);
    // 主指标：米 → km（12345m = 12.3km），单位单独成行
    expect(find.text('12.3'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('累计里程'), findsOneWidget);
    // 三项明细
    expect(find.text('8 次'), findsOneWidget); // 服务端 count
    expect(find.text('2 小时 30 分'), findsOneWidget); // 9000 秒
    expect(find.text('1235 m'), findsOneWidget); // 1234.6 米取整
    // 底部：时间范围 + 采样点千分位
    expect(find.text('2026/03/15 — 2026/09/10'), findsOneWidget);
    expect(find.text('45,678 个采样点'), findsOneWidget);
    // 同步时间相对文本
    expect(find.text('刚刚'), findsOneWidget);
  });

  testWidgets('正常态：云端与本地条数一致时不显示差异提示', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => sample()),
      localCount: 8, // 与 count 相同
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('与本地记录一致'), findsNothing);
    expect(find.textContaining('比本地'), findsNothing);
  });

  testWidgets('正常态：云端多于本地时解释原因（防误判数据异常）', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => sample()), // count = 8
      localCount: 5,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('比本地多 3 条'), findsOneWidget);
    expect(find.textContaining('其他设备'), findsOneWidget);
  });

  testWidgets('正常态：本地多于云端时提示未同步', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => sample()), // count = 8
      localCount: 12,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('比本地少 4 条'), findsOneWidget);
    expect(find.textContaining('未同步'), findsOneWidget);
  });

  // ---------------- 2. 未登录 ----------------

  testWidgets('未登录：整卡隐藏（不重复堆叠登录引导）', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => sample(), loggedIn: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('云端足迹'), findsNothing);
    expect(find.text('12.3'), findsNothing);
    // 确认是真的隐藏而不是渲染成空白卡（AppCard 的 InkWell/Material 都不应存在）
    expect(find.byType(Card), findsNothing);
  });

  // ---------------- 3. 空数据 ----------------

  testWidgets('无数据：给出引导文案与刷新入口', (tester) async {
    await pumpCard(tester, containerWith(stats: () async => CloudStats.empty));
    await tester.pumpAndSettle();

    expect(find.text('云端足迹'), findsOneWidget);
    expect(find.text('云端还没有出行记录'), findsOneWidget);
    expect(find.textContaining('云端同步'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
    // 空态不应出现主指标大数字
    expect(find.text('km'), findsNothing);
  });

  // ---------------- 4. 错误态 ----------------

  testWidgets('网络错误：可读文案 + 重试按钮', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => throw Exception('SocketException: 网络不可达')),
    );
    await tester.pumpAndSettle();

    expect(find.text('云端足迹获取失败'), findsOneWidget);
    expect(find.text('网络连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('401：提示重新登录', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => throw Exception('401 Unauthorized')),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录已过期，请重新登录'), findsOneWidget);
  });

  testWidgets('重试按钮可点击且不抛异常', (tester) async {
    await pumpCard(
      tester,
      containerWith(stats: () async => throw Exception('boom')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    // 仍为错误态（数据源依旧失败），关键是不能崩
    expect(find.text('云端足迹获取失败'), findsOneWidget);
  });

  // ---------------- 5. 加载态 ----------------

  testWidgets('加载中：保留标题与骨架，不出现空白卡', (tester) async {
    // 永不完成的 Future → 稳定停在 loading 态
    final container = containerWith(
      stats: () => Completer<CloudStats>().future,
    );
    await pumpCard(tester, container);
    await tester.pump(); // 只推进一帧，不 settle

    expect(find.text('云端足迹'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('km'), findsNothing);

    // 抽干 FadeSlideIn 的延迟定时器，否则测试结束时会报
    // "A Timer is still pending even after the widget tree was disposed"
    await tester.pump(const Duration(seconds: 1));
  });

  // ---------------- 6. 窄屏溢出 ----------------

  testWidgets('窄屏 320：长内容不溢出', (tester) async {
    // 构造极限值：超大里程/时长/采样点 + 超长差异提示
    final extreme = CloudStats(
      count: 99999,
      totalDistance: 9876543.2, // 9876.5 km
      totalDuration: 359999, // 约 100 小时
      totalAscent: 123456.7,
      totalDescent: 123456.7,
      totalPoints: 98765432,
      firstStart: DateTime(2020, 1, 1).millisecondsSinceEpoch,
      lastStart: DateTime(2026, 9, 10).millisecondsSinceEpoch,
      lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await pumpCard(
      tester,
      containerWith(stats: () async => extreme),
      localCount: 1,
      width: 320,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 逐帧校验无 RenderFlex overflow（溢出只在渲染时以异常形式暴露）
    expect(find.text('9876.5'), findsOneWidget);
  });
}

/// 假 AuthNotifier：只控制 isLoggedIn，不触碰存储与网络
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);
  final UserProfile? _user;

  @override
  AuthState build() => AuthState(user: _user);
}
