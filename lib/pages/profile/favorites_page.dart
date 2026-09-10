import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../services/favorite_repository.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 我的收藏页（对应小程序 subpackages/tools/pages/favorites）
/// 美食 / 景点 两个 Tab，支持取消收藏
/// 说明：Phase 1 收藏数据由后续美食/景点详情页写入，
/// 当前页可直接体验收藏数据结构（详情页 Phase 3 上线）。
/// ============================================================
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  Map<FavoriteType, List<FavoriteItem>> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final food = await FavoriteRepository.loadAll(FavoriteType.food);
    final scenery = await FavoriteRepository.loadAll(FavoriteType.scenery);
    if (mounted) {
      setState(() {
        _data = {FavoriteType.food: food, FavoriteType.scenery: scenery};
      });
    }
  }

  Future<void> _remove(FavoriteItem item) async {
    await FavoriteRepository.remove(item.type, item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '我的收藏',
            actions: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ],
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: '美食 (${_data[FavoriteType.food]?.length ?? 0})'),
                Tab(text: '美景 (${_data[FavoriteType.scenery]?.length ?? 0})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _list(FavoriteType.food),
                _list(FavoriteType.scenery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(FavoriteType type) {
    final items = _data[type] ?? [];
    if (items.isEmpty) {
      return EmptyState(
        icon: type == FavoriteType.food ? Icons.restaurant : Icons.landscape,
        text: type == FavoriteType.food ? '还没有收藏美食' : '还没有收藏美景',
        hint: '发现页的推荐内容上线收藏能力后会出现在这里',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return FadeSlideIn(
          delay: i * 60,
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradientWith(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    type == FavoriteType.food
                        ? Icons.restaurant
                        : Icons.landscape,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      if (it.desc.isNotEmpty)
                        Text(it.desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite,
                      color: AppColors.danger, size: 20),
                  tooltip: '取消收藏',
                  onPressed: () => _remove(it),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
