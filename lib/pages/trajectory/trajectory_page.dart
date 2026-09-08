import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trajectory.dart';
import '../../pages/shared/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../services/gpx_service.dart';
import '../../services/trajectory_repository.dart';

/// ============================================================
/// 轨迹历史页（Phase 2 重写 + P1：GPX 多选合并导出）
///
/// 设计语言：统一「微旅途」现代风格
///  - GradientHeader 替掉 AppBar，统计行作为头部 child
///  - 内容用 AppCard 白卡；列表项 FadeSlideIn 交错进场
///  - 下拉刷新 + 左滑删除（trajectoryHistoryProvider）
///
/// 功能：
///  - 历史轨迹列表（卡片：标题/城市/日期/距离/时长/停留点数）
///  - 录制入口（FAB / 顶部按钮）
///  - 点击进入详情页
///  - 空状态引导
///  - 总距离统计
///  - 【P1 新增】多选合并：长按或点「选择」进入选择模式，
///    勾选多条轨迹后一键合并为 1 条并导出标准 .gpx 文件。
///
/// 对应小程序 subpackages/travel/pages/trajectory
/// ============================================================
class TrajectoryPage extends ConsumerStatefulWidget {
  const TrajectoryPage({super.key});

  @override
  ConsumerState<TrajectoryPage> createState() => _TrajectoryPageState();
}

class _TrajectoryPageState extends ConsumerState<TrajectoryPage> {
  /// 是否处于多选（合并）模式
  bool _selectionMode = false;

  /// 已选中的轨迹 ID 集合
  final Set<String> _selected = {};

  /// 合并导出进行中
  bool _isMerging = false;

  // ---- 选择模式切换 ----

  void _enterSelectionMode() => setState(() {
        _selectionMode = true;
        _selected.clear();
      });

  void _exitSelectionMode() => setState(() {
        _selectionMode = false;
        _selected.clear();
      });

