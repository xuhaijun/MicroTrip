import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ============================================================
/// 共享组件库
/// 对应小程序 components/（weather-card / empty-state 等）
/// ============================================================

/// 渐变卡片：主色渐变背景 + 白色文字（首页天气卡 / AI 助手卡统一风格）
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = AppRadius.xl,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
    return onTap == null
        ? body
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: body,
          );
  }
}

/// 白色圆角卡片（列表项 / 信息块通用容器）
///
/// 实现注意：外层 [Container] 仅承载圆角投影（无背景色），
/// 真正的白色背景由内层 [Material] 提供。这样卡片内的 [ListTile] 的
/// 点击涟漪（ink splash）能正确绘制在最近的 Material 祖先上，
/// 避免「ListTile 被带背景色的 DecoratedBox 包裹导致涟漪不可见」的断言。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        child: child,
      ),
    );
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: body,
    );
    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: card,
          );
  }
}

/// 区块标题（左侧渐变竖条 + 标题 + 可选右侧「更多」）
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.onMore,
  });

  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: const Row(
              children: [
                Text('更多', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
              ],
            ),
          ),
      ],
    );
  }
}

/// 空状态（对应小程序 components/empty-state）
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.hint = '',
  });

  final IconData icon;
  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}

/// 主色渐变按钮（登录 / 保存等场景）
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.round),
          boxShadow: AppShadows.card,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// ============================================================
/// 统一渐变头部（4 个 Tab 页共用）
/// - 自动处理状态栏安全区（刘海屏不顶头）
/// - 标题 + 可选副标题 + 可选右侧操作（图标按钮等）
/// - 可选内容区（如统计数字行），与标题间隔 16
/// - 底部圆角 + 浅阴影，营造现代「卡片化头部」观感
/// ============================================================
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.child,
    this.onTitleTap,
    this.onCardTap,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? child;
  final VoidCallback? onTitleTap;

  /// 整卡点击回调（如首页天气卡：卡内任意位置都跳天气详情）。
  ///
  /// 实现注意：用 [HitTestBehavior.opaque] 包住整卡，让标题/副标题之外的
  /// 留白区域也能命中；标题区自带 GestureDetector（切城市）与 actions 里的
  /// IconButton（刷新）层级更深，手势竞技场中优先胜出，不会被整卡点击吞掉。
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: top + 16,
        bottom: child != null ? 20 : 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTitleTap,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (onTitleTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white70, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
              ...?actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 16),
            child!,
          ],
        ],
      ),
    );
    // 整卡可点：opaque 让留白区也可命中（deferToChild 只在子节点上命中，
    // 会出现「点卡片空白处没反应」的体验断点）
    return onCardTap == null
        ? card
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCardTap,
            child: card,
          );
  }
}
