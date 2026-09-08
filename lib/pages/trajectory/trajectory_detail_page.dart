import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../models/trajectory.dart';
import '../../pages/shared/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../services/gpx_service.dart';
import '../../services/sync_service.dart';
import '../../services/trajectory_repository.dart';
import '../../widgets/map/trajectory_map_widget.dart';

/// ============================================================
/// 轨迹详情页（Phase 2 / Phase 5 扩展）
///
/// 设计语言：统一「微旅途」现代风格
///  - GradientHeader 替掉 AppBar（含返回 + 分享/GPX/删除·下载动作）
///  - 内容全部 AppCard 白卡；标题卡改为白卡统计行，日期进头部副标题
///
/// 功能：
///  - 全屏地图展示完整轨迹（Polyline + 停留点 + 起终点）
///  - 统计卡片（距离/时长/平均速度/爬升/停留点数）
///  - 停留点列表
///  - 截图分享（ScreenshotController + share_plus）
///  - 编辑标题/备注
///  - 删除轨迹
///
/// Phase 5：支持云端轨迹直传渲染 ——
///  - [externalRecord] 非空时跳过本地加载，直接渲染该记录（云端详情场景）；
///  - [fromCloud] = true 时删除操作改为调用 SyncService.deleteRemote。
///
/// 对应小程序 subpackages/travel/pages/trajectory-detail
/// ============================================================
class TrajectoryDetailPage extends ConsumerStatefulWidget {
  const TrajectoryDetailPage({
    super.key,
    required this.trajectoryId,
    this.externalRecord,
    this.fromCloud = false,
  });

  final String trajectoryId;

  /// 云端模式：外部传入的完整轨迹记录（不查本地仓库）
  final TrajectoryRecord? externalRecord;

  /// 是否为云端轨迹（影响操作按钮语义）
  final bool fromCloud;

  @override
  ConsumerState<TrajectoryDetailPage> createState() =>
      _TrajectoryDetailPageState();
}

class _TrajectoryDetailPageState extends ConsumerState<TrajectoryDetailPage> {
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  bool _isSharing = false;
  bool _isDownloading = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    // 云端模式：直接使用外部传入的记录，不依赖本地 provider
    if (widget.externalRecord != null) {
      return _buildScaffold(context, widget.externalRecord!);
    }
    final recordAsync = ref.watch(trajectoryDetailProvider(widget.trajectoryId));

