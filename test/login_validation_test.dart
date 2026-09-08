import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/login_page.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';
import 'package:micro_trip/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归保护：登录/注册提交前的客户端校验应即时提示非法输入，
/// 且不触发实际登录/注册（避免把明显非法的请求打到后端/本地账号库）。
void main() {
  Future<ProviderContainer> pumpLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: LoginPage()),
      ),
    );
    // 视口放大，避免隐私勾选框/提交按钮被滚出屏幕导致 tap 未命中
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('手机号非法时本地校验提示，不登录', (tester) async {
    final container = await pumpLogin(tester);
    await tester.tap(find.byType(Checkbox)); // 同意
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123'); // 非法手机号
    await tester.enterText(fields.at(1), '123456');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();

    expect(find.text('请输入正确的 11 位手机号'), findsOneWidget);
    expect(container.read(authProvider).isLoggedIn, isFalse);
  });

  testWidgets('密码不足 6 位时本地校验提示，不登录', (tester) async {
    final container = await pumpLogin(tester);
    await tester.tap(find.byType(Checkbox));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '13800138000'); // 合法
    await tester.enterText(fields.at(1), '123'); // 过短
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();

    expect(find.text('密码至少 6 位'), findsOneWidget);
    expect(container.read(authProvider).isLoggedIn, isFalse);
  });

  testWidgets('注册模式昵称为空时本地校验提示，不注册', (tester) async {
    final container = await pumpLogin(tester);
    await tester.tap(find.text('注册')); // 切到注册 Tab
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    // 注册模式字段顺序：昵称(0) / 手机号(1) / 密码(2)
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '13800138000'); // 手机号
    await tester.enterText(fields.at(2), '123456'); // 密码
    // 昵称留空
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();

    expect(find.text('请输入昵称'), findsOneWidget);
    expect(container.read(authProvider).isLoggedIn, isFalse);
  });

  testWidgets('手机号字段仅接受数字输入', (tester) async {
    await pumpLogin(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '138abc00xy9'); // 含字母
    await tester.pumpAndSettle();
    // digitsOnly 应把非数字滤掉 → 1,3,8,0,0,9 = '138009'
    final field = tester.widget<TextField>(fields.at(0));
    expect(field.controller?.text, '138009');
  });
}
