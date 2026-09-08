import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/food_item.dart';
import '../../providers/app_providers.dart';
import '../../services/food_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 美食推荐列表页（对应小程序 subpackages/city/pages/food 列表模式）
/// - 顶部搜索框 + 分类标签横向筛选
/// - 卡片列表（emoji 图标 + 名称/评分/价格/简介）
/// - 点击进入 /food-detail/:id
/// - [embedded] = true：不渲染 Scaffold/AppBar，供发现页 Tab 内嵌复用
///
/// 数据源由「模拟数据总开关」控制：列表由 [foodListProvider] 异步拉取。
/// ============================================================
class FoodListPage extends ConsumerStatefulWidget {
  const FoodListPage({super.key, this.embedded = false});

  /// 内嵌模式：由父级 Scaffold（发现页 Tab）承载，不渲染独立 AppBar
  final bool embedded;

  @override
  ConsumerState<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends ConsumerState<FoodListPage> {
  String _keyword = '';
  String _activeTag = '全部';

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(cityProvider);
    final mock = ref.watch(useMockDataProvider);
    final listAsync =
        ref.watch(foodListProvider((city: city.name, mock: mock)));

    final body = listAsync.when(
      loading: () => Column(
        children: [
          _buildSearchBar(),
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      error: (e, _) => Column(
        children: [
          _buildSearchBar(),
          Expanded(child: EmptyState(icon: Icons.error_outline, text: '加载失败')),
        ],
      ),
      data: (result) {
        final tags = FoodService.deriveTags(result.data);
        final items = FoodService.filterList(
          result.data,
          keyword: _keyword,
          tag: _activeTag,
        );
        return Column(
          children: [
            _buildSearchBar(),
            _buildTagBar(tags),
            const SizedBox(height: 4),
            Expanded(child: _buildList(items)),
          ],
        );
      },
    );

    // 内嵌模式：只返回内容，由父级 Scaffold 承载
    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '美食推荐',
            subtitle: city.name,
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 22),
                tooltip: '切换城市',
                onPressed: () => context.push('/city-list'),
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 搜索框
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          hintText: '搜索美食名称或简介…',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textHint),
                  onPressed: () => setState(() => _keyword = ''),
                ),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.round),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// 分类标签横向滚动
  Widget _buildTagBar(List<String> tags) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final selected = tag == _activeTag;
          return ChoiceChip(
            label: Text(tag, style: const TextStyle(fontSize: 13)),
            selected: selected,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            showCheckmark: false,
            backgroundColor: AppColors.card,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() => _activeTag = tag),
          );
        },
      ),
    );
  }

  /// 列表 / 空状态
  Widget _buildList(List<FoodItem> items) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.ramen_dining, text: '没有匹配的美食');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: i * 60,
        child: _FoodCard(item: items[i]),
      ),
    );
  }
}

/// 美食列表卡片
class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item});
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/food-detail/${item.id}'),
      child: Row(
        children: [
          // emoji 图标区
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientWith(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(item.image, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text('⭐ ${item.ratingText}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TagChip(text: item.tag, filled: false),
                    const SizedBox(width: 8),
                    Text(item.price,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}

/// 轻量标签
class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.round),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: filled ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
