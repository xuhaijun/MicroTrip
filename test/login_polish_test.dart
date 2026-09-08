import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/http/http_client.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/login_page.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';
import 'package:micro_trip/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 计数适配器：统计实际发出的认证请求次数（本组测试断言「被拦截时不发请求」）。
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'error': {'code': 'UNAUTHORIZED', 'message': '账号或密码错误'}}),
      401,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 登录/注册页「进一步打磨」：注册确认密码、预填上次手机号、密码强度提示。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    await AuthService.setServerUrl('https://example.com');
    HttpClient.dio.httpClientAdapter = _CountingAdapter();
  });

  tearDown(() async {
    await AuthService.setServerUrl('');
    SharedPreferences.setMockInitialValues({});
  });

  /// 注册模式下两次密码不一致：应本地拦截并提示，不发起注册请求。
  testWidgets('注册确认密码不一致：拦截并提示，不发请求', (tester) async {
    final adapter = HttpClient.dio.httpClientAdapter as _CountingAdapter;
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    // 切到注册 Tab
    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    // 注册模式字段顺序：昵称(0) 手机号(1) 密码(2) 确认密码(3)
    await tester.enterText(fields.at(0), '小明');
    await tester.enterText(fields.at(1), '13800000000');
    await tester.enterText(fields.at(2), '123456');
    await tester.enterText(fields.at(3), '123457'); // 不一致
    await tester.pumpAndSettle();

    // 勾选同意
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // 提交
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();

    expect(adapter.calls, 0, reason: '密码不一致不应发起注册请求');
    // 既有确认框下方的实时红字提示，也有提交后的 Toast，故用 findsWidgets
    expect(find.text('两次输入的密码不一致'), findsWidgets,
        reason: '应提示「两次输入的密码不一致」');
  });

  /// 登录页应预填上次成功登录/注册的手机号。
  testWidgets('打开登录页预填上次手机号', (tester) async {
    await AuthService.saveLastPhone('13912345678');
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    // 登录模式字段顺序：手机号(0) 密码(1)
    final phoneField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(phoneField.controller?.text, '13912345678',
        reason: '应预填上次登录手机号');
  });

  /// 密码强度提示随输入更新（弱 -> 强）。
  testWidgets('密码强度提示随输入更新', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    final pw = find.byType(TextField).at(1); // 登录模式密码字段

    await tester.enterText(pw, '123'); // 弱
    await tester.pumpAndSettle();
    expect(find.text('弱'), findsOneWidget, reason: '短纯数字应为弱');

    await tester.enterText(pw, 'Abcd1234!'); // 强（长度+大小写+数字+符号）
    await tester.pumpAndSettle();
    expect(find.text('强'), findsOneWidget, reason: '复杂密码应为强');
  });
}
