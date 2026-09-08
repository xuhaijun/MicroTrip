import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/http/http_client.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// ============================================================
/// 认证状态（Phase 4）
/// 供「我的」页 / 登录页 / 需要登录的能力响应式读取登录态。
/// ============================================================

/// 登录状态快照
class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.error,
    this.rateLimitUntil,
  });

  /// 当前登录用户（未登录为 null）
  final UserProfile? user;

  /// 登录/注册请求进行中
  final bool loading;

  /// 最近一次操作错误信息（供 UI 提示，已优先取后端可读文案）
  final String? error;

  /// 限流截止时间（429 触发）：非 null 且未过期时，登录/注册按钮禁用并显示倒计时。
  /// 由 [login]/[register] 在捕获到限流型 [ServiceException] 时写入。
  final DateTime? rateLimitUntil;

  bool get isLoggedIn => user != null;

  /// 是否仍处于限流冷却中（按钮应禁用）
  bool get isRateLimited {
    final until = rateLimitUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// 限流剩余秒数（<=0 表示已解除），向上取整让倒计时从 N 平滑递减
  int get rateLimitRemainingSeconds {
    final until = rateLimitUntil;
    if (until == null) return 0;
    final secs = until.difference(DateTime.now()).inMilliseconds / 1000;
    final r = secs.ceil();
    return r > 0 ? r : 0;
  }

  AuthState copyWith({
    UserProfile? user,
    bool? loading,
    String? error,
    bool clearError = false,
    DateTime? rateLimitUntil,
    bool clearRateLimit = false,
  }) =>
      AuthState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        rateLimitUntil:
            clearRateLimit ? null : (rateLimitUntil ?? this.rateLimitUntil),
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 启动时从本地恢复会话（token 过期则自动清除）
    final user = AuthService.currentUser;
    return AuthState(user: user);
  }

  /// 登录
  Future<bool> login({required String phone, required String password}) async {
    state = state.copyWith(loading: true, clearError: true, clearRateLimit: true);
    try {
      final user = await AuthService.login(phone: phone, password: password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e is ServiceException ? e.message : e.toString(),
        rateLimitUntil: _rateLimitUntilOf(e),
      );
      return false;
    }
  }

  /// 注册并自动登录
  Future<bool> register({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearRateLimit: true);
    try {
      final user = await AuthService.register(
        phone: phone,
        password: password,
        nickname: nickname,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e is ServiceException ? e.message : e.toString(),
        rateLimitUntil: _rateLimitUntilOf(e),
      );
      return false;
    }
  }

  /// 从异常中提取限流截止时间：仅当 [ServiceException] 为限流（429）时才有值；
  /// 后端未给 Retry-After 时回退 30 秒，避免按钮永久禁用。
  DateTime? _rateLimitUntilOf(Object e) {
    if (e is! ServiceException || !e.isRateLimited) return null;
    final secs = e.retryAfterSeconds ?? 30;
    return DateTime.now().add(Duration(seconds: secs));
  }

  /// 一键体验（幂等：演示账号已存在则自动登录，不会报「已注册」）
  Future<bool> experience() async {
    state = state.copyWith(loading: true, clearError: true, clearRateLimit: true);
    try {
      final user = await AuthService.experience();
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e is ServiceException ? e.message : e.toString(),
      );
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    await AuthService.logout();
    state = const AuthState();
  }

  /// 刷新会话（外部修改 token / 401 后调用）
  void refresh() {
    state = AuthState(user: AuthService.currentUser);
  }

  /// 清除错误提示
  void clearError() => state = state.copyWith(clearError: true);
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