  void _toggleSelect(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
        // 取消选择后若已无选中项，自动退出选择模式
        if (_selected.isEmpty) _selectionMode = false;
      });

  /// 下拉刷新
  Future<void> _refresh() async {
    await ref.read(trajectoryHistoryProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(trajectoryHistoryProvider);

    return Scaffold(
      body: Column(
        children: [
          // ---- 统一渐变头部（统计行作为 child）----
          GradientHeader(
            title: _selectionMode ? '已选 ${_selected.length} 条' : '我的轨迹',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
              if (_selectionMode)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: '退出选择',
                  onPressed: _exitSelectionMode,
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white),
                  tooltip: '多选合并',
                  onPressed: _enterSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.add_location_alt, color: Colors.white),
                  tooltip: '录制新轨迹',
                  onPressed: () => context.push('/trajectory-record'),
                ),
              ],
            ],
            child: historyAsync.when(
              // 刷新时（copyWithPrevious 已保留旧数据）继续显示统计，避免头部闪烁空白
              loading: () => historyAsync.hasValue
                  ? _SummaryRow(records: historyAsync.value ?? [])
                  : const _HeaderStatsShimmer(),
              error: (_, _) => historyAsync.hasValue
                  ? _SummaryRow(records: historyAsync.value ?? [])
                  : const SizedBox.shrink(),
              data: (records) => _SummaryRow(records: records),
            ),
          ),
          // ---- 内容区 ----
          // 刷新时保留旧列表（copyWithPrevious 让 state 持有上次数据），
          // 仅首次进入（无数据）才显示全屏 loading，避免「刷新后大片空白」。
          Expanded(
            child: historyAsync.when(
              loading: () => historyAsync.hasValue
                  ? _buildList(context, historyAsync.value ?? [])
                  : const Center(child: CircularProgressIndicator()),
              error: (e, _) => historyAsync.hasValue
                  ? _buildList(context, historyAsync.value ?? [])
                  : Center(child: Text('加载失败: $e')),
              data: (records) {
                if (records.isEmpty) return _buildEmpty(context);
                return _buildList(context, records);
              },
            ),
          ),
        ],
      ),
      // 选择模式下的合并导出底栏
      bottomNavigationBar: _selectionMode && _selected.isNotEmpty
          ? _buildMergeBar(
              records: _recordsFromIds(historyAsync.value ?? [], _selected))
          : null,
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/trajectory-record'),
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text('录制', style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.primary,
            ),
    );
  }

  /// 根据选中 ID 取轨迹对象列表
  List<TrajectoryRecord> _recordsFromIds(
      List<TrajectoryRecord> all, Set<String> ids) {
    final map = {for (final r in all) r.id: r};
    return ids.map((id) => map[id]).whereType<TrajectoryRecord>().toList();
  }

  /// 合并导出底栏
  Widget _buildMergeBar({required List<TrajectoryRecord> records}) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '将 ${records.length} 条轨迹合并为 1 条并导出 GPX',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isMerging ? null : () => _mergeAndExport(records),
              icon: _isMerging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_outlined),
              label: Text(_isMerging ? '合并中…' : '合并导出'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 合并并导出 GPX
  Future<void> _mergeAndExport(List<TrajectoryRecord> records) async {
    if (records.isEmpty) return;
    setState(() => _isMerging = true);
    try {
      // 1) 合并为单条轨迹记录
      final merged = GpxService.mergeRecords(records);

      // 2) 持久化到本地仓库（合并结果长期可查）
      await TrajectoryRepository.save(merged);
      ref.invalidate(trajectoryHistoryProvider);

      // 3) 生成合并 GPX 并分享
      final gpx = GpxService.exportMergedGpx(records);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${merged.id}_merged.gpx');
      await file.writeAsString(gpx);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '微旅途 — 合并轨迹 GPX（${records.length} 条）',
      );

      // 退出选择模式
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已合并并导出 GPX')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('合并导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  /// 空状态
  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: Icons.route_outlined,
              text: '暂无历史轨迹',
              hint: '点击下方按钮开始录制你的第一条出行轨迹',
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: '开始录制',
              onPressed: () => context.push('/trajectory-record'),
            ),
          ],
        ),
      ),
    );
  }

  /// 历史列表
  Widget _buildList(BuildContext context, List<TrajectoryRecord> records) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
        children: [
          // 提示：选择模式入口
          if (!_selectionMode && records.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '提示：点击右上角「多选合并」可把多条轨迹合并为一条并导出 GPX',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          // 轨迹卡片列表（交错波浪滑入，每项延迟 60ms）
          ...records.indexed.map(
            (e) => FadeSlideIn(
              delay: 120 + e.$1 * 60,
              child: Dismissible(
                key: Key(e.$2.id),
                direction: _selectionMode
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 28),
                ),
                confirmDismiss: (direction) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除轨迹'),
                      content: Text(
                          '确定删除「${e.$2.displayTitle}」吗？此操作不可撤销。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  return ok == true;
                },
                onDismissed: (_) async {
                  final removed = e.$2;
                  await ref
                      .read(trajectoryHistoryProvider.notifier)
                      .delete(removed.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已删除「${removed.displayTitle}」'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () => ref
                            .read(trajectoryHistoryProvider.notifier)
                            .updateRecord(removed),
                      ),
                    ),
                  );
                },
                child: _TrajectoryCard(
                  record: e.$2,
                  selectable: _selectionMode,
                  selected: _selected.contains(e.$2.id),
                  onToggle: () => _toggleSelect(e.$2.id),
                  onOpen: () {
                    if (_selectionMode) {
                      _toggleSelect(e.$2.id);
                    } else {
                      context.push('/trajectory-detail/${e.$2.id}');
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 头部统计行（轨迹数 / 总距离 / 总时长）
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.records});

  final List<TrajectoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final totalDist = records.fold(0.0, (sum, r) => sum + r.distance);
    final totalDur = records.fold(0, (sum, r) => sum + r.duration);

    return Row(
      children: [
        _SummaryStat(
          label: '轨迹数',
          value: '${records.length}',
          icon: Icons.list_alt,
          counterValue: records.length,
          counterFormatter: (v) => v.round().toString(),
        ),
        _SummaryStat(
          label: '总里程',
          value: totalDist >= 1000
              ? '${(totalDist / 1000).toStringAsFixed(1)} km'
              : '${totalDist.round()} m',
          icon: Icons.straighten,
          counterValue: totalDist,
          counterFormatter: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(1)} km'
              : '${v.round()} m',
        ),
        _SummaryStat(
          label: '总时长',
          value: _formatDuration(totalDur),
          icon: Icons.timer,
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}

/// 头部统计加载占位
class _HeaderStatsShimmer extends StatelessWidget {
  const _HeaderStatsShimmer();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 56);
}

/// 总统计中的单项（支持数字滚动动画）
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.counterValue,
    this.counterFormatter,
  });

  final String label;
  final String value;
  final IconData icon;

  /// 数值动画目标值（可选）
  final num? counterValue;
  final String Function(num)? counterFormatter;

  @override
  Widget build(BuildContext context) {
    final fmt = counterFormatter;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          if (counterValue != null && fmt != null)
            AnimatedCounter(
              value: counterValue!,
              formatter: fmt,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            )
          else
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

/// 单条轨迹卡片
class _TrajectoryCard extends StatelessWidget {
  const _TrajectoryCard({
    required this.record,
    this.selectable = false,
    this.selected = false,
    this.onToggle,
    this.onOpen,
  });
  final TrajectoryRecord record;

  /// 是否处于多选模式（显示勾选框）
  final bool selectable;
  /// 是否被选中
  final bool selected;
  /// 勾选切换回调
  final VoidCallback? onToggle;
  /// 点击打开/切换选中
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      onLongPress: onToggle,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 多选模式：显示勾选框
                if (selectable)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.route,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${record.city ?? '未知城市'}  ·  ${record.dateText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // 距离标签
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    record.distanceText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                if (!selectable)
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            // 小统计行
            Row(
              children: [
                _MiniStat(
                    icon: Icons.timer_outlined,
                    text: record.durationText),
                const SizedBox(width: 16),
                _MiniStat(
                    icon: Icons.pause_circle,
                    text: '${record.stops.length} 停留'),
                const SizedBox(width: 16),
                if (record.maxAltitude != null)
                  _MiniStat(
                      icon: Icons.terrain,
                      text: '${record.maxAltitude!.round()}m'),
                if (selectable) const Spacer(),
                if (selectable)
                  Text(
                    selected ? '已选' : '点击选择',
                    style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textTertiary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
