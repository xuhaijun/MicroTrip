import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/cloud_trajectory.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 云端历史页（Phase 5）
///
/// 设计语言：统一「微旅途」现代风格
///  - GradientHeader 替掉 AppBar（含返回按钮）
///  - 引导/错误/空态统一使用 EmptyState，主操作使用 GradientButton
///  - 内容卡片保持 AppCard 白卡
///
/// 功能：
///  - 分页拉取 GET /trajectory/list（摘要，不含 GPS 点）
///  - 点击卡片 → 拉取完整详情 → 进入轨迹详情页（云端模式）
///  - 长按卡片 → 删除云端记录
///  - 下拉刷新 / 加载更多
///  - 未登录或未配置后端地址 → 引导提示（优雅降级）
///
/// 说明：本页用 ConsumerStatefulWidget 而非普通 StatefulWidget，
/// 只为在删除云端记录后 invalidate `cloudStatsProvider` ——
/// 「我的」页的云端足迹卡片是缓存型 FutureProvider，
/// 不主动失效会让用户回到「我的」页仍看到删除前的条数。
/// ============================================================
class CloudTrajectoryPage extends ConsumerStatefulWidget {
  const CloudTrajectoryPage({super.key});

  @override
  ConsumerState<CloudTrajectoryPage> createState() =>
      _CloudTrajectoryPageState();
}

class _CloudTrajectoryPageState extends ConsumerState<CloudTrajectoryPage> {
  final List<CloudTrajectory> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  bool _loadingMore = false;
  String? _openingId; // 正在加载详情的卡片 id（显示进度）

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  /// 拉取列表（initial: 首屏/刷新；否则为加载更多）
  Future<void> _load({bool initial = false}) async {
    // 未配置后端：直接显示引导状态
    if (!SyncService.isConfigured) {
      setState(() {
        _error = null;
        _items.clear();
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _loading = initial;
      _loadingMore = !initial;
      _error = null;
    });
    try {
      final data = await SyncService.fetchList(
        page: initial ? 1 : _page + 1,
      );
      setState(() {
        if (initial) {
          _items
            ..clear()
            ..addAll(data.list);
          _page = 1;
        } else {
          _items.addAll(data.list);
          _page = data.page;
        }
        _total = data.total;
        _hasMore = data.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (initial && _items.isEmpty) {
          _error = e.toString().replaceFirst('ServiceException: ', '');
        }
      });
      if (!initial || _items.isNotEmpty) {
        _showSnack('加载失败: $e');
      }
    }
  }

  /// 点击卡片：拉取完整详情后进入轨迹详情页（云端模式）
  Future<void> _openDetail(CloudTrajectory item) async {
    if (_openingId != null) return; // 防止重复点击
    setState(() => _openingId = item.id);
    try {
      final record = await SyncService.fetchDetail(item.id);
      if (!mounted) return;
      // extra 传完整记录 → 详情页直接渲染，不再查本地仓库
      context.push('/trajectory-detail/${item.id}', extra: record);
    } catch (e) {
      if (mounted) _showSnack('加载详情失败: $e');
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  /// 长按删除云端记录
  Future<void> _confirmDelete(CloudTrajectory item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除云端轨迹'),
        content: Text(
            '将删除「${item.displayTitle}」的云端备份（不影响本地数据），确定继续吗？'),
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
    try {
      await SyncService.deleteRemote(item.id);
      if (mounted) {
        setState(() => _items.removeWhere((e) => e.id == item.id));
        // 契约：统计由服务端聚合，客户端无法本地推算，必须重拉
        ref.read(cloudStatsProvider.notifier).refresh();
        _showSnack('已删除云端轨迹');
      }
    } catch (e) {
      if (mounted) _showSnack('删除失败: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ---- 统一渐变头部 ----
          GradientHeader(
            title: '云端轨迹',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          // ---- 内容区（下拉刷新）----
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(initial: true),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 1) 未配置后端：引导去登录/设置
    if (!SyncService.isConfigured) {
      return _buildGuide();
    }
    // 2) 首屏加载中
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // 3) 加载失败且无数据
    if (_error != null && _items.isEmpty) {
      return _buildError();
    }
    // 4) 空列表
    if (_items.isEmpty) {
      return _buildEmpty();
    }
    // 5) 列表
    return _buildList();
  }

  /// 未配置后端 / 未登录引导
  Widget _buildGuide() {
    final loggedIn = AuthService.isLoggedIn;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.cloud_off_outlined,
          text: '云端同步未启用',
          hint: loggedIn
              ? '请先在「设置」中配置后端服务地址，再同步轨迹到云端'
              : '请先登录账号，并在「设置」中配置后端服务地址',
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: '前往设置',
          onPressed: () => context.push('/profile/settings'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.wifi_off_outlined,
          text: '加载失败',
          hint: _error ?? '',
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _load(initial: true),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const EmptyState(
          icon: Icons.cloud_queue_outlined,
          text: '云端还没有轨迹',
          hint: '在「设置」中点击「立即同步」，把本地轨迹备份到云端',
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: '去同步',
          onPressed: () => context.push('/profile/settings'),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 顶部统计
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '共 $_total 条云端轨迹 · 下拉刷新',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        // 卡片列表
        ..._items.map((item) => _CloudCard(
              item: item,
              opening: _openingId == item.id,
              onTap: () => _openDetail(item),
              onLongPress: () => _confirmDelete(item),
            )),
        // 加载更多
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _loadingMore
                ? const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : OutlinedButton(
                    onPressed: () => _load(initial: false),
                    child: const Text('加载更多'),
                  ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('— 已加载全部 —',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ),
          ),
      ],
    );
  }
}

/// 云端轨迹卡片
class _CloudCard extends StatelessWidget {
  const _CloudCard({
    required this.item,
    required this.opening,
    required this.onTap,
    required this.onLongPress,
  });

  final CloudTrajectory item;
  final bool opening;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: opening
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined,
                          color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${item.dateText}  ${item.durationText}'
                        '${item.city != null ? "  ·  ${item.city}" : ""}',
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
                    item.distanceText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 小统计行
            Row(
              children: [
                Icon(Icons.speed, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${item.avgSpeed?.toStringAsFixed(1) ?? "0.0"} km/h',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '同步于 ${item.syncedAtText}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
