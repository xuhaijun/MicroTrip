import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:micro_trip/models/trajectory.dart';
import 'package:micro_trip/pages/trajectory/trajectory_record_page.dart';
import 'package:micro_trip/providers/app_providers.dart';

/// 录制状态替身：记录 [stop] 是否被调用，避免真实 GPS 依赖。
/// 初始状态即为 recording，使停止按钮可见；[stop] 默认返回 null（不发请求、不落盘）。
class _FakeRecNotifier extends TrajectoryRecordingNotifier {
  bool stopCalled = false;

  @override
  TrajectoryRecordingState build() =>
      const TrajectoryRecordingState(status: RecordingStatus.recording);

  @override
  Future<TrajectoryRecord?> stop({String? title, String? city}) async {
    stopCalled = true;
    return null;
  }
}

Widget _buildApp(_FakeRecNotifier fake, ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const TrajectoryRecordPage(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('取消保存：不调用 stop、不保存轨迹，且保持录制状态',
      (tester) async {
    final fake = _FakeRecNotifier();
    final container = ProviderContainer(
      overrides: [trajectoryRecordingProvider.overrideWith(() => fake)],
    );
    await tester.pumpWidget(_buildApp(fake, container));
    await tester.pumpAndSettle();

    // 录制中 → 停止按钮可见
    expect(find.byIcon(Icons.stop), findsOneWidget);

    // 点击停止 → 弹出保存对话框
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    expect(find.text('保存轨迹'), findsOneWidget);

    // 点击「取消」
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    // 关键断言：stop 未被调用（轨迹未保存），且仍在录制状态
    expect(fake.stopCalled, isFalse);
    expect(container.read(trajectoryRecordingProvider).status,
        RecordingStatus.recording);
  });

  testWidgets('点击保存：调用 stop 保存轨迹', (tester) async {
    final fake = _FakeRecNotifier();
    final container = ProviderContainer(
      overrides: [trajectoryRecordingProvider.overrideWith(() => fake)],
    );
    await tester.pumpWidget(_buildApp(fake, container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(fake.stopCalled, isTrue);
  });
}
