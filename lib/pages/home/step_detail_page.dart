import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/step_data.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 今日步数详情页（首页「今日步数」卡片点击进入）
/// 展示今日步数 / 距离 / 热量 / 运动等级，并提供最近 7 天趋势柱状图。
/// ============================================================
class StepDetailPage extends ConsumerStatefulWidget {
  const StepDetailPage({super.key});

  @override
  ConsumerState<StepDetailPage> createState() => _StepDetailPageState();
}

class _StepDetailPageState extends ConsumerState<StepDetailPage> {
  /// 刷新进行中标记：按钮转圈 + 禁用防连点
  bool _refreshing = false;

  /// 刷新今日步数与 7 天趋势
  /// 注意：stepProvider 是 AsyncNotifierProvider，仅 `invalidate` 会走缓存优先路径，
  /// 感知不到新数据（「点了没反应」根因）。必须调公开方法 [StepNotifier.refresh]
  /// 强制重新读取；recentStepsProvider 是 FutureProvider，invalidate 即自动重建。
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(stepProvider.notifier).refresh();
      ref.invalidate(recentStepsProvider);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(stepProvider);
    final recentAsync = ref.watch(recentStepsProvider);
    final date = DateTime.now();
    final dateLabel =
        '${date.year}年${date.month}月${date.day}日 ${_weekdayOf(date)}';

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: '今日步数',
            subtitle: dateLabel,
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // ---------------- 今日大卡 ----------------
                  FadeSlideIn(
                    child: GradientCard(
                      child: stepsAsync.when(
                        loading: () => _bigSteps('--', '加载中…'),
                        error: (_, _) => _bigSteps('--', '读取失败'),
                        data: (d) => _bigSteps(d.stepsText, d.level.label),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // ---------------- 三项明细 ----------------
                  FadeSlideIn(
                    delay: 60,
                    child: stepsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (d) => Row(
                        children: [
                          Expanded(child: _statCard('距离', d.distanceText)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _statCard('热量', d.caloriesText)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _statCard('来源', _sourceLabel(d.source))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // ---------------- 7 天趋势 ----------------
                  FadeSlideIn(
                    delay: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: '最近 7 天'),
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          child: recentAsync.when(
                            loading: () => const SizedBox(
                                height: 160,
                                child: Center(child: CircularProgressIndicator())),
                            error: (_, _) => const SizedBox(
                                height: 160,
                                child: Center(child: Text('趋势加载失败'))),
                            data: (list) => _weekChart(list),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 今日步数大卡内部：数值 + 运动等级 + 单位
  Widget _bigSteps(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          const Text('步',
              style: TextStyle(fontSize: 13, color: Colors.white54)),
        ],
      );

  /// 单项明细小卡（距离 / 热量 / 来源）
  Widget _statCard(String title, String value) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  /// 最近 7 天趋势柱状图（纯 Flutter 绘制，无第三方图表依赖）
  Widget _weekChart(List<StepData> data) {
    if (data.isEmpty) {
      return const SizedBox(
          height: 160, child: Center(child: Text('暂无历史数据')));
    }
    final maxSteps =
        data.map((d) => d.steps).reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_shortSteps(d.steps),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  // 柱子条：固定宽度 14dp，Column 默认水平居中，
                  // 两侧自动留白形成间距，不再撑满 1/7 屏宽导致积压。
                  Container(
                    width: 14,
                    height: maxSteps > 0 ? (d.steps / maxSteps) * 96 : 2,
                    decoration: BoxDecoration(
                      color: d.level == StepLevel.excellent
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_dayLabel(d.date),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 步数缩写（>=1000 显示为 k，避免柱状图顶部数字横向溢出）
  String _shortSteps(int s) =>
      s >= 1000 ? '${(s / 1000).toStringAsFixed(s % 1000 == 0 ? 0 : 1)}k' : '$s';

  /// 日期 → 简短标签（今天 / M/D）
  String _dayLabel(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '今天';
    }
    return '${d.month}/${d.day}';
  }

  /// 数据来源中文标签
  String _sourceLabel(StepDataSource src) => switch (src) {
        StepDataSource.health => '健康',
        StepDataSource.wechat => '微信运动',
        StepDataSource.mock => '示例',
        StepDataSource.local => '本地',
      };

  String _weekdayOf(DateTime d) {
    const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return wd[d.weekday - 1];
  }
}
