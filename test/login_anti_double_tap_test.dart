import 'dart:convert';
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

/// 计数适配器：统计实际发出的认证请求次数，并模拟少量网络耗时（让 in-flight 窗口存在）。
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    // 模拟网络耗时，确保第二次点击落在第一次请求未完成的窗口内
    await Future.delayed(const Duration(milliseconds: 50));
    // 返回 401：让登录/体验请求失败但不导航（登录页走 skipAuthHandling，不触发全局跳登录），
    // 从而只验证「重复点击只发一次请求」这一核心保证。
    return ResponseBody.fromString(
      jsonEncode({'error': {'code': 'UNAUTHORIZED', 'message': '账号或密码错误'}}),
      401,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 防重复点击：登录 / 注册 / 一键体验 按钮在请求进行中应拦截重复点击，
/// 即使快速连点也只发起一次认证请求。
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

  testWidgets('连续快速点击登录：仅发起一次认证请求', (tester) async {
    final adapter = HttpClient.dio.httpClientAdapter as _CountingAdapter;
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '13800000000');
    await tester.enterText(fields.at(1), '123456');
    await tester.pumpAndSettle();

    final submit = find.byType(GradientButton);

    // 两次 tap 之间不插入 pump：第一次进入 in-flight 后按钮禁用，
    // 第二次即便触达也由 _submitting 守卫拦截，保证只发一次请求。
    await tester.tap(submit);
    await tester.tap(submit);

    // 推进网络与状态，直到请求结束
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(adapter.calls, 1,
        reason: '重复点击不应触发多次认证请求');
  });

  testWidgets('连续快速点击一键体验：仅发起一次认证请求', (tester) async {
    final adapter = HttpClient.dio.httpClientAdapter as _CountingAdapter;
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final experience = find.text('一键体验（免注册）');
    await tester.tap(experience);
    await tester.tap(experience);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(adapter.calls, 1,
        reason: '重复点击一键体验不应触发多次认证请求');
  });
}