    return recordAsync.when(
      loading: () => _buildScaffold(context, null),
      error: (e, _) => _buildScaffold(context, null, error: e.toString()),
      data: (record) => record == null
          ? _buildScaffold(context, null, notFound: true)
          : _buildScaffold(context, record),
    );
  }

  /// 组装 Scaffold（本地与云端模式共用）
  Widget _buildScaffold(BuildContext context, TrajectoryRecord? record,
      {String? error, bool notFound = false}) {
    return Scaffold(
      body: Column(
        children: [
          // ---- 统一渐变头部（含返回 + 分享/GPX/删除·下载）----
          GradientHeader(
            title: record?.displayTitle ?? '轨迹详情',
            subtitle: record != null
                ? '${record.dateText}  ·  ${record.city ?? "未知城市"}'
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
              if (record != null) _buildShareAction(),
              if (record != null) _buildGpxAction(record),
              if (record != null)
                widget.fromCloud
                    ? IconButton(
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_outlined,
                                color: Colors.white),
                        tooltip: '下载到本地',
                        onPressed: _isDownloading
                            ? null
                            : () => _downloadToLocal(record),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        tooltip: '删除轨迹',
                        onPressed: () => _confirmDelete(context),
                      ),
            ],
          ),
          // ---- 内容区 ----
          Expanded(
            child: _buildContent(context, record,
                error: error, notFound: notFound),
          ),
        ],
      ),
    );
  }

  /// 内容分发：加载 / 错误 / 空 / 正常
  Widget _buildContent(BuildContext context, TrajectoryRecord? record,
      {String? error, bool notFound = false}) {
    if (record == null) {
      if (error != null) {
        return Center(
            child: Text('加载失败: $error',
                style: const TextStyle(color: AppColors.textSecondary)));
      }
      if (notFound) {
        return const Center(
            child: Text('轨迹不存在',
                style: TextStyle(color: AppColors.textSecondary)));
      }
      return const Center(child: CircularProgressIndicator());
    }
    return _buildBody(record);
  }

  /// 页面主体（汇总卡 + 地图 + 统计 + 停留点 [+ 编辑区]）
  Widget _buildBody(TrajectoryRecord record) {
    return Screenshot(
      controller: _screenshotCtrl,
      child: Container(
        color: AppColors.background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 汇总统计卡（白卡）
            _buildSummaryCard(record),
            const SizedBox(height: 16),
            // 地图
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: TrajectoryMapWidget(
                points: record.points,
                stops: record.stops,
                showControls: true,
                interactive: true,
              ),
            ),
            const SizedBox(height: 16),
            // 统计卡片网格
            _buildStatsGrid(record),
            const SizedBox(height: 16),
            // 停留点列表
            if (record.stops.isNotEmpty) ...[
              _buildStopsSection(record.stops),
              const SizedBox(height: 16),
            ],
            // 编辑标题（云端记录只读，不显示编辑区）
            if (!widget.fromCloud) _buildEditSection(record),
          ],
        ),
      ),
    );
  }

  /// 汇总统计卡（距离 / 时长 / 平均）
  Widget _buildSummaryCard(TrajectoryRecord record) {
    return AppCard(
      child: Row(
        children: [
          _SummaryStat(label: '距离', value: record.distanceText),
          _SummaryStat(
              label: '时长', value: record.durationText),
          _SummaryStat(
              label: '平均',
              value:
                  '${record.avgSpeed?.toStringAsFixed(1) ?? "0.0"} km/h'),
        ],
      ),
    );
  }

  /// 统计网格
  Widget _buildStatsGrid(TrajectoryRecord record) {
    // 用 Wrap + 等宽 SizedBox 取代固定 childAspectRatio 的 GridView：
    // 每个瓦片高度由内容（图标 + 两行文字）自然决定，永不被压矮而纵向溢出；
    // 宽度按可用空间均分两列，长内容走省略号不会横向溢出。
    // 原 GridView.count(childAspectRatio: 2.8) 在窄屏 / 大字号下会把瓦片压得过矮，
    // 导致内部 Row 横向溢出 12px、Column 纵向溢出 7.7~8px。
    final tiles = <Widget>[
        _StatTile(
          icon: Icons.terrain,
          label: '最高海拔',
          value: record.maxAltitude != null
              ? '${record.maxAltitude!.round()} m'
              : '—',
        ),
        _StatTile(
          icon: Icons.south,
          label: '最低海拔',
          value: record.minAltitude != null
              ? '${record.minAltitude!.round()} m'
              : '—',
        ),
        _StatTile(
          icon: Icons.trending_up,
          label: '累计爬升',
          value: '${record.ascent?.round() ?? 0} m',
        ),
        _StatTile(
          icon: Icons.trending_down,
          label: '累计下降',
          value: '${record.descent?.round() ?? 0} m',
        ),
        _StatTile(
          icon: Icons.location_searching,
          label: '采样点数',
          value: '${record.points.length}',
        ),
        _StatTile(
          icon: Icons.pause_circle,
          label: '停留点数',
          value: '${record.stops.length}',
        ),
      ];
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tileW = (constraints.maxWidth - 12) / 2; // 12 = 列间距
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles
              .map((t) => SizedBox(width: tileW, child: t))
              .toList(),
        );
      },
    );
  }

  /// 停留点列表
  Widget _buildStopsSection(List<StopPoint> stops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: '停留点（${stops.length}）'),
        const SizedBox(height: 12),
        ...stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final stop = entry.value;
          final arrTime = DateTime.fromMillisecondsSinceEpoch(stop.arrivalTime);
          final depTime = DateTime.fromMillisecondsSinceEpoch(stop.departureTime);
          return AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.15),
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              stop.label ?? '停留点 ${idx + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              stop.durationText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_timeStr(arrTime)} - ${_timeStr(depTime)}'
                        '${stop.address != null ? "  |  ${stop.address}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 编辑标题/备注
  Widget _buildEditSection(TrajectoryRecord record) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '编辑信息',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: record.title ?? ''),
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (val) => _updateRecord(record, title: val),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: record.note ?? ''),
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            onSubmitted: (val) => _updateRecord(record, note: val),
          ),
        ],
      ),
    );
  }

  /// 更新轨迹信息
  Future<void> _updateRecord(TrajectoryRecord record,
      {String? title, String? note}) async {
    final updated = record.copyWith(title: title, note: note);
    await ref.read(trajectoryHistoryProvider.notifier).updateRecord(updated);
    ref.invalidate(trajectoryDetailProvider(widget.trajectoryId));
  }

  /// 分享动作按钮
  Widget _buildShareAction() {
    return IconButton(
      icon: _isSharing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.share, color: Colors.white),
      tooltip: '分享轨迹截图',
      onPressed: _isSharing ? null : () => _shareScreenshot(),
    );
  }

  /// 导出 GPX 动作按钮（record 为空时禁用）
  Widget _buildGpxAction(TrajectoryRecord record) {
    final enabled = !_isExporting;
    return IconButton(
      icon: _isExporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.file_download_outlined, color: Colors.white),
      tooltip: '导出 GPX 文件',
      onPressed: enabled ? () => _shareGpx(record) : null,
    );
  }

  /// 导出 GPX：生成标准 .gpx 文本 → 写临时文件 → 系统分享
  Future<void> _shareGpx(TrajectoryRecord record) async {
    setState(() => _isExporting = true);
    try {
      final gpx = GpxService.exportTrackToGpx(record);
      final dir = await getTemporaryDirectory();
      final safeName = (record.displayTitle)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/${safeName}_${record.id}.gpx');
      await file.writeAsString(gpx);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '微旅途 — 轨迹 GPX：${record.displayTitle}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出 GPX 失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// 截图分享
  Future<void> _shareScreenshot() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotCtrl.capture();
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('截图失败，请重试')),
          );
        }
        return;
      }

      // 保存到临时文件
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/trajectory_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);

      // 系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '微旅途 — 我的出行轨迹',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// 确认删除（本地模式删本地记录；云端模式删云端记录）
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.fromCloud ? '删除云端轨迹' : '删除轨迹'),
        content: Text(widget.fromCloud
            ? '将删除云端备份的这条轨迹（不影响本地数据），确定继续吗？'
            : '确定删除这条轨迹吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (widget.fromCloud) {
      // 云端模式：调用 SyncService 删除云端记录
      try {
        await SyncService.deleteRemote(widget.trajectoryId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已删除云端轨迹')));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e')));
        }
      }
      return;
    }

    // 本地模式：从本地仓库删除
    await ref
        .read(trajectoryHistoryProvider.notifier)
        .delete(widget.trajectoryId);
    if (context.mounted) context.pop();
  }

  /// 云端模式：把当前轨迹保存到本地仓库（可离线查看）
  Future<void> _downloadToLocal(TrajectoryRecord record) async {
    setState(() => _isDownloading = true);
    try {
      await TrajectoryRepository.save(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已下载到本地，可在「出行轨迹」中查看')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _timeStr(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 汇总卡中的统计项（白卡，深色文字）
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 统计瓦片
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          // Expanded 让文字列受约束，长内容走省略号而非撑破 Row（修复横向溢出）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
