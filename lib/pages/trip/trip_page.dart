import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/memo_item.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';
import '../shared/widgets/mini_calendar.dart';

/// ============================================================
/// 行程页（对应小程序 pages/trip）
/// 现代重设计：统一渐变头部（实时统计：出行轨迹 / 备忘 / 总里程）
/// + 开始录制轨迹横幅 + 迷你万年历 + 最近轨迹 + 备忘提醒
/// （快捷功能卡片整卡暂隐藏，开关 [_TripPageState._showQuickSection]）
/// ============================================================
class TripPage extends ConsumerStatefulWidget {
  const TripPage({super.key});

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage>
    with AutomaticKeepAliveClientMixin {
  /// 快捷功能卡片总开关：当前整卡隐藏（含标题 + 敬请期待 chip + 六宫格）。
  /// 需要恢复时改为 true：先恢复「快捷功能」标题卡；若同时要显示六宫格，
  /// 再把 [_showQuickEntries] 改为 true 即可，网格代码完整保留在 [_buildQuickEntries]。
  static const bool _showQuickSection = false;

  /// 快捷功能六宫格显示开关（仅当 [_showQuickSection] 为 true 时生效）：
  /// false = 只显示标题卡；true = 标题下展开六宫格。
  static const bool _showQuickEntries = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final memos = ref.watch(memoProvider);
    final history = ref.watch(trajectoryHistoryProvider);
    final records = history.whenOrNull(data: (l) => l) ?? [];
    final totalMeters =
        records.fold(0.0, (double s, r) => s + r.distance);
    final mileageText = totalMeters >= 1000
        ? '${(totalMeters / 1000).toStringAsFixed(1)} km'
        : '${totalMeters.round()} m';
    final uncompleted = memos.where((m) => !m.completed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------------- 统一渐变头部（实时统计） ----------------
          GradientHeader(
            title: '行程',
            subtitle: '规划你的每一次出发',
            child: Row(
              children: [
                _HeaderStat('${records.length}', '出行轨迹'),
                _HeaderDivider(),
                _HeaderStat('${memos.length}', '备忘'),
                _HeaderDivider(),
                _HeaderStat(mileageText, '总里程'),
              ],
            ),
          ),
          // 与渐变头部自然衔接：统一四 Tab 页布局，消除错位
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- 开始录制轨迹（醒目入口） ----------------
                  FadeSlideIn(child: _buildRecordBanner(context)),
                  const SizedBox(height: 16),
                  // ---------------- 快捷功能（整卡隐藏，开关 [_showQuickSection]） ----------------
                  if (_showQuickSection) ...[
                    FadeSlideIn(
                      delay: 80,
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('快捷功能',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                if (!_showQuickEntries) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.round),
                                    ),
                                    child: const Text('敬请期待',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary)),
                                  ),
                                ],
                              ],
                            ),
                            if (_showQuickEntries) ...[
                              const SizedBox(height: 12),
                              _buildQuickEntries(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // ---------------- 迷你万年历 ----------------
                  FadeSlideIn(
                    delay: 80,
                    child: MiniCalendar(
                      onOpenFull: () => context.push('/calendar'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ---------------- 最近轨迹 ----------------
                  FadeSlideIn(
                    delay: 140,
                    child: SectionTitle(
                      title: '最近轨迹',
                      onMore: () => context.push('/trip/trajectory'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: 180,
                    child: _buildRecentTrails(records, context),
                  ),
                  const SizedBox(height: 20),
                  // ---------------- 备忘提醒 ----------------
                  FadeSlideIn(
                    delay: 220,
                    child: SectionTitle(
                      title: '备忘提醒',
                      onMore: () => context.push('/trip/memo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: 260,
                    child: _buildMemos(memos, uncompleted, context),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trip/memo/edit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('记一笔'),
      ),
    );
  }

  /// 快捷功能六宫格（暂隐藏，[_showQuickEntries] 为 true 时恢复显示）
  Widget _buildQuickEntries(BuildContext context) {
    final entries = <(IconData, Color, String, String, VoidCallback)>[
      (
        Icons.fiber_manual_record,
        Colors.red,
        '录制轨迹',
        '实时 GPS 记录',
        () => context.push('/trajectory-record'),
      ),
      (
        Icons.camera_alt,
        AppColors.primary,
        '拍照识物',
        '识别植物/动物',
        () => context.push('/photo-recognition'),
      ),
      (
        Icons.tour,
        AppColors.accent,
        '一日游攻略',
        '5 段式行程规划',
        () => context.push('/oneday'),
      ),
      (
        Icons.calendar_month,
        AppColors.success,
        '万年历',
        '农历 · 宜忌 · 假期',
        () => context.push('/calendar'),
      ),
      (
        Icons.explore,
        AppColors.primaryLight,
        '附近探索',
        '周边景点美食',
        () => context.push('/nearby'),
      ),
      (
        Icons.list_alt,
        AppColors.textSecondary,
        '全部轨迹',
        '历史记录',
        () => context.push('/trip/trajectory'),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // 单元格高度需容纳 40px 图标 + 上下 padding(20) + 两行文字；
        // 原 3.2 把格子压得过扁(窄屏仅 ~43px)，导致内部 Column 纵向溢出。
        // 2.0 在 320 屏每格高 ~69px，留足余量，彻底消除溢出。
        childAspectRatio: 2.0,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return _QuickEntry(
          icon: e.$1,
          iconColor: e.$2,
          title: e.$3,
          subtitle: e.$4,
          onTap: e.$5,
        );
      },
    );
  }

  /// 开始录制轨迹：行程页顶部醒目入口（让已接好的录制能力更显眼）
  Widget _buildRecordBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/trajectory-record'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('开始录制轨迹',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(height: 3),
                  Text('实时 GPS 记录你的出行路线',
                      style:
                          TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: const Text('开始',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  /// 最近轨迹列表（最多 4 条）
  Widget _buildRecentTrails(List records, BuildContext context) {
    if (records.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.route_outlined,
          text: '还没有轨迹记录',
          hint: '点击右下角「记一笔」旁的录制，开始你的第一段旅程',
        ),
      );
    }
    final list = records.take(4).toList();
    return Column(
      children: [
        for (final r in list)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => context.push('/trajectory-detail/${r.id}'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.route_outlined,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${r.dateText} · ${r.distanceText} · ${r.durationText}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
      ],
    );
  }

  /// 备忘列表（带提醒时间）
  Widget _buildMemos(List<MemoItem> memos, int uncompleted, BuildContext context) {
    if (memos.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.note_alt_outlined,
          text: '暂无备忘',
          hint: '点击右下角 + 添加一条出行备忘',
        ),
      );
    }
    final list = memos.take(4).toList();
    return Column(
      children: [
        for (final m in list)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => context.push('/trip/memo/edit', extra: m.id),
            child: Row(
              children: [
                Icon(
                  m.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: m.completed ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: TextStyle(
                          fontSize: 15,
                          color: m.completed
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          decoration: m.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (m.remindTime != null) ...[
                        const SizedBox(height: 2),
                        Text(_remindText(m),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.accent)),
                      ],
                    ],
                  ),
                ),
                _priorityTag(m.priority),
              ],
            ),
          ),
        if (uncompleted > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('还有 $uncompleted 条待完成',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textHint)),
          ),
      ],
    );
  }

  String _remindText(MemoItem m) {
    final t = m.remindTime!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '⏰ ${t.month}/${t.day} $hh:$mm';
  }

  Widget _priorityTag(int priority) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: switch (priority) {
            2 => const Color(0xFFFDECEA),
            1 => const Color(0xFFFFF4E5),
            _ => const Color(0xFFF0F9FF),
          },
          borderRadius: BorderRadius.circular(AppRadius.round),
        ),
        child: Text(
          switch (priority) { 2 => '紧急', 1 => '重要', _ => '普通' },
          style: TextStyle(
            fontSize: 11,
            color: switch (priority) {
              2 => AppColors.danger,
              1 => AppColors.warning,
              _ => AppColors.primary,
            },
          ),
        ),
      );
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      );
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.3),
      );
}

/// 快捷功能入口卡片
class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
