import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 首次引导页（Onboarding）
/// - 仅在首次安装后展示（由 Splash 依据 kGuideSeen 路由进入）
/// - 横向分页：4 屏功能亮点 + 指示点 + 跳过 / 下一步 / 立即体验
/// - 最后一屏提供「登录/注册」入口，解锁云端同步
/// - 离开引导即标记 kGuideSeen，后续启动不再展示
/// ============================================================
class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final PageController _pageController = PageController();
  int _page = 0;

  /// 引导内容（emoji 占位插画，遵循 App 既有「emoji 品牌图标」体系，无需引入图片资源）
  static const List<_GuideSlide> _slides = [
    _GuideSlide('🗺️', '行前规划', '天气、景点、美食一站搞定，\n出行计划提前安排妥帖。'),
    _GuideSlide('📍', '轨迹记录', '精准记录每段旅程，距离、海拔\n随时可查、随时回放。'),
    _GuideSlide('🤖', 'AI 助手', '拍照识物、智能行程，\n出行疑问随问随答。'),
    _GuideSlide('☁️', '云端同步', '登录账号后，收藏与轨迹\n在多端安全同步。'),
  ];

  /// 离开引导：标记已看 + 进入首页
  void _finish() {
    AppStorage.setBool(AppStorage.kGuideSeen, true);
    if (mounted) context.go('/home');
  }

  /// 跳转到登录（门控模式）：先标记引导已看，避免退出登录后再次弹引导
  void _goLogin() {
    AppStorage.setBool(AppStorage.kGuideSeen, true);
    if (mounted) context.go('/login', extra: <String, dynamic>{'gated': true});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ---- 右上角「跳过」 ----
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('跳过',
                    style: TextStyle(fontSize: 15, color: AppColors.textHint)),
              ),
            ),
            // ---- 分页内容 ----
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradientWith(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(s.emoji, style: const TextStyle(fontSize: 88)),
                        ),
                        const SizedBox(height: 40),
                        Text(s.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 14),
                        Text(s.desc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),
            // ---- 指示点 ----
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            // ---- 底部操作 ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isLast
                  ? Column(
                      children: [
                        GradientButton(
                          label: '立即体验',
                          onPressed: _finish,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _goLogin,
                          child: const Text('登录/注册，解锁云同步',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 14)),
                        ),
                      ],
                    )
                  : GradientButton(
                      label: '下一步',
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// 引导单屏数据
class _GuideSlide {
  const _GuideSlide(this.emoji, this.title, this.desc);
  final String emoji;
  final String title;
  final String desc;
}
