import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/anim_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/cloud_stats.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import 'common_widgets.dart';

/// ============================================================
/// 「云端足迹」统计卡片（用于「我的」页）
///
/// 数据来自服务端 `GET /trajectory/stats` —— 服务端在 SQL 侧用
/// COUNT/SUM/MAX 一次聚合后只回传一行，所以**卡片开销与轨迹条数无关**；
/// 这也是它存在的意义：轨迹会随使用时间累积，本地求和迟早会拖慢页面。
///
/// 四种状态都有明确呈现（不出现"白卡片 + 无文案"）：
///   1. 加载中 → 骨架占位（保留卡片高度，避免内容跳动）
///   2. 未登录 → [SizedBox.shrink] 整卡隐藏（页面其余部分已有登录引导，不重复打扰）
///   3. 出错   → 一行简短提示 + 「重试」，不阻塞页面其他内容
///   4. 无数据 → 引导去设置页做首次同步
///   5. 正常   → 累计里程主指标 + 三项明细 + 时间范围
/// ============================================================
class CloudStatsCard extends ConsumerWidget {
  const CloudStatsCard({super.key, this.localRecordCount});

  /// 本地轨迹条数，用于提示"云端与本地为何不一致"（云端可能含其他设备的数据）
  final int? localRecordCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cloudStatsProvider);

    // 未登录 / 未配置后端：整卡隐藏，避免在未登录时堆叠多个登录引导
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn) return const SizedBox.shrink();

    return FadeSlideIn(
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: async.when(
          // 保留固定高度占位：加载态与完成态高度接近，避免下拉刷新时页面跳动
          loading: () => const _StatsSkeleton(),
          error: (e, _) => _StatsError(
            message: _shortMessage(e),
            onRetry: () => ref.invalidate(cloudStatsProvider),
          ),
          data: (stats) => stats.isEmpty
              ? _StatsEmpty(ctx: context, onRetry: () => ref.invalidate(cloudStatsProvider))
              : _StatsBody(
                  stats: stats,
                  localRecordCount: localRecordCount,
                  onRefresh: () => ref.invalidate(cloudStatsProvider),
                ),
        ),
      ),
    );
  }

  /// 把异常压成一行可读文案（网络类错误提示"网络"，其余原样截断）
  static String _shortMessage(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('connection') ||
        s.contains('Timeout') ||
        s.contains('timeout')) {
      return '网络连接失败';
    }
    if (s.contains('401')) return '登录已过期，请重新登录';
    // 去掉 "ServiceException: " 前缀，过长时截断，避免撑破卡片
    final clean = s.contains(': ') ? s.split(': ').last : s;
    return clean.length > 40 ? '${clean.substring(0, 40)}…' : clean;
  }
}

/// ---------------- 正常态 ----------------

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.onRefresh,
    this.localRecordCount,
  });

  final CloudStats stats;
  final VoidCallback onRefresh;
  final int? localRecordCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            const Icon(Icons.cloud_done_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('云端足迹',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(stats.lastSyncedText,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh,
                    size: 16, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 主指标：累计里程
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(stats.totalDistanceKmText,
                style: const TextStyle(
                    fontSize: 30,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(width: 4),
            const Text('km',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            Text('累计里程',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint.withValues(alpha: 0.9))),
          ],
        ),
        const SizedBox(height: 14),
        // 三项明细
        Row(
          children: [
            _MiniStat('出行', '${stats.countText} 次'),
            _vDivider(),
            _MiniStat('时长', stats.totalDurationText),
            _vDivider(),
            _MiniStat('爬升', '${stats.totalAscentText} m'),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        // 时间范围 + 采样点数
        Row(
          children: [
            const Icon(Icons.date_range_outlined,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                stats.rangeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
            Text('${stats.totalPointsText} 个采样点',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
        // 本地 vs 云端差异提示：两者不一致是正常的（云端含其他设备数据 / 本地未同步）
        if (localRecordCount != null && localRecordCount! != stats.count) ...[
          const SizedBox(height: 6),
          Text(stats.diffHint(localRecordCount!),
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.accent.withValues(alpha: 0.95))),
        ],
      ],
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 24,
        color: AppColors.divider,
      );
}

/// 明细小项（值在上、标签在下）
class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      );
}

/// ---------------- 加载态 ----------------

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              const Text('云端足迹',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 120,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// ---------------- 空态 ----------------

class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty({required this.ctx, required this.onRetry});
  final BuildContext ctx;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_outlined, size: 18, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Text('云端足迹',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('云端还没有出行记录',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('到「设置 → 云端同步」把本地轨迹同步上去',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('刷新', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      );
}

/// ---------------- 错误态 ----------------

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('云端足迹获取失败',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
}
