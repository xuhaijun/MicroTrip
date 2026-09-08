import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/login_page.dart';
import 'package:micro_trip/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归保护：未勾选同意《用户协议》/《隐私政策》时，点击「一键体验」「登录」按钮
/// 不应静默无反应，而应弹出同意提示，且不触发实际登录/注册。
void main() {
  testWidgets('未勾选同意时点击一键体验应弹提示而非无反应', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();

    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 不勾选同意，直接点击「一键体验（免注册）」
    await tester.tap(find.text('一键体验（免注册）'));
    await tester.pumpAndSettle();

    // 应弹出同意提示（点击有反应）
    expect(find.text('请先阅读并同意《用户协议》和《隐私政策》'), findsOneWidget);
    // 不应登录成功
    expect(container.read(authProvider).isLoggedIn, isFalse);

    // 关闭 SnackBar，再验证「登录」主按钮同样会提示
    await tester.pumpAndSettle();
    await tester.tap(find.text('登 录'));
    await tester.pumpAndSettle();
    expect(find.text('请先阅读并同意《用户协议》和《隐私政策》'), findsOneWidget);
    expect(container.read(authProvider).isLoggedIn, isFalse);
  });
}
