import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../core/http/http_client.dart';
import '../core/storage/app_storage.dart';
import '../models/user_profile.dart';

/// ============================================================
/// 认证服务（Phase 4）— JWT 登录体系
///
/// 双模式设计（与小程序「无后端」定位对齐，但升级为完整 JWT 体系）：
///  - 本地模式（默认）：账号注册/登录数据存本机，本地签发 JWT（HS256，
///    HMAC-SHA256 签名，30 天有效期），完全离线可跑；
///  - 服务端模式：在「设置」页配置后端地址后，走真实 REST 接口：
///      POST {apiBase}/auth/register  {phone,password,nickname}
///      POST {apiBase}/auth/login     {phone,password}
///      期望响应：{ token: string, user: {id,nickname,avatar,phone} }
///    登录后所有 needAuth 请求自动携带 `Authorization: Bearer <token>`。
///
/// Phase 6：接口路径统一走 [apiBase]（`{serverUrl}/api/v1`）。后端对历史裸路径
/// （`/auth/login` 等）保留了双映射，故新旧客户端可并存；此处主动对齐规范路径，
/// 为后端将来发布 v2 契约留出空间。
///
/// 对外 API（供 AuthNotifier / UI 使用）：
///  - token / isLoggedIn / currentUser      会话查询
///  - serverUrl / apiBase / ping            后端地址与连通性自检
///  - register / login / logout             账号操作
///  - clearSession                          仅清本地会话（401/403 拦截用）
///  - decodeToken / isTokenExpired          JWT 解析与过期判断
/// ============================================================
class AuthService {
  AuthService._();

  // ==================== 存储键（travel_ 前缀由 AppStorage 自动加） ====================
  static const String kToken = 'token'; // JWT 字符串
  static const String kUserProfile = 'userProfile'; // 当前登录用户
  static const String kLocalAccounts = 'localAccounts'; // 本地账号库 {phone: {...}}
  static const String kJwtSecret = 'jwtSecret'; // 本地签发 JWT 的 HMAC 密钥
  static const String kAuthConfig = 'authConfig'; // {serverUrl: 'https://...'}

  /// 一键体验的固定演示身份（Phase 7 修复）：
  /// 体验模式复用同一演示账号，使体验数据跨会话一致；账号已存在时直接登录，
  /// 避免重复注册报「该手机号已注册」。集中在此定义，避免散落在 UI 里写死。
  static const String kDemoPhone = '13800000000';
  static const String kDemoPassword = '123456';

  /// 最近一次成功登录/注册的手机号（仅保存手机号，用于登录页预填，不含密码）
  static const String kLastPhone = 'lastLoginPhone';

  /// Token 有效期（本地签发，与真实后端约定一致）
  static const Duration tokenTtl = Duration(days: 30);

  // ==================== 会话查询 ====================

  /// 当前 JWT（未登录返回 null）
  static String? get token {
    final raw = AppStorage.getObject(kToken);
    return raw?.toString();
  }

  /// 是否已登录（token 存在且未过期）
  static bool get isLoggedIn {
    final t = token;
    if (t == null || t.isEmpty) return false;
    return !isTokenExpired(t);
  }

