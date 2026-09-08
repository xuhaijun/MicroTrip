import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug/overflow_locator.dart';
import 'core/http/http_client.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/background_recorder_service.dart';
import 'services/weather_push_service.dart';

/// ============================================================
/// 应用根 Widget：主题 + 路由装配
/// ============================================================
class MicroTripApp extends StatelessWidget {
  const MicroTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '微旅途',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 离线地图瓦片（OpenStreetMap）在大陆常不可达：UI 层已用
  // NetworkTileProvider(silenceExceptions: true) 透明降级（见各地图页）。
  // 但即便不抛异常，Flutter 仍会把「图片资源加载失败」通过 FlutterError.onError
  // 以 library='image resource service' 打印到控制台刷屏。此处在其最外层精准拦截
  // 这一类，对其他网络/UI 异常的正常上报零影响（包括下方溢出定位器的 overflow 上报）。
  final baseOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library == 'image resource service') return;
    baseOnError?.call(details);
  };

  // 开发期溢出定位器：设备端出现溢出黄条时，自动打印溢出 widget 的祖先链，
  // 便于快速定位（release 构建自动跳过，零开销）。
  installOverflowLocator();

  // 本地存储初始化（必须在 runApp 前，业务层直接同步读取）
  await AppStorage.init();

  // ---- Phase 4：网络鉴权拦截器初始化 ----
  // tokenProvider：needAuth 请求自动注入 Bearer Token
  HttpClient.tokenProvider = () => AuthService.token;
  // onUnauthorized：任意接口返回 401 时清除本地会话并跳转登录页。
  // 用 clearSession 而非 logout：此时令牌已失效，再发登出请求毫无意义
  // （且 logout 内部也走 HttpClient，会引入不必要的失败请求）。
  HttpClient.onUnauthorized = () {
    AuthService.clearSession();
    _gotoLogin('登录已过期，请重新登录');
  };
  // onBanned：后端返回 403 + error.code=FORBIDDEN（账号被管理员封禁）。
  // 与 401 区分：封禁重新登录也无法恢复，需明确告知用户联系管理员。
  HttpClient.onBanned = () {
    AuthService.clearSession();
    _gotoLogin('账号已被封禁，请联系管理员');
  };
  // onRateLimited：任意非登录接口返回 429 时全局提示「请 N 秒后再试」。
  // 登录/注册请求带 skipAuthHandling 跳过本回调，由登录页按钮倒计时自行提示。
  HttpClient.onRateLimited = (retryAfter) {
    final msg = retryAfter != null
        ? '请求过于频繁，请 $retryAfter 秒后再试'
        : '请求过于频繁，请稍后再试';
    _showGlobalSnackBar(msg);
  };
  // onForbidden：非封禁类 403（无权限访问该资源）全局提示，不强制登出。
  HttpClient.onForbidden = () {
    _showGlobalSnackBar('没有访问权限');
  };
  HttpClient.init();

  // ---- Phase 4/5：天气提醒 & 后台录制服务初始化 ----
  // 【启动性能优化】此前这两步在 runApp 前的事件循环里同步执行，其中
  // WeatherPushService.init() 会同步解析完整时区数据库（latest_all），
  // 阻塞首帧渲染，是「启动半天出不来」的主因之一。
  // 现统一推迟到「首帧绘制完成后」再执行，彻底移出启动关键路径；
  // 即便内部仍有耗时操作，也只会在用户已看到界面之后发生。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(WeatherPushService.init());
    unawaited(BackgroundRecorderService.configure());
  });

  runApp(const ProviderScope(child: MicroTripApp()));
}

/// 会话中断（401 过期 / 403 封禁）后统一跳登录页，并把原因透传给登录页展示。
///
/// - 以门控方式进入（`gated: true`）：登录成功后回首页。会话已失效，
///   直接 pop 回原页面会立刻再次触发 401，形成"跳转-返回"来回抖动。
/// - 已在登录页则不再重复 push，避免路由堆叠。
void _gotoLogin(String notice) {
  final current = appRouter.routerDelegate.currentConfiguration.uri.path;
  if (current == '/login') return;
  appRouter.push('/login', extra: {'gated': true, 'notice': notice});
}

/// 全局 SnackBar 提示（拦截器无 BuildContext，借助 GoRouter 根 Navigator 取 context）。
/// 用于 429 限流 / 403 越权等非会话类错误的轻量全局提示。
void _showGlobalSnackBar(String msg) {
  final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
  );
}
