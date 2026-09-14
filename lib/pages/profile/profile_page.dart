import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../services/weather_push_service.dart';
import '../shared/widgets/cloud_stats_card.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 我的页（对应小程序 pages/profile）
/// 现代重设计：统一渐变头部（用户身份 + 实时统计：城市 / 轨迹 / 备忘 / 收藏）
/// + 云端足迹卡片（服务端 SQL 聚合，未登录自动隐藏）
/// + 功能入口（收藏 / 我的轨迹 / 我的备忘 / 天气提醒 / 自动定位 / 设置 / 关于）
/// + 退出登录 + 版本页脚
/// ============================================================
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late bool _weatherNotif;

  @override
  void initState() {
    super.initState();
    _weatherNotif = WeatherPushService.isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ref.watch(authProvider);
    final memos = ref.watch(memoProvider);
    final city = ref.watch(cityProvider);
    final recent = ref.watch(recentCitiesProvider).valueOrNull ?? [];
    final history = ref.watch(trajectoryHistoryProvider);
    final records = history.whenOrNull(data: (l) => l) ?? [];
    final favCount = ref.watch(favoritesCountProvider);
    final autoLocate = ref.watch(autoLocateProvider);

    final user = auth.user;
    final nickname = auth.isLoggedIn ? user!.nickname : '我的';
    final subtitle = auth.isLoggedIn
        ? (user!.phone.length == 11
            ? '${user.phone.substring(0, 3)}****${user.phone.substring(7)}'
            : (user.loginType == 'server' ? '云端账号' : '本地账号'))
        : '登录后享受收藏云同步';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------------- 统一渐变头部（用户身份 + 统计） ----------------
          GradientHeader(
            title: nickname,
            subtitle: subtitle,
            onTitleTap: auth.isLoggedIn
                ? null
                : () => context.push('/login'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Colors.white70, size: 22),
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
            child: Column(
              children: [
                // 头像 + 身份（未登录时整个区域可点击跳转登录页；
                // 之前只有标题文字绑定了 onTitleTap，头像本身点不动 →「点击头像登录无反应」根因）
                GestureDetector(
                  onTap: auth.isLoggedIn
                      ? null
                      : () => context.push('/login'),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          auth.isLoggedIn ? user!.avatar : '🧳',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(auth.isLoggedIn
                                ? '当前城市 · ${city.name}'
                                : '点击头像登录',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85))),
                          if (auth.isLoggedIn) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user!.loginType == 'server' ? '云端账号' : '本地账号',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 统计
                Row(
                  children: [
                    _HeaderStat('${recent.length}', '去过的城市'),
                    _HeaderDivider(),
                    _HeaderStat('${records.length}', '出行轨迹'),
                    _HeaderDivider(),
                    _HeaderStat('${memos.length}', '备忘'),
                    _HeaderDivider(),
                    _HeaderStat(
                      favCount.whenOrNull(data: (c) => '$c') ?? '·',
                      '收藏',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 与渐变头部自然衔接：统一四 Tab 页布局，消除错位
          Padding(
            // 左右 16 → 12：列表卡片更贴边，行内左右留白同步收窄（2026-09-14）
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Column(
                children: [
                  // ---------------- 云端足迹统计（服务端 SQL 聚合，未登录自动隐藏） ----------------
                  // 放在功能入口之前：它是"结果数据"，比"入口列表"更值得先看到；
                  // localRecordCount 用于解释"云端与本地条数为何不一致"
                  CloudStatsCard(localRecordCount: records.length),
                  const SizedBox(height: 12),
                  // ---------------- 功能入口 ----------------
                  FadeSlideIn(
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _Tile(
                            Icons.star_outline,
                            '我的收藏',
                            '美食与景点收藏',
                            trailing: favCount.whenOrNull(data: (c) => '$c'),
                            onTap: () => context.push('/profile/favorites'),
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _Tile(
                            Icons.route_outlined,
                            '我的轨迹',
                            '查看全部出行轨迹记录',
                            trailing: '${records.length}',
                            onTap: () => context.push('/trip/trajectory'),
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _Tile(
                            Icons.note_alt_outlined,
                            '我的备忘',
                            '查看全部出行备忘提醒',
                            trailing: '${memos.length}',
                            onTap: () => context.push('/trip/memo'),
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _SwitchTile(
                            Icons.notifications_outlined,
                            '天气提醒',
                            '每日推送当日天气与出行提示',
                            value: _weatherNotif,
                            onChanged: (v) async {
                              await WeatherPushService.setEnabled(v,
                                  city: ref.read(cityProvider));
                              if (mounted) setState(() => _weatherNotif = v);
                            },
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _SwitchTile(
                            Icons.my_location_outlined,
                            '自动定位',
                            '打开后启动自动定位当前城市',
                            value: autoLocate,
                            onChanged: (v) =>
                                ref.read(autoLocateProvider.notifier).set(v),
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _Tile(
                            Icons.settings_outlined,
                            '设置',
                            '天气 / AI 接口配置',
                            onTap: () => context.push('/profile/settings'),
                          ),
                          const Divider(height: 1, indent: 48, endIndent: 12),
                          _Tile(
                            Icons.info_outline,
                            '关于',
                            '版本与说明',
                            onTap: () => context.push('/profile/about'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ---------------- 退出登录 ----------------
                  if (auth.isLoggedIn) ...[
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: 100,
                      child: _LogoutCard(onTap: _confirmLogout),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // ---------------- 页脚 ----------------
                  const Text('微旅途 · 让每一次出发都被善待',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  Text('v${AppConfig.appVersion}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后本地数据仍会保留，确定退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已退出登录')));
      }
    }
  }
}

/// 头部统计单项
class _HeaderStat extends StatelessWidget {
  const _HeaderStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      );
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 26,
        color: Colors.white.withValues(alpha: 0.3),
      );
}

/// 普通入口行
class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.subtitle,
      {this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          // 左右 16 → 12：图标/箭头更靠近卡片边缘（与卡片外边距一起收窄）
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textHint)),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      );
}

/// 开关行
class _SwitchTile extends StatelessWidget {
  const _SwitchTile(
    this.icon,
    this.title,
    this.subtitle, {
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        // 左右 16 → 12：与普通列表项（_Tile）保持一致
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      );
}

/// 退出登录卡片
class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          alignment: Alignment.center,
          child: const Text('退出登录',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger)),
        ),
      );
}