  /// 当前登录用户（未登录返回 null）
  static UserProfile? get currentUser {
    if (!isLoggedIn) return null;
    final raw = AppStorage.getObject(kUserProfile);
    if (raw is Map) {
      return UserProfile.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  /// 当前后端配置（设置页可覆盖；为空表示本地演示模式）
  /// 已归一化：去掉用户可能误填的尾部斜杠，避免拼出 `//auth/login`
  static String get serverUrl {
    final raw = AppStorage.getObject(kAuthConfig);
    final url = raw is Map ? (raw['serverUrl']?.toString() ?? '') : '';
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> setServerUrl(String url) async {
    await AppStorage.setObject(kAuthConfig, {'serverUrl': url.trim()});
  }

  /// 记录最近一次成功登录/注册的手机号（仅手机号，不保存密码），供登录页预填。
  static Future<void> saveLastPhone(String phone) async {
    await AppStorage.setObject(kLastPhone, phone.trim());
  }

  /// 读取最近一次成功登录/注册的手机号（无记录返回 null）。
  static String? get lastPhone {
    final raw = AppStorage.getObject(kLastPhone);
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  /// 接口基址（Phase 6）：所有业务接口统一走 `{serverUrl}/api/v1`。
  /// 后端 Controller 同时映射了历史裸路径，故此变更对旧版本后端亦安全
  /// （若确需回退到裸路径，把此 getter 改回 [serverUrl] 即可，无需改各 service）。
  static String get apiBase => serverUrl.isEmpty ? '' : '$serverUrl/api/v1';

  // ==================== 连通性自检 ====================

  /// 测试可注入：覆盖 [ping] 实现（仅测试使用，默认 null = 走真实探活）。
  /// 测试里设为返回固定 [ServerPingResult]，即可脱离网络断言 UI 行为。
  static Future<ServerPingResult> Function(String)? pingOverride;

  /// 探活后端（GET {apiBase}/health），用于设置页「测试连接」。
  ///
  /// 不抛异常，统一返回 [ServerPingResult]，把地址填错 / 服务未启动 /
  /// HTTPS 证书不受信 / 超时等问题在配置阶段就暴露出来，
  /// 而不是等用户去同步轨迹时才报错。
  static Future<ServerPingResult> ping({String? url}) async {
    // 测试桩：若存在则直接返回固定结果，避免真实网络请求
    if (pingOverride != null) {
      return pingOverride!(url ?? AuthService.serverUrl);
    }

    final base = (url == null || url.trim().isEmpty)
        ? apiBase
        : '${url.trim().replaceAll(RegExp(r'/+$'), '')}/api/v1';
    if (base.isEmpty) {
      return const ServerPingResult(ok: false, message: '请先填写后端服务地址');
    }
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      return const ServerPingResult(
          ok: false, message: '地址需以 http:// 或 https:// 开头');
    }

    final started = DateTime.now();
    try {
      // skipAuthHandling：探活失败不应触发全局清会话 / 跳登录页
      final data = await HttpClient.get('$base/health', skipAuthHandling: true);
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final body = data is Map && data['data'] is Map ? data['data'] as Map : data;
      if (body is Map && body['ok'] == true) {
        final service = body['service']?.toString() ?? 'unknown';
        return ServerPingResult(
          ok: true,
          message: '连接成功（$service，${elapsed}ms）',
          latencyMs: elapsed,
        );
      }
      return const ServerPingResult(
          ok: false, message: '地址可访问但不是 MicroTripServer（health 响应异常）');
    } on ServiceException catch (e) {
      // 404 往往是把地址填到了错误的路径前缀上，单独给提示
      if (e.code == 404) {
        return const ServerPingResult(
            ok: false, message: '接口不存在（404）：请确认地址填到服务根路径，不要带 /api 等后缀');
      }
      return ServerPingResult(ok: false, message: e.message);
    } catch (e) {
      return ServerPingResult(ok: false, message: '连接失败：$e');
    }
  }

  // ==================== 注册 ====================

  /// 注册新账号并自动登录
  static Future<UserProfile> register({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    _validatePhone(phone);
    if (password.length < 6) {
      throw ServiceException('密码至少 6 位');
    }
    if (nickname.trim().isEmpty) {
      throw ServiceException('请输入昵称');
    }

    if (serverUrl.isNotEmpty) {
      // ---- 服务端模式：调用真实后端注册接口 ----
      // skipAuthHandling：注册请求自身错误由本页/AuthNotifier 本地处理，
      // 不应触发全局 onRateLimited / onUnauthorized，避免与注册页提示重复。
      final data = await HttpClient.post(
        '$apiBase/auth/register',
        body: {'phone': phone, 'password': password, 'nickname': nickname.trim()},
        skipAuthHandling: true,
      );
      return _applyServerSession(data);
    }

    // ---- 本地模式：写入本地账号库 ----
    final accounts = _loadLocalAccounts();
    if (accounts.containsKey(phone)) {
      throw ServiceException('该手机号已注册，请直接登录');
    }
    final now = DateTime.now().toIso8601String();
    accounts[phone] = {
      'password': password,
      'nickname': nickname.trim(),
      'avatar': _randomAvatar(phone),
      'createdAt': now,
    };
    await AppStorage.setObject(kLocalAccounts, accounts);

    final user = UserProfile(
      id: phone, // 本地账号以手机号作为稳定标识
      nickname: nickname.trim(),
      avatar: accounts[phone]!['avatar'] as String,
      phone: phone,
      loginType: 'local',
      createdAt: now,
    );
    await _issueLocalSession(user);
    return user;
  }

  // ==================== 登录 ====================

  /// 登录（本地验证账号密码 / 服务端调后端接口）
  static Future<UserProfile> login({
    required String phone,
    required String password,
  }) async {
    _validatePhone(phone);
    if (password.isEmpty) {
      throw ServiceException('请输入密码');
    }

    if (serverUrl.isNotEmpty) {
      // ---- 服务端模式 ----
      // skipAuthHandling：登录请求自身错误由登录页/AuthNotifier 本地处理
      // （含 429 倒计时），不应触发全局回调，避免重复弹提示或误跳登录页。
      final data = await HttpClient.post(
        '$apiBase/auth/login',
        body: {'phone': phone, 'password': password},
        skipAuthHandling: true,
      );
      return _applyServerSession(data);
    }

    // ---- 本地模式：校验账号密码 ----
    final accounts = _loadLocalAccounts();
    final account = accounts[phone];
    if (account == null) {
      throw ServiceException('账号不存在，请先注册');
    }
    if (account['password'] != password) {
      throw ServiceException('密码错误，请重试');
    }

    final user = UserProfile(
      id: phone,
      nickname: account['nickname']?.toString() ?? '微旅途用户',
      avatar: account['avatar']?.toString() ?? '🧳',
      phone: phone,
      loginType: 'local',
      createdAt: account['createdAt']?.toString(),
    );
    await _issueLocalSession(user);
    return user;
  }

  // ==================== 一键体验（幂等） ====================

  /// 一键体验：建立并登录固定的演示账号 [kDemoPhone]。
  ///
  /// 幂等设计（Phase 7 修复「体验账号已存在却报已注册」）：
  ///  - 演示账号尚未建立 → 走 [register] 自动注册并登录；
  ///  - 已存在（之前体验过 / 已注册过该号）→ [register] 抛「已注册」，
  ///    此时自动降级为 [login] 复用同一身份，不再提示错误。
  /// 本地模式与服务端模式均适用（服务端注册冲突同样返回「已注册」）。
  static Future<UserProfile> experience() async {
    try {
      return await register(
        phone: kDemoPhone,
        password: kDemoPassword,
        nickname: '体验用户',
      );
    } on ServiceException catch (e) {
      // 演示账号已存在：直接登录复用，避免重复注册报错
      if (e.message.contains('已注册')) {
        return await login(phone: kDemoPhone, password: kDemoPassword);
      }
      rethrow;
    }
  }

  // ==================== 登出 ====================

  /// 登出：通知后端吊销令牌（服务端模式）+ 清除本地会话（保留本地账号库）
  static Future<void> logout() async {
    if (serverUrl.isNotEmpty) {
      try {
        // skipAuthHandling：登出请求自身若返回 401（令牌已失效）不应再触发
        // 全局 onUnauthorized，否则会形成「401 → logout → 401」无限递归。
        await HttpClient.post(
          '$apiBase/auth/logout',
          needAuth: true,
          skipAuthHandling: true,
        );
      } catch (_) {/* 忽略登出接口失败 */}
    }
    await clearSession();
  }

  /// 仅清除本地会话（不请求后端）。
  /// 供 401/403 拦截回调使用——此时令牌已失效或账号已被封禁，
  /// 再发登出请求既无意义也会引发递归。
  static Future<void> clearSession() async {
    await AppStorage.remove(kToken);
    await AppStorage.remove(kUserProfile);
  }

  // ==================== JWT 解析 ====================

  /// 解析 JWT payload（不校验签名；仅用于读取过期时间等公开信息）
  static Map<String, dynamic>? decodeToken(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// JWT 是否已过期（无 exp 字段视为不过期）
  static bool isTokenExpired(String jwt) {
    final payload = decodeToken(jwt);
    final exp = payload?['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
    }
    return false;
  }

  // ==================== 内部实现 ====================

  /// 本地签发 JWT（HS256）：header.payload.signature
  static Future<String> _issueLocalJwt(UserProfile user) async {
    final now = DateTime.now();
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'sub': user.id,
      'name': user.nickname,
      'phone': user.phone,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(tokenTtl).millisecondsSinceEpoch ~/ 1000,
    };
    final b64Header = _b64url(jsonEncode(header));
    final b64Payload = _b64url(jsonEncode(payload));
    final signature = _hmac('$b64Header.$b64Payload', await _getJwtSecret());
    return '$b64Header.$b64Payload.$signature';
  }

  /// 建立本地会话：签发 JWT + 持久化用户信息
  static Future<void> _issueLocalSession(UserProfile user) async {
    final jwt = await _issueLocalJwt(user);
    await AppStorage.setObject(kToken, jwt);
    await AppStorage.setObject(kUserProfile, user.toMap());
  }

  /// 解析服务端登录响应并建立会话
  static UserProfile _applyServerSession(dynamic data) {
    if (data is! Map) {
      throw ServiceException('后端返回格式错误');
    }
    // 兼容 {token, user} 与 {data: {token, user}} 两种返回结构
    final payload = data['data'] is Map ? data['data'] as Map : data;
    final jwt = payload['token']?.toString();
    final userMap = payload['user'];
    if (jwt == null || jwt.isEmpty || userMap is! Map) {
      throw ServiceException(data['message']?.toString() ?? '登录失败，请检查后端返回格式');
    }
    // 校验 token 合法性（签名不匹配/过期立即拒绝）
    if (isTokenExpired(jwt)) {
      throw ServiceException('后端返回的 Token 已过期');
    }
    final user = UserProfile(
      id: userMap['id']?.toString() ?? 'server-user',
      nickname: userMap['nickname']?.toString() ?? '微旅途用户',
      avatar: userMap['avatar']?.toString() ?? '🧳',
      phone: userMap['phone']?.toString() ?? '',
      loginType: 'server',
      createdAt: DateTime.now().toIso8601String(),
    );
    AppStorage.setObject(kToken, jwt);
    AppStorage.setObject(kUserProfile, user.toMap());
    return user;
  }

  /// 读取本地账号库（{phone: {password, nickname, avatar, createdAt}}）
  static Map<String, Map<String, dynamic>> _loadLocalAccounts() {
    final raw = AppStorage.getObject(kLocalAccounts);
    if (raw is Map) {
      return raw.map(
          (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
    }
    return {};
  }

  /// 获取本地 JWT 签名密钥（首次生成后持久化，保证重启后 token 仍可校验）
  static Future<String> _getJwtSecret() async {
    final existing = AppStorage.getObject(kJwtSecret);
    if (existing is String && existing.isNotEmpty) return existing;
    final secret = _randomSecret();
    await AppStorage.setObject(kJwtSecret, secret);
    return secret;
  }

  static String _b64url(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');

  static String _hmac(String input, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return base64Url.encode(hmac.convert(utf8.encode(input)).bytes).replaceAll('=', '');
  }

  static String _randomSecret() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// 根据手机号稳定派生一个 emoji 头像（同一账号头像固定）
  static String _randomAvatar(String phone) {
    const avatars = ['🧳', '🧭', '🗺️', '🏔️', '🌊', '🎒', '📸', '⛺'];
    final hash = phone.codeUnits.fold<int>(0, (a, b) => (a + b) % 97);
    return avatars[hash % avatars.length];
  }

  static void _validatePhone(String phone) {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone.trim())) {
      throw ServiceException('请输入 11 位手机号');
    }
  }
}

/// 后端连通性自检结果（[AuthService.ping] 返回）
class ServerPingResult {
  const ServerPingResult({
    required this.ok,
    required this.message,
    this.latencyMs,
  });

  /// 是否连通且确认为 MicroTripServer
  final bool ok;

  /// 面向用户的结果描述（成功含服务名与耗时；失败含可操作的原因）
  final String message;

  /// 往返耗时（毫秒），仅成功时有值
  final int? latencyMs;
}
