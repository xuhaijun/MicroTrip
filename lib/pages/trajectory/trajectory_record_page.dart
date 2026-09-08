import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../pages/shared/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../widgets/map/trajectory_map_widget.dart';

/// 距离数值动画格式化：米 → 自动切 km 显示（与 distanceText 规则一致）
String _fmtDistance(num meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
  return '${meters.round()} m';
}

/// ============================================================
/// 轨迹录制页（Phase 2）
///
/// 设计语言：统一「微旅途」现代风格
///  - GradientHeader 替掉 AppBar（含返回按钮与快捷停止）
///  - 居中大圆形录制按钮，按 status 切换 开始/暂停/继续/停止
///    颜色：primary（开始/继续）/ accent（暂停）/ danger（停止）
///  - 实时统计卡片（距离/时长/平均速度/采样点）+ 地图占位
///
/// 对应小程序 subpackages/travel/pages/trajectory-record
/// ============================================================
class TrajectoryRecordPage extends ConsumerStatefulWidget {
  const TrajectoryRecordPage({super.key});

  @override
  ConsumerState<TrajectoryRecordPage> createState() =>
      _TrajectoryRecordPageState();
}

class _TrajectoryRecordPageState extends ConsumerState<TrajectoryRecordPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(trajectoryRecordingProvider);
    final stats = recState.stats;
    final status = recState.status;

    return Scaffold(
      body: Column(
        children: [
          // ---- 统一渐变头部 ----
          GradientHeader(
            title: '记录轨迹',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
              if (status == RecordingStatus.recording ||
                  status == RecordingStatus.paused)
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.white),
                  tooltip: '停止并保存',
                  onPressed: () => _onStop(context),
                ),
            ],
          ),
          // ---- 实时地图 ----
          Expanded(
            flex: 3,
            child: TrajectoryMapWidget(
              points: stats.points,
              fitBounds: true,
              interactive: true,
            ),
          ),
          // ---- 实时统计面板 ----
          // 用 SingleChildScrollView 包裹：矮屏（如 320×568）下内容超过 flex
          // 分配空间时改为滚动，避免底部溢出；常态高屏内容自适应、不滚动。
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                  // 统计卡片（数字随 GPS 更新平滑滚动）
                  Row(
                    children: [
                      _StatCard(
                        label: '距离',
                        value: stats.distanceText,
                        icon: Icons.straighten,
                        counterValue: stats.distance,
                        counterFormatter: _fmtDistance,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: '时长',
                        value: stats.durationText,
                        icon: Icons.timer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatCard(
                        label: '平均速度',
                        value: stats.avgSpeedText,
                        icon: Icons.speed,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: '采样点',
                        value: '${stats.pointCount}',
                        icon: Icons.location_searching,
                        counterValue: stats.pointCount,
                        counterFormatter: (v) => v.round().toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 海拔信息
                  if (stats.maxAltitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.terrain, size: 16,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          // 单行省略号：长海拔文案在窄屏（320）会撑破 Row（之前右侧溢出 50px）
                          Expanded(
                            child: Text(
                              '海拔 ${stats.minAltitude?.round()}m ~'
                              ' ${stats.maxAltitude?.round()}m'
                              '  |  爬升 ${stats.ascent.round()}m'
                              '  下降 ${stats.descent.round()}m',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12), // 原为 Spacer：滚动容器内不可用，改为固定间距
                  // 录制控制按钮
                  _buildControls(context, status),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// 大圆形录制按钮
  Widget _bigButton({
    required Color color,
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 72,
  }) {
    return Material(
      shape: const CircleBorder(),
      color: color,
      elevation: 6,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.42),
        ),
      ),
    );
  }

  /// 录制控制按钮
  Widget _buildControls(BuildContext context, RecordingStatus status) {
    switch (status) {
      case RecordingStatus.idle:
        return Center(
          child: _bigButton(
            color: AppColors.primary,
            icon: Icons.play_arrow,
            onPressed: () => _start(context),
          ),
        );
      case RecordingStatus.recording:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bigButton(
              color: AppColors.accent,
              icon: Icons.pause,
              onPressed: () =>
                  ref.read(trajectoryRecordingProvider.notifier).pause(),
            ),
            const SizedBox(width: 32),
            _bigButton(
              color: AppColors.danger,
              icon: Icons.stop,
              size: 56,
              onPressed: () => _onStop(context),
            ),
          ],
        );
      case RecordingStatus.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bigButton(
              color: AppColors.primary,
              icon: Icons.play_arrow,
              onPressed: () =>
                  ref.read(trajectoryRecordingProvider.notifier).resume(),
            ),
            const SizedBox(width: 32),
            _bigButton(
              color: AppColors.danger,
              icon: Icons.stop,
              size: 56,
              onPressed: () => _onStop(context),
            ),
          ],
        );
      case RecordingStatus.stopped:
        return const SizedBox.shrink();
    }
  }

  /// 开始录制
  Future<void> _start(BuildContext context) async {
    final ok = await ref.read(trajectoryRecordingProvider.notifier).start();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法开始录制：请检查定位权限和GPS开关'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 停止录制 — 弹出标题输入，保存轨迹
  Future<void> _onStop(BuildContext context) async {
    final titleController = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存轨迹'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '轨迹标题（可选）',
            hintText: '如：周末骑行锦江绿道',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // 弹窗关闭后输入框已无用，立即释放，避免 controller 泄漏
    titleController.dispose();

    // 用户点击「取消」：showDialog 返回 null。
    // 修复点：之前即便取消也会继续执行 stop() 导致轨迹被保存。
    // 现在取消即中止本次停止/保存，保留当前录制状态（可继续录制或稍后再停止）。
    if (title == null) return;

    final record = await ref
        .read(trajectoryRecordingProvider.notifier)
        .stop(title: title);

    if (record == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('轨迹已保存：${record.displayTitle} (${record.distanceText})'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // 返回到轨迹列表
    context.pop();
  }
}

/// 统计小卡片
/// 提供 [counterValue] + [counterFormatter] 时数值平滑滚动
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.counterValue,
    this.counterFormatter,
  });

  final String label;
  final String value;
  final IconData icon;

  /// 数值动画目标值（可选）；提供后替代静态 [value] 文本
  final num? counterValue;
  final String Function(num)? counterFormatter;

  @override
  Widget build(BuildContext context) {
    final fmt = counterFormatter;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            // 用 Expanded 约束 Column 宽度，避免数值文本以固有宽度撑破 Row（之前右侧溢出 50px）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  // 数值动画：录制中距离/点数随 GPS 更新平滑滚动
                  if (counterValue != null && fmt != null)
                    AnimatedCounter(
                      value: counterValue!,
                      formatter: fmt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    )
                  else
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
