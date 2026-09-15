import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 关于页（对应小程序 profile 内「关于」与隐私协议入口）
/// ============================================================
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 与 Android 原生约定的通道（MainActivity 中注册），用于唤起应用市场。
  static const MethodChannel _marketChannel =
      MethodChannel('com.xuhai.micro_trip/market');

  /// 去评分：按渠道跳对应应用市场。
  /// 用 market:// 唤起设备默认应用商店——该商店由构建渠道决定
  /// （华为包→AppGallery、小米包→小米应用商店…），天然「按渠道正确」；
  /// 未安装商店 / iOS 未实现该通道时降级为提示（2026-09-15 落实 P2#9 审计建议）。
  Future<void> _rate(BuildContext context) async {
    const uri = 'market://details?id=com.xuhai.micro_trip';
    try {
      await _marketChannel.invokeMethod<void>('openMarket', {'uri': uri});
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到应用市场，感谢你的支持～')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GradientHeader(
            title: '关于微旅途',
            actions: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ---------------- 品牌 ----------------
                FadeSlideIn(
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.card,
                        ),
                        alignment: Alignment.center,
                        child: const Text('🧳', style: TextStyle(fontSize: 40)),
                      ),
                      const SizedBox(height: 14),
                      const Text(AppConfig.appName,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('v${AppConfig.appVersion} · Flutter 跨端版',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textHint)),
                      const SizedBox(height: 2),
                      Text('渠道：${AppConfig.channel}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ---------------- 基本信息 ----------------
                FadeSlideIn(
                  delay: 60,
                  child: AppCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: Column(
                      children: [
                        // 分隔线规则（2026-09-14 统一，全 App 一致）：
                        // 左端对齐行内文字左边界、右端内缩 12，两端都不顶到卡片内缘。
                        // 本卡标签文字从内容区左边缘起（行内无前置图标）→ indent 取 0，
                        // 线条即从文字左边界开始，右端不再顶到卡片边缘。
                        // 旧值 indent: 56 且无 endIndent → 左边越过文字 56、右边顶到边缘，最难看。
                        _row('项目', '微旅途 MicroTrip（Flutter 版）'),
                        const Divider(height: 1, endIndent: 12),
                        _row('技术栈', 'Flutter · Riverpod · go_router · dio'),
                        const Divider(height: 1, endIndent: 12),
                        _row('天气数据', '和风天气 QWeather'),
                        const Divider(height: 1, endIndent: 12),
                        _row('智能助手', '小途（OpenAI 兼容大模型）'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 隐私声明 ----------------
                const FadeSlideIn(
                  delay: 120,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('隐私说明',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 10),
                        Text(
                          '1. 你的全部数据（城市选择、备忘、收藏、聊天记录）仅保存在本机，不上传任何服务器；\n'
                          '2. 定位仅用于获取当前城市天气与海拔，可在系统设置中随时关闭；\n'
                          '3. 天气与 AI 请求直接由本机发往对应服务商（和风天气 / 你配置的 AI 服务），请自行评估其隐私政策；\n'
                          '4. 清除本地数据入口位于「设置 - 清除全部本地数据」。',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 协议与隐私政策入口 ----------------
                FadeSlideIn(
                  delay: 180,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: const Icon(Icons.description_outlined,
                              size: 20, color: AppColors.primary),
                          title: const Text('用户协议',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textPrimary)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textHint),
                          onTap: () => context.push('/user-agreement'),
                        ),
                        // indent 56 = 标题文字起点：contentPadding 16 +
                        // (max(minLeadingWidth 24, 图标 20) + horizontalTitleGap 16) = 16 + 40 = 56，
                        // 屏幕坐标即 72（实测一致）。M3 的 minLeadingWidth 是 24，不是 M2 的 40。
                        // endIndent 12 与「设置」/「我的」页统一。
                        const Divider(height: 1, indent: 56, endIndent: 12),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: const Icon(Icons.privacy_tip_outlined,
                              size: 20, color: AppColors.primary),
                          title: const Text('查看完整隐私政策',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textPrimary)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textHint),
                          onTap: () => context.push('/privacy-policy'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 去评分 ----------------
                FadeSlideIn(
                  delay: 240,
                  child: GradientButton(
                    label: '去评分',
                    onPressed: () => _rate(context),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '从微信小程序「微旅途」迁移而来\nMIT License',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
                width: 64,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textHint))),
            Expanded(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary))),
          ],
        ),
      );
}
