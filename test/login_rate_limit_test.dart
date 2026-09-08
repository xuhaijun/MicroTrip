import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/http/http_client.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/login_page.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';
import 'package:micro_trip/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 极简 Dio 适配器：对任意请求返回固定状态码 + body，避免真实网络。
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'Retry-After': ['5'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 登录触发 429 限流时，提交按钮应变为「请 N 秒后再试」倒计时禁用，
/// 冷却结束后自动恢复可点。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // AppStorage 是 late 单例，需在读取前初始化（对应 main() 中的 AppStorage.init()）
    await AppStorage.init();
    await AuthService.setServerUrl('https://example.com');
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      429,
      '{"error":{"code":"RATE_LIMITED","message":"请求过于频繁，请 5 秒后再试"}}',
    );
  });

  tearDown(() async {
    await AuthService.setServerUrl('');
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('登录 429：按钮禁用并显示倒计时，冷却结束后恢复可点',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );
    // 登录页内容较高，放大测试视口避免隐私勾选框/提交按钮被滚出屏幕导致 tap 未命中
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    // 勾选同意隐私政策（未勾选时按钮禁用，与限流无关）
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // 填入合法手机号与密码
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '13800000000');
    await tester.enterText(fields.at(1), '123456');
    await tester.pumpAndSettle();

    // 点击登录 → 触发 429
    final submit = find.byType(GradientButton);
    await tester.tap(submit);
    // mock 异步返回，推进若干帧让 429 落地（不用 pumpAndSettle，避免被倒计时定时器挂起）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // 限流冷却中：按钮显示倒计时且禁用（秒数随时间递减，用子串匹配避免时序抖动）
    // 按钮文案「请 N 秒后再试」与 SnackBar 的「请求过于频繁，请 N 秒后再试」均含该子串
    expect(find.textContaining('秒后再试'), findsWidgets);
    final btn = tester.widget<GradientButton>(submit);
    expect(btn.onPressed, isNull);

    // 倒计时由「自减计数器 + 假时钟定时器」驱动：pump 推进假时钟即可让
    // 每秒定时器触发并自减，归零后按钮恢复「登 录」可点（无需真实等待）。
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('登 录'), findsOneWidget);
    final btn2 = tester.widget<GradientButton>(submit);
    expect(btn2.onPressed, isNotNull);
  });
}
