import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 登录 / 注册页
/// - Tab 切换「登录 / 注册」，手机号 + 密码（注册附加昵称 + 确认密码）
/// - 注册需两次密码一致；密码框实时显示强度提示（弱 / 中 / 强）
/// - 打开页面自动预填上次成功登录/注册的手机号（仅手机号，不含密码）
/// - 本地演示模式离线可用；配置后端后走真实接口
/// - 门控模式（[extra] 携带 {'gated': true}）：成功 / 跳过统一跳首页，
///   用于启动引导、401 拦截等「需进入应用」的场景；
///   非门控（从「我的」页进入）则返回上一页。
/// - [extra] 可携带 {'notice': '...'}：由网络层会话中断回调传入
///   （401 登录过期 / 403 账号封禁），进入本页后以 SnackBar 告知用户原因。
/// - 合规：提交 / 一键体验前必须勾选同意《隐私政策》。
/// ============================================================
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.extra});

  /// 路由 extra：{'gated': true} 表示作为启动 / 拦截门控进入
  final Object? extra;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController(); // 注册模式「确认密码」
  final _nickname = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;
  bool _agreed = false;

  /// 防重复点击：认证请求进行中的本地守卫。
  /// 在 [_runAuth] 最前同步置位、请求结束（失败复位 / 成功跳走）复位，
  /// 保证快速连点只真正发起一次认证，不依赖 provider.loading 的时序，行为稳定可测。
  bool _submitting = false;

  /// 限流倒计时驱动定时器（429 冷却期间每秒刷新按钮文案）
  Timer? _rateLimitTimer;

  /// 限流剩余秒数（由认证状态播种，再由定时器每秒自减）。
  /// 用「自减计数器」而非实时读取 DateTime.now()：
  ///  - 生产：真实定时器每秒自减，与 rateLimitUntil 一致；
  ///  - 测试：flutter_test 假时钟下 Timer.periodic 仅在 pump(Duration) 时触发，
  ///    自减计数器可被假时钟推进，从而稳定驱动倒计时与「恢复可点」断言。
  int _rateLimitSeconds = 0;

  /// 是否处于限流冷却（按钮禁用并显示倒计时）
  bool get _rateLimited => _rateLimitSeconds > 0;

  /// 是否以「门控」方式进入（成功/跳过统一回首页）
  bool get _gated =>
      widget.extra is Map && (widget.extra as Map)['gated'] == true;

  @override
  void initState() {
    super.initState();
    // 预填上次成功登录/注册的手机号，提升复访体验（仅手机号，不含密码）
    final last = AuthService.lastPhone;
    if (last != null) _phone.text = last;
    // 会话中断原因（登录过期 / 账号封禁）由 HttpClient 回调通过路由 extra 传入。
    // 首帧后再弹，确保 ScaffoldMessenger 已就绪。
    final notice = widget.extra is Map ? (widget.extra as Map)['notice'] : null;
    if (notice is String && notice.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(notice)));
      });
    }
  }

  /// 限流冷却开始：从认证状态读取剩余秒数作为初始值，启动每秒自减定时器；
  /// 归零后自动停止并恢复按钮可点。
  void _ensureRateLimitTicking() {
    final seed = ref.read(authProvider).rateLimitRemainingSeconds;
    _rateLimitSeconds = seed > 0 ? seed : 0;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _rateLimitTimer?.cancel();
        _rateLimitTimer = null;
        return;
      }
      if (_rateLimitSeconds > 0) _rateLimitSeconds--;
      setState(() {}); // 每秒刷新剩余秒数
      if (_rateLimitSeconds <= 0) {
        _rateLimitTimer?.cancel();
        _rateLimitTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _phone.dispose();
    _password.dispose();
    _password2.dispose();
    _nickname.dispose();
    super.dispose();
  }

  /// 关闭登录页：门控 → 首页；否则能返回则返回，兜底首页
  void _finish() {
    if (_gated) {
      context.go('/home');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// 未勾选同意《用户协议》/《隐私政策》时，点击提交 / 一键体验的统一提示。
  /// 用「点击后提示」替代「静默禁用」：未同意仍可点，避免用户感知为「点了没反应」。
  void _showAgreeHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先阅读并同意《用户协议》和《隐私政策》'),
      ),
    );
  }

  /// 统一的认证执行包装：收敛「加载中 / 未同意 / 失败提示 / 成功跳转」共性逻辑，
  /// [_submit] 与 [_experience] 只关心各自的入参与成功文案，消除重复。
  Future<void> _runAuth(
    Future<bool> Function(AuthNotifier auth) action, {
    required String successMsg,
    String? rememberPhone,
  }) async {
    // 防重复点击：本地 in-flight 守卫置于最前、同步置位。
    // 即使两次点击在极短时间内连续触发，第二次也会因 _submitting 已置位而直接返回，
    // 保证只真正发起一次认证请求（不依赖 provider.loading 的时序，行为稳定可测）。
    if (_submitting) return;
    if (!_agreed) {
      _showAgreeHint();
      return;
    }
    final auth = ref.read(authProvider.notifier);
    _submitting = true;
    setState(() {}); // 立即禁用按钮，给出「提交中」可见反馈
    final ok = await action(auth);
    if (!mounted) return;
    if (ok) {
      // 成功：记录本次手机号用于下次预填（仅登录/注册，不含体验演示号）
      if (rememberPhone != null) {
        await AuthService.saveLastPhone(rememberPhone);
      }
      // 直接跳转，页面将被销毁，无需复位 _submitting
      _toast(successMsg);
      _finish();
      return;
    }
    // 失败 / 超时：复位以恢复按钮可点，允许重试（同时 _submitting 守卫已确保不会重复提交）
    _submitting = false;
    setState(() {});
    _toast(ref.read(authProvider).error ?? '操作失败，请重试');
  }

  /// 轻量 Toast（成功 / 错误统一出口；带 mounted 守卫，避免页面销毁后访问 context）
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 客户端手机号格式校验（与 [AuthService._validatePhone] 一致：1 开头、11 位）
  bool _isValidPhone(String phone) => RegExp(r'^1\d{10}$').hasMatch(phone);

  /// 密码强度评估：基于长度与字符多样性打分，返回 0(空)/1(弱)/2(中)/3(强) 及配色文案。
  ({int level, String label, Color color}) _passwordStrength(String p) {
    if (p.isEmpty) return (level: 0, label: '', color: Colors.grey);
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (p.contains(RegExp(r'[a-z]')) && p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'))) score++;
    if (score <= 1) return (level: 1, label: '弱', color: Colors.red);
    if (score <= 3) return (level: 2, label: '中', color: Colors.orange);
    return (level: 3, label: '强', color: Colors.green);
  }

  /// 密码强度可视化：三段进度条 + 文案（弱/中/强），随输入实时刷新。
  Widget _passwordStrengthIndicator(String password) {
    final s = _passwordStrength(password);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(3, (i) {
              final active = i < s.level;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? s.color
                        : AppColors.textHint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(s.label, style: TextStyle(fontSize: 12, color: s.color)),
      ],
    );
  }

  Future<void> _submit() async {
    // 客户端前置校验：明显非法输入直接本地提示，避免打到后端/本地注册才报错。
    final phone = _phone.text.trim();
    final password = _password.text;
    final nickname = _nickname.text.trim();
    if (!_isValidPhone(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    if (password.length < 6) {
      _toast('密码至少 6 位');
      return;
    }
    if (_isRegister && nickname.isEmpty) {
      _toast('请输入昵称');
      return;
    }
    if (_isRegister) {
      if (_password2.text.isEmpty) {
        _toast('请再次输入密码');
        return;
      }
      if (password != _password2.text) {
        _toast('两次输入的密码不一致');
        return;
      }
    }
    await _runAuth(
      (auth) => _isRegister
          ? auth.register(phone: phone, password: password, nickname: nickname)
          : auth.login(phone: phone, password: password),
      successMsg: _isRegister ? '注册成功，欢迎使用微旅途！' : '登录成功',
      rememberPhone: phone,
    );
  }

  /// 一键体验：本地免注册、幂等自动登录（演示账号已存在时复用，不误报「已注册」）
  Future<void> _experience() async {
    await _runAuth(
      (auth) => auth.experience(),
      successMsg: '已开启体验模式，欢迎使用微旅途！',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    // 限流冷却开始（rateLimitUntil 由认证层在 429 时写入）→ 启动倒计时
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.rateLimitUntil != null &&
          prev?.rateLimitUntil != next.rateLimitUntil) {
        _ensureRateLimitTicking();
      }
    });

    final blocked = _rateLimited;
    // 去掉 _agreed：未同意不再静默禁用按钮，改为点击时提示（见 _showAgreeHint）。
    // 仅 提交中(_submitting) / 限流冷却 期间禁用，保证用户点击「有反应」，
    // 底层 _submitting 守卫则拦截重复点击，杜绝连点重复提交。
    final canSubmit = !_submitting && !state.loading && !blocked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GradientHeader(
            title: '微旅途',
            subtitle: '登录后同步收藏与行程数据',
            actions: [
              IconButton(
                onPressed: _finish,
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ],
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text('🧳', style: TextStyle(fontSize: 36)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FadeSlideIn(
              child: Column(
                children: [
                  // ---------------- 登录 / 注册 Tab ----------------
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.round),
                    ),
                    child: Row(
                      children: [
                        _tabButton('登录', !_isRegister, () {
                          setState(() => _isRegister = false);
                          ref.read(authProvider.notifier).clearError();
                        }),
                        _tabButton('注册', _isRegister, () {
                          setState(() => _isRegister = true);
                          ref.read(authProvider.notifier).clearError();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------------- 表单 ----------------
                  if (_isRegister) ...[
                    _field(_nickname, '昵称', '怎么称呼你？',
                        icon: Icons.face_outlined),
                    const SizedBox(height: 14),
                  ],
                  _field(_phone, '手机号', '11 位手机号',
                      icon: Icons.phone_iphone,
                      keyboard: TextInputType.phone,
                      maxLen: 11,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                  const SizedBox(height: 14),
                  _field(_password, '密码', _isRegister ? '至少 6 位' : '请输入密码',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      onChanged: (_) => setState(() {}),
                      suffix: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: AppColors.textHint),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                  if (_password.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _passwordStrengthIndicator(_password.text),
                  ],
                  if (_isRegister) ...[
                    const SizedBox(height: 14),
                    _field(_password2, '确认密码', '再次输入密码',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        onChanged: (_) => setState(() {}),
                        suffix: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: AppColors.textHint),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        )),
                    if (_password2.text.isNotEmpty &&
                        _password2.text != _password.text) ...[
                      const SizedBox(height: 6),
                      const Text('两次输入的密码不一致',
                          style: TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ],
                  const SizedBox(height: 24),

                  // ---------------- 提交按钮 ----------------
                  GradientButton(
                    label: _submitting
                        ? (_isRegister ? '注册中…' : '登录中…')
                        : blocked
                            ? '请 $_rateLimitSeconds 秒后再试'
                            : (_isRegister ? '注册并登录' : '登 录'),
                    onPressed: canSubmit
                        ? () {
                            _submit();
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // ---------------- 一键体验 ----------------
                  TextButton(
                    onPressed: canSubmit
                        ? () {
                            _experience();
                          }
                        : null,
                    child: const Text('一键体验（免注册）',
                        style: TextStyle(color: AppColors.primary, fontSize: 14)),
                  ),
                  const SizedBox(height: 14),

                  // ---------------- 隐私协议（必勾选） ----------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _agreed,
                          activeColor: AppColors.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) => setState(() => _agreed = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _agreed = !_agreed),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: '我已阅读并同意',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  TextSpan(
                                    text: '《用户协议》',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context
                                          .push('/user-agreement'),
                                  ),
                                  const TextSpan(
                                    text: '和',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  TextSpan(
                                    text: '《隐私政策》',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => context
                                          .push('/privacy-policy'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ---------------- 游客跳过（仅门控场景） ----------------
                  if (_gated)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('暂不登录，先逛逛',
                          style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                    ),
                  if (_gated) const SizedBox(height: 8),

                  // ---------------- 提示 ----------------
                  const Text(
                    '演示说明：未配置后端时使用本地账号（数据仅存本机）；在「设置」中配置后端地址后自动切换为真实接口。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.round - 4),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                )),
          ),
        ),
      );

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    required IconData icon,
    TextInputType? keyboard,
    int? maxLen,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            obscureText: obscure,
            keyboardType: keyboard,
            maxLength: maxLen,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              isDense: true,
              prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
              suffixIcon: suffix,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
}
