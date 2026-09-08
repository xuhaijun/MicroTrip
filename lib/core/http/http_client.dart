import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// 网络封装（dio）
/// 迁移自小程序 utils/request.js 的 requestWithCache 能力：
///  - GET + 内存/持久双层缓存，TTL 过期自动失效
///  - 统一超时 / 错误转译（ServiceException）
///  - clearCache 支持强制刷新场景
///
/// Phase 4 新增（对应 request.js 的 needAuth 鉴权）：
///  - tokenProvider：认证层注册的 token 读取回调（避免与 AuthService 循环依赖）
///  - needAuth：请求 extra 标记，自动注入 `Authorization: Bearer <token>`
///  - onUnauthorized：401 统一回调（认证层注册 → 清除会话 + 跳转登录页）
///
/// Phase 6 新增（对齐后端安全加固：限流 / 角色化封禁）：
///  - 统一错误转译 [_translate]：优先透传后端 `{error:{code,message}}` 的可读文案，
///    避免所有非 401 错误都被压成「网络连接失败」这类无信息量提示；
///  - 429 限流：保留 `Retry-After`（[ServiceException.retryAfterSeconds]）供 UI 倒计时，
///    并触发 [onRateLimited] 全局提示「请 N 秒后再试」；
///  - 403 处理：后端 `error.code == 'FORBIDDEN'` 触发 [onBanned]（清会话 + 提示封禁），
///    其余 403 触发 [onForbidden] 全局提示「没有访问权限」；
///  - [skipAuthHandling]：标记「本请求自身就是登出/探活/登录/注册」或「页面已自行处理」，
///    不再触发上述全局回调，避免「401 → 自动 logout → 401」递归及与页面本地提示重复。
/// ============================================================
class ServiceException implements Exception {
  ServiceException(
    this.message, {
    this.code,
    this.detail,
    this.errorCode,
    this.retryAfterSeconds,
  });

  /// 面向用户的可读文案（已优先取后端 error.message）
  final String message;

  /// HTTP 状态码；网络层错误（超时/DNS 失败等）为 -1
  final int? code;

  /// 原始异常对象（通常是 DioException），供调用方深挖细节
  final Object? detail;

  /// 后端业务错误码：`FORBIDDEN` / `RATE_LIMITED` / `NOT_FOUND` / `ERROR` …
  final String? errorCode;

  /// 429 限流时的建议重试等待秒数（取自 Retry-After 头）
  final int? retryAfterSeconds;

  /// 是否被限流（登录/注册高频调用触发）
  bool get isRateLimited => code == 429;

  /// 是否账号被封禁（区别于普通的越权 403）
  bool get isBanned => code == 403 && errorCode == 'FORBIDDEN';

  @override
  String toString() => 'ServiceException($code${errorCode == null ? '' : '/$errorCode'}): $message';
}

