import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/settings_page.dart';
import 'package:micro_trip/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页「测试连接」按钮行为验证。
/// 通过 [AuthService.pingOverride] 注入固定结果，脱离真实网络断言 UI。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // AppStorage 是 late 单例，需在读取前初始化（对应 main() 中的 AppStorage.init()）
    await AppStorage.init();
  });

  tearDown(() {
    AuthService.pingOverride = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('后端可达：点击「测试连接」显示成功内联结果并弹 SnackBar',
      (tester) async {
    AuthService.pingOverride = (url) async => const ServerPingResult(
      ok: true,
      message: '连接成功（micro-trip-server，12ms）',
      latencyMs: 12,
    );
    await pumpSettings(tester);

    expect(find.text('测试连接'), findsOneWidget);

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    // 内联结果（绿色对勾 + 文案）与 SnackBar 汇总同一文案
    expect(find.textContaining('连接成功'), findsWidgets);
    // 按钮恢复为「测试连接」，不再显示「测试中…」
    expect(find.text('测试连接'), findsOneWidget);
  });

  testWidgets('地址错误：点击「测试连接」显示失败内联结果', (tester) async {
    AuthService.pingOverride = (url) async => const ServerPingResult(
      ok: false,
      message: '接口不存在（404）：请确认地址填到服务根路径，不要带 /api 等后缀',
    );
    await pumpSettings(tester);

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.textContaining('接口不存在'), findsWidgets);
    // 失败后按钮恢复可点，便于用户修正地址重试
    expect(find.text('测试连接'), findsOneWidget);
  });
}
