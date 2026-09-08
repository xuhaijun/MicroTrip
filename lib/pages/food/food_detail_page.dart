import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../models/food_item.dart';
import '../../providers/app_providers.dart';
import '../../services/favorite_repository.dart';
import '../../services/food_service.dart';
import '../map/nearby_map_page.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 美食详情页（对应小程序 subpackages/city/pages/food 详情模式）
/// - 顶部渐变卡：emoji + 名称 + 星级评分 + 价格
/// - 标签集合 / 图文描述 / 小贴士
/// - 推荐店铺「去哪吃」（由 provider 异步拉取，随开关切换 服务端 / 本地示例）
/// - 收藏（FavoriteRepository，与我的页收藏打通）
///
/// 数据源由「模拟数据总开关」控制：美食详情与推荐门店均由 provider 异步拉取。
/// ============================================================
class FoodDetailPage extends ConsumerStatefulWidget {
  const FoodDetailPage({super.key, required this.foodId});

  final int foodId;

  @override
  ConsumerState<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends ConsumerState<FoodDetailPage> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  /// 读取收藏状态
  Future<void> _loadFavorite() async {
    final fav = await FavoriteRepository.isFavorite(
        FavoriteType.food, widget.foodId.toString());
    if (mounted) setState(() => _isFavorite = fav);
  }

  /// 切换收藏
  Future<void> _toggleFavorite(FoodItem food) async {
    if (_isFavorite) {
      await FavoriteRepository.remove(FavoriteType.food, food.id.toString());
    } else {
      await FavoriteRepository.save(FavoriteItem(
        id: food.id.toString(),
        type: FavoriteType.food,
        name: food.name,
        image: food.image,
        desc: food.desc,
        rating: food.ratingText,
      ));
    }
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFavorite ? '已收藏「${food.name}」' : '已取消收藏'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  /// 分享美食：调起系统分享面板（自动包含微信 / 朋友圈 / QQ / 短信等已安装渠道）
  ///
  /// 注意：share_plus 10.x 使用静态方法 [Share.share]（11.x 才引入
  /// `SharePlus.instance.share(ShareParams(...))` 新 API，与本项目锁定版本不符）。
  Future<void> _shareFood(FoodItem food) async {
    final text = '🍜 我在「微旅途」发现了一道美食：${food.name}\n'
        '⭐ 评分 ${food.ratingText} · 参考价 ${food.price}\n'
        '${food.desc}';
    await Share.share(text, subject: '微旅途 · ${food.name}');
  }

  /// 推荐门店区块（异步拉取）
  Widget _buildShopsSection(AsyncValue<FoodResult<List<FoodShop>>> shopsAsync) {
    return shopsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (shopsResult) {
        final shops = shopsResult.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: '去哪吃 · 推荐店铺'),
            const SizedBox(height: 4),
            ...shops.map((s) => _ShopCard(shop: s)),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.explore, size: 18),
                label: const Text('在附近地图查看周边'),
                onPressed: () => context.push('/nearby'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primaryLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(cityProvider);
    final mock = ref.watch(useMockDataProvider);
    final detailAsync =
        ref.watch(foodDetailProvider((id: widget.foodId, city: city.name, mock: mock)));
    final shopsAsync = ref.watch(foodShopsProvider((city: city.name, mock: mock)));

    final header = GradientHeader(
      title: '美食详情',
      subtitle: '${city.name} · 特色美食',
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
          tooltip: '分享',
          onPressed: () => detailAsync.whenData(
            (result) => _shareFood(result.data), // whenData 回调收到 FoodResult，需取 .data
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
        final food = result.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(child: _buildHeader(food)),
            const SizedBox(height: 16),
            FadeSlideIn(delay: 60, child: _buildTags(food)),
            const SizedBox(height: 16),
            FadeSlideIn(delay: 120, child: _buildDesc(food)),
            if (food.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              FadeSlideIn(delay: 180, child: _buildTips(food)),
            ],
            const SizedBox(height: 20),
            FadeSlideIn(delay: 200, child: _buildShopsSection(shopsAsync)),
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

  /// 顶部渐变卡（emoji + 名称 + 评分 + 价格）
  Widget _buildHeader(FoodItem food) {
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
            child: Text(food.image, style: const TextStyle(fontSize: 38)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 8),
                // 评分 + 星级说明同处一行：窄屏（320）下二者固有宽度之和偶发右溢 2.5px，
                // 见 overflow_scan_test。改为 Flex 子项 + 省略号，评分占自然宽度、星级说明
                // 占用剩余空间并在过长时截断，杜绝溢出。
                Row(
                  children: [
                    Flexible(
                      child: Text('⭐ ${food.ratingText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(food.starText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('参考价 ${food.price}',
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

  /// 标签集合
  Widget _buildTags(FoodItem food) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: food.tags
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
  Widget _buildDesc(FoodItem food) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('图文详情',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(food.desc,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
        ],
      ),
    );
  }

  /// 小贴士（温馨提示）
  Widget _buildTips(FoodItem food) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(food.tips,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 推荐店铺卡片
class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});
  final FoodShop shop;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () {
        // 门店有坐标则带入聚焦；否则打开附近地图（基于我的位置/城市）
        if (shop.latitude != 0 && shop.longitude != 0) {
          context.push(
            '/nearby',
            extra: NearbyFocus(
              lat: shop.latitude,
              lng: shop.longitude,
              name: shop.name,
              type: 'food',
            ),
          );
        } else {
          context.push('/nearby');
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientWith(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.storefront,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text('⭐ ${shop.rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${shop.address} · ${shop.distance}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('人均 ${shop.avgPrice}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
