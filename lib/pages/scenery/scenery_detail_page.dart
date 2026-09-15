import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../models/scenery_item.dart';
import '../../providers/app_providers.dart';
import '../../services/favorite_repository.dart';
import '../map/nearby_map_page.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 景点详情页（对应小程序 subpackages/city/pages/scenery 详情模式）
/// - 顶部渐变卡：emoji + 名称 + 星级评分 + 门票
/// - 信息面板：建议时长 / 开放时间 / 地址 / 导航
/// - 图文描述 + 收藏
/// - 周边推荐「周边逛逛」（点击可跳转对应详情）
///
/// 数据源由「模拟数据总开关」控制：详情与周边由 provider 异步拉取。
/// ============================================================
class SceneryDetailPage extends ConsumerStatefulWidget {
  const SceneryDetailPage({super.key, required this.sceneryId});

  final int sceneryId;

  @override
  ConsumerState<SceneryDetailPage> createState() => _SceneryDetailPageState();
}

class _SceneryDetailPageState extends ConsumerState<SceneryDetailPage> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  /// 读取收藏状态
  Future<void> _loadFavorite() async {
    final fav = await FavoriteRepository.isFavorite(
        FavoriteType.scenery, widget.sceneryId.toString());
    if (mounted) setState(() => _isFavorite = fav);
  }

  /// 切换收藏
  Future<void> _toggleFavorite(SceneryItem item) async {
    if (_isFavorite) {
      await FavoriteRepository.remove(
          FavoriteType.scenery, item.id.toString());
    } else {
      await FavoriteRepository.save(FavoriteItem(
        id: item.id.toString(),
        type: FavoriteType.scenery,
        name: item.name,
        image: item.image,
        desc: item.desc,
        address: item.address,
        rating: item.ratingText,
      ));
    }
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFavorite ? '已收藏「${item.name}」' : '已取消收藏'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  /// 分享景点：调起系统分享面板（自动包含微信 / 朋友圈 / QQ / 短信等已安装渠道）
  ///
  /// 注意：share_plus 10.x 使用静态方法 [Share.share]（11.x 才引入
  /// `SharePlus.instance.share(ShareParams(...))` 新 API，与本项目锁定版本不符）。
  Future<void> _shareScenery(SceneryItem item) async {
    final text = '🏞️ 我在「微旅途」发现了一个好去处：${item.name}\n'
        '⭐ 评分 ${item.ratingText} · ${item.ticket}\n'
        '📍 ${item.address}\n${item.desc}';
    await Share.share(text, subject: '微旅途 · ${item.name}');
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(cityProvider);
    final mock = ref.watch(useMockDataProvider);
    final detailAsync =
        ref.watch(sceneryDetailProvider((id: widget.sceneryId, city: city.name, mock: mock)));
    final nearbyAsync =
        ref.watch(sceneryNearbyProvider((id: widget.sceneryId, city: city.name, mock: mock)));

    final header = GradientHeader(
      title: '美景详情',
      subtitle: '${city.name} · 周边好去处',
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
          tooltip: '分享',
          onPressed: () => detailAsync.whenData(
            (result) => _shareScenery(result.data), // whenData 回调收到 SceneryResult，需取 .data
          ),
        ),
        detailAsync.when(
          data: (result) => IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppColors.danger : Colors.white70,
              size: 22,
            ),
            tooltip: '收藏',
            onPressed: () => _toggleFavorite(result.data),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 22),
          tooltip: '返回',
          onPressed: () => context.pop(),
        ),
      ],
    );

    final body = detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: EmptyState(icon: Icons.error_outline, text: '加载失败'),
      ),
      data: (result) {
        final scenery = result.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(child: _buildHeader(scenery)),
            const SizedBox(height: 16),
            FadeSlideIn(delay: 60, child: _buildInfoPanel(scenery)),
            const SizedBox(height: 16),
            FadeSlideIn(delay: 120, child: _buildTags(scenery)),
            const SizedBox(height: 16),
            FadeSlideIn(delay: 180, child: _buildDesc(scenery)),
            const SizedBox(height: 20),
            const SectionTitle(title: '周边逛逛'),
            const SizedBox(height: 4),
            nearbyAsync.when(
              loading: () => const SizedBox(
                height: 118,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, _) => const SizedBox.shrink(),
              data: (nearby) => nearby.data.isEmpty
                  ? const SizedBox.shrink()
                  : _buildNearby(nearby.data),
            ),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 顶部渐变卡
  Widget _buildHeader(SceneryItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(item.image, style: const TextStyle(fontSize: 38)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Expanded + 省略号：评分文本可压缩/截断，避免窄屏（320）把 Row 撑破右溢。
                    // 不加 maxLines 时 Expanded 虽能给宽度，但文本无截断下限，
                    // 极端窄屏下仍可能令整行右溢（见 overflow_scan_test /scenery-detail）。
                    Expanded(
                      child: Text('⭐ ${item.ratingText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    // Flexible + 省略号：票务标签过长时收缩而非溢出
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.round),
                        ),
                        child: Text(item.ticket,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('建议游玩 ${item.duration}',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 信息面板（开放时间 / 地址 / 导航）
  Widget _buildInfoPanel(SceneryItem item) {
    return AppCard(
      child: Column(
        children: [
          _InfoRow(icon: Icons.schedule, label: '开放时间', value: item.openTime),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(
            icon: Icons.place_outlined,
            label: '地址',
            value: item.address,
            trailing: TextButton(
              onPressed: () {
                // 有坐标则带入聚焦导航；否则打开附近地图（我的位置/城市）
                if (item.latitude != 0) {
                  context.push(
                    '/nearby',
                    extra: NearbyFocus(
                      lat: item.latitude,
                      lng: item.longitude,
                      name: item.name,
                      type: 'scenery',
                    ),
                  );
                } else {
                  context.push('/nearby');
                }
              },
              // 紧凑样式：去掉 TextButton 默认可点高度(min ~36)与内边距，
              // 让「导航」文字与地址首行同一基线对齐（2026-09-15 修复「导航按钮未对齐」）。
              // 否则地址换行成 2 行时，按钮文字被顶到按钮框中部，与首行错开。
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                textStyle: const TextStyle(fontSize: 13, height: 1.4),
              ),
              child: Text(item.latitude != 0 ? '导航' : '附近',
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  /// 标签集合
  Widget _buildTags(SceneryItem item) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: item.tags
          .map((t) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradientWith(0.10),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                ),
                child: Text(t,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }

  /// 描述
  Widget _buildDesc(SceneryItem item) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('景点介绍',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(item.desc,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
        ],
      ),
    );
  }

  /// 周边推荐（横向滚动）
  Widget _buildNearby(List<NearbyScenery> list) {
    return SizedBox(
      // 周边卡片为竖向 Column，原 118 在真机字号下偶发 2~14px 底部溢出
      // （见 overflow_scan_test /scenery-detail）；抬到 132 留足余量。
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final n = list[i];
          return GestureDetector(
            onTap: () => context.push('/scenery-detail/${n.id}'),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                // mainAxisSize.min + 居中：仅取内容高度并居中，避免内容略高于
                // 固定高度时的底部溢出。
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(n.image, style: const TextStyle(fontSize: 22)),
                      const Spacer(),
                      Text('⭐ ${n.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(n.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  Text(n.distance,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
