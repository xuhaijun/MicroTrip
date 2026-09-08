import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/http/http_client.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 极简 Dio 适配器：对任意请求返回固定状态码 + body，避免真实网络。
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.statusCode, this.body, {this.retryAfter});

  final int statusCode;
  final String body;
  final String? retryAfter;

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
        if (retryAfter != null) 'Retry-After': [retryAfter!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 拦截器全局回调（401/403/429）路由验证：
/// 与登录/注册/探活等 skipAuthHandling 请求不触发全局回调，避免重复提示。
///
/// 注意：必须 `await expectLater(..., throwsA(...))` —— 该断言返回 Future，
/// 不 await 会导致后续 `expect(flag, ...)` 在异步请求完成（回调尚未触发）前先执行。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    // 隔离：清掉可能残留的拦截器，再挂一个干净的（对应 main 中的 HttpClient.init）
    HttpClient.dio.interceptors.clear();
    HttpClient.init();
  });

  tearDown(() {
    HttpClient.onUnauthorized = null;
    HttpClient.onBanned = null;
    HttpClient.onRateLimited = null;
    HttpClient.onForbidden = null;
    HttpClient.dio.interceptors.clear();
  });

  test('401 触发 onUnauthorized', () async {
    HttpClient.dio.httpClientAdapter =
        _MockAdapter(401, '{"error":{"message":"登录过期"}}');
    var fired = false;
    HttpClient.onUnauthorized = () => fired = true;
    // 预期：_translate 把 DioException 转成 ServiceException 抛出
    await expectLater(() => HttpClient.get('https://example.com/x'),
        throwsA(isA<ServiceException>()));
    expect(fired, isTrue);
  });

  test('403 + FORBIDDEN 触发 onBanned，不触发 onForbidden', () async {
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      403,
      '{"error":{"code":"FORBIDDEN","message":"账号被封禁"}}',
    );
    var banned = false;
    var forbidden = false;
    HttpClient.onBanned = () => banned = true;
    HttpClient.onForbidden = () => forbidden = true;
    await expectLater(() => HttpClient.get('https://example.com/x'),
        throwsA(isA<ServiceException>()));
    expect(banned, isTrue);
    expect(forbidden, isFalse);
  });

  test('403 非 FORBIDDEN 触发 onForbidden，不触发 onBanned', () async {
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      403,
      '{"error":{"code":"NO_PERMISSION","message":"无权限"}}',
    );
    var banned = false;
    var forbidden = false;
    HttpClient.onBanned = () => banned = true;
    HttpClient.onForbidden = () => forbidden = true;
    await expectLater(() => HttpClient.get('https://example.com/x'),
        throwsA(isA<ServiceException>()));
    expect(banned, isFalse);
    expect(forbidden, isTrue);
  });

  test('429 触发 onRateLimited 并解析 Retry-After', () async {
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      429,
      '{"error":{"code":"RATE_LIMITED","message":"请求过于频繁"}}',
      retryAfter: '5',
    );
    int? secs;
    HttpClient.onRateLimited = (s) => secs = s;
    await expectLater(() => HttpClient.get('https://example.com/x'),
        throwsA(isA<ServiceException>()));
    expect(secs, 5);
  });

  test('429 无 Retry-After 时 onRateLimited 收到 null', () async {
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      429,
      '{"error":{"code":"RATE_LIMITED","message":"请求过于频繁"}}',
    );
    int? secs;
    HttpClient.onRateLimited = (s) => secs = s;
    await expectLater(() => HttpClient.get('https://example.com/x'),
        throwsA(isA<ServiceException>()));
    expect(secs, isNull);
  });

  test('skipAuthHandling 不触发任何全局回调', () async {
    HttpClient.dio.httpClientAdapter = _MockAdapter(
      429,
      '{"error":{"code":"RATE_LIMITED","message":"请求过于频繁"}}',
      retryAfter: '5',
    );
    var rateLimited = false;
    var unauthorized = false;
    HttpClient.onRateLimited = (_) => rateLimited = true;
    HttpClient.onUnauthorized = () => unauthorized = true;
    await expectLater(
        () => HttpClient.get('https://example.com/x', skipAuthHandling: true),
        throwsA(isA<ServiceException>()));
    expect(rateLimited, isFalse);
    expect(unauthorized, isFalse);
  });
}