class HttpClient {
  HttpClient._();

  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    // 和风天气在部分网络下对 keep-alive 敏感，统一短连接策略
    headers: {'Accept': 'application/json'},
  ));

  /// 认证层注册的 token 读取回调（Phase 4）
  /// 返回 null 表示未登录；返回空串表示已退出登录
  static String? Function()? tokenProvider;

  /// 401 未授权回调（Phase 4）：认证层注册，用于清除会话并提示重新登录
  static void Function()? onUnauthorized;

  /// 403 账号封禁回调（Phase 6）：后端 `error.code == 'FORBIDDEN'` 时触发。
  /// 与 401 分开是因为语义不同：401 是"登录过期，重新登录即可"，
  /// 403 封禁是"管理员已禁用该账号，重新登录也没用"，提示文案必须区分。
  static void Function()? onBanned;

  /// 429 限流回调（Phase 6）：后端返回 429 时触发，供全局提示「请 N 秒后再试」。
  /// 与登录页的按钮倒计时互补：登录/注册请求带 skipAuthHandling 跳过本回调，
  /// 由登录页自行驱动倒计时；其余接口（天气/行程等）统一在此弹全局提示。
  static void Function(int? retryAfterSeconds)? onRateLimited;

  /// 403 越权回调（非封禁）：后端返回 403 但 `error.code != 'FORBIDDEN'` 时触发，
  /// 全局提示「没有访问权限」。封禁（FORBIDDEN）走 [onBanned]，两者语义不同。
  static void Function()? onForbidden;

  /// 请求 extra 标记：跳过 401/403 的全局回调（避免登出/探活请求触发递归）
  static const String kSkipAuthHandling = 'skipAuthHandling';

  /// 内存缓存：key -> (数据, 过期时间)
  static final Map<String, _CacheEntry> _memoryCache = {};

  /// 初始化拦截器链（在 main() 中调用一次）
  /// - onRequest：needAuth 标记的请求自动附加 Bearer Token
  /// - onError：401 触发 [onUnauthorized]；403 + FORBIDDEN 触发 [onBanned]，
  ///   其余 403 触发 [onForbidden]；429 触发 [onRateLimited]（均受 [skipAuthHandling] 豁免）
  static void init() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 业务层通过 options.extra['needAuth'] = true 标记需要鉴权的请求
        if (options.extra['needAuth'] == true) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (e, handler) {
        // 登出 / 探活 / 登录 / 注册等请求自身不参与全局会话处理，否则会递归
        // 或和页面本地错误处理（如登录页 429 倒计时）重复弹提示
        final skip = e.requestOptions.extra[kSkipAuthHandling] == true;
        if (!skip) {
          final status = e.response?.statusCode;
          if (status == 401) {
            // token 失效/过期/已被服务端吊销 → 清除会话并跳登录页
            onUnauthorized?.call();
          } else if (status == 403) {
            if (_serverErrorCode(e) == 'FORBIDDEN') {
              // 账号被管理员封禁 → 单独提示（重新登录无法解决）
              onBanned?.call();
            } else {
              // 普通越权（无权限访问该资源）→ 全局提示，不强制登出
              onForbidden?.call();
            }
          } else if (status == 429) {
            // 限流：解析 Retry-After 供全局提示倒计时秒数（非整数/缺失则传 null）
            final retryAfter =
                int.tryParse(e.response?.headers.value('Retry-After') ?? '');
            onRateLimited?.call(retryAfter);
          }
        }
        handler.next(e);
      },
    ));
  }

  /// GET 请求（带缓存）
  /// [cacheKey] 非 null 时启用缓存；[ttl] 为缓存有效期
  static Future<dynamic> getWithCache(
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    String? cacheKey,
    Duration? ttl,
  }) async {
    if (cacheKey != null && ttl != null) {
      final hit = _memoryCache[cacheKey];
      if (hit != null && hit.expireAt.isAfter(DateTime.now())) {
        return hit.data;
      }
      // 二级缓存：持久化（进程重启后 30 分钟内仍可用）
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('req_cache_$cacheKey');
      if (raw != null) {
        try {
          final entry = jsonDecode(raw) as Map<String, dynamic>;
          final expireAt = DateTime.parse(entry['expireAt'] as String);
          if (expireAt.isAfter(DateTime.now())) {
            final data = entry['data'];
            _memoryCache[cacheKey] = _CacheEntry(data, expireAt);
            return data;
          }
        } catch (_) {/* 缓存损坏则忽略 */}
      }
    }

    final data = await get(url, query: query, headers: headers);

    if (cacheKey != null && ttl != null) {
      final expireAt = DateTime.now().add(ttl);
      _memoryCache[cacheKey] = _CacheEntry(data, expireAt);
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('req_cache_$cacheKey', jsonEncode({
        'expireAt': expireAt.toIso8601String(),
        'data': data,
      }));
    }
    return data;
  }

  /// GET 请求（不走缓存）
  /// [needAuth] 为 true 时自动附加 Bearer Token（Phase 4）
  static Future<dynamic> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool needAuth = false,
    bool skipAuthHandling = false,
  }) async {
    try {
      final resp = await dio.get<dynamic>(
        url,
        queryParameters: query,
        options: Options(
          headers: headers,
          extra: {'needAuth': needAuth, kSkipAuthHandling: skipAuthHandling},
        ),
      );
      return resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// POST 请求（JSON body）
  /// [needAuth] 为 true 时自动附加 Bearer Token（Phase 4）
  static Future<dynamic> post(
    String url, {
    Object? body,
    Map<String, dynamic>? headers,
    bool needAuth = false,
    bool skipAuthHandling = false,
  }) async {
    try {
      final resp = await dio.post<dynamic>(
        url,
        data: body,
        options: Options(
          headers: headers,
          contentType: 'application/json',
          extra: {'needAuth': needAuth, kSkipAuthHandling: skipAuthHandling},
        ),
      );
      return resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// DELETE 请求（JSON body 可选）
  /// [needAuth] 为 true 时自动附加 Bearer Token（Phase 4）
  static Future<dynamic> delete(
    String url, {
    Object? body,
    Map<String, dynamic>? headers,
    bool needAuth = false,
    bool skipAuthHandling = false,
  }) async {
    try {
      final resp = await dio.delete<dynamic>(
        url,
        data: body,
        options: Options(
          headers: headers,
          contentType: 'application/json',
          extra: {'needAuth': needAuth, kSkipAuthHandling: skipAuthHandling},
        ),
      );
      return resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// 清除指定缓存（下拉刷新强制重拉时使用）
  static Future<void> clearCache(String cacheKey) async {
    _memoryCache.remove(cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('req_cache_$cacheKey');
  }

  // ==================== 错误转译（Phase 6） ====================

  /// 取后端错误包络：`{ error: { code, message } }`（兼容 `{data:{...}}` 包裹与平铺 message）
  static Map? _errorEnvelope(DioException e) {
    final data = e.response?.data;
    final body = data is String
        ? (() {
            try {
              return jsonDecode(data);
            } catch (_) {
              return null;
            }
          })()
        : data;
    if (body is! Map) return null;
    final err = body['error'];
    if (err is Map) return err;
    // 兜底：部分接口直接平铺 message 字段
    if (body['message'] != null) return {'message': body['message']};
    return null;
  }

  /// 后端业务错误码（FORBIDDEN / RATE_LIMITED / NOT_FOUND / ERROR …）
  static String? _serverErrorCode(DioException e) =>
      _errorEnvelope(e)?['code']?.toString();

  /// 后端可读错误文案
  static String? _serverMessage(DioException e) {
    final msg = _errorEnvelope(e)?['message']?.toString();
    return (msg == null || msg.trim().isEmpty) ? null : msg.trim();
  }

  /// 把 [DioException] 统一转成带可读文案的 [ServiceException]。
  ///
  /// 优先级：后端 `error.message` > 按状态码/网络错误类型给出的兜底文案。
  /// 这样后端新增的 429 限流、403 封禁等提示能原样传达给用户，
  /// 不再被压成无信息量的「网络连接失败」。
  static ServiceException _translate(DioException e) {
    final status = e.response?.statusCode;
    final serverMsg = _serverMessage(e);
    final errorCode = _serverErrorCode(e);

    // 429：解析 Retry-After（后端已在响应头写入剩余秒数）供 UI 倒计时
    int? retryAfter;
    if (status == 429) {
      final raw = e.response?.headers.value('Retry-After');
      retryAfter = int.tryParse(raw ?? '');
    }

    final message = serverMsg ?? _fallbackMessage(e, status);
    return ServiceException(
      message,
      code: status ?? -1,
      detail: e,
      errorCode: errorCode,
      retryAfterSeconds: retryAfter,
    );
  }

  /// 后端未给出 message 时的兜底文案（区分网络层与业务层，便于用户自查）
  static String _fallbackMessage(DioException e, int? status) {
    switch (status) {
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有访问权限';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 500:
      case 502:
      case 503:
        return '服务端异常（$status），请稍后重试';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络或后端地址';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查后端地址与端口';
      case DioExceptionType.badCertificate:
        return 'HTTPS 证书校验失败（自签证书需在客户端放行）';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return status == null
            ? '网络请求失败: ${e.message ?? e.type.name}'
            : '请求失败（$status）';
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.expireAt);
  final dynamic data;
  final DateTime expireAt;
}
