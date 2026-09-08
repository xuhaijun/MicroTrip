import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';

/// ============================================================
/// 启动加载页（Splash）
/// - 应用入口首屏：展示品牌 Logo 与加载态，承接「冷启动」过渡
/// - 启动时已完成本地存储初始化与会话恢复（见 main.dart）
/// - 路由决策：
///     · 首次安装（未同意协议）→ 先弹《用户协议 & 隐私政策》征询框
///     · 未看引导 → /guide；已看引导 → /home
/// - 合规：不同意协议则退出应用（不上架前强制同意，符合国内商店要求）
/// ============================================================
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  /// 展示品牌约 1s 后，先征询协议同意，再按「是否看过引导」分流
  /// （原生品牌闪屏已即时显示，此处仅作品牌延续，不宜过长以免体感启动慢）
  Future<void> _route() async {
    // 提前持有 router 引用，避免 async gap 后直接使用 context
    final router = GoRouter.of(context);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // 首次启动：未同意《用户协议 & 隐私政策》→ 弹框征询（不同意退出应用）
    if (!AppStorage.getBool(AppStorage.kPrivacyAgreed)) {
      final agreed = await _showPrivacyConsent();
      if (!mounted) return;
      if (!agreed) {
        // 用户拒绝协议：退出应用（合规要求，不可绕过）
        await SystemNavigator.pop();
        return;
      }
      await AppStorage.setBool(AppStorage.kPrivacyAgreed, true);
    }

    final seenGuide = AppStorage.getBool(AppStorage.kGuideSeen);
    if (!seenGuide) {
      router.go('/guide');
    } else {
      router.go('/home');
    }
  }

  /// 首次启动协议征询框：
  /// - 《用户协议》《隐私政策》可点击跳转查看（返回后弹框保留）
  /// - 不同意 → false（调用方退出应用）；同意 → true
  Future<bool> _showPrivacyConsent() async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 必须明确选择，不可点外部关闭
      builder: (ctx) => AlertDialog(
        title: const Text('用户协议与隐私政策'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '欢迎使用「微旅途」！在开始使用前，请你仔细阅读并理解以下条款：',
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),
              _ConsentLink(
                label: '《用户协议》',
                onTap: () => ctx.push('/user-agreement'),
              ),
              const SizedBox(height: 8),
              _ConsentLink(
                label: '《隐私政策》',
                onTap: () => ctx.push('/privacy-policy'),
              ),
              const SizedBox(height: 12),
              const Text(
                '点击「同意并继续」即表示你已阅读并同意上述全部条款；'
                '若不同意，我们将无法为你提供服务。',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.6),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('不同意',
                style: TextStyle(color: AppColors.textHint)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意并继续'),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              // ---- 品牌 Logo：弹性缩放进场 ----
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text('🧳', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '微旅途',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '让每一次出发都被善待',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(flex: 3),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹框内的协议链接行（带下划线，可点击跳转对应协议页）
class _ConsentLink extends StatelessWidget {
  const _ConsentLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
