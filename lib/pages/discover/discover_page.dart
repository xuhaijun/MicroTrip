import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_info.dart';
import '../../providers/app_providers.dart';
import '../../services/ai_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 发现页（对应小程序 pages/discover）
/// 现代重设计：统一渐变头部（城市 + 拍照识物入口）
/// + 为你精选（美食/美景横向卡片）+ 智能推荐（小途自动生成、富文本、标签、重生成）
/// + 分类入口（美食 / 美景 / 拍照识物 / 一日游）
/// ============================================================
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final city = ref.watch(cityProvider);
    final mock = ref.watch(useMockDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------------- 统一渐变头部 ----------------
          GradientHeader(
            title: '发现',
            subtitle: '${city.name} · 为你精选好去处',
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined,
                    color: Colors.white70, size: 22),
                tooltip: '拍照识物',
                onPressed: () => context.push('/photo-recognition'),
              ),
            ],
          ),
          Transform.translate(
            // 区域整体下移：取消上叠（-16 会让内容浮在头部上、显得太靠顶），
            // 改为 0 自然落在渐变头部下方，配合顶部 24px 缓冲更靠下、更清爽。
            offset: const Offset(0, 0),
            child: Padding(
              // 顶部留足缓冲，让「为你精选」与渐变头部拉开间距、整体更靠下
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- 为你精选 ----------------
                  FadeSlideIn(
                    child: SectionTitle(
                      title: '为你精选',
                      onMore: () => context.push('/scenery'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: 80,
                    child: _FeaturedScroller(city: city.name, mock: mock),
                  ),
                  const SizedBox(height: 20),
                  // ---------------- 智能推荐 ----------------
                  FadeSlideIn(
                    delay: 140,
                    child: _SmartRecommend(city: city),
                  ),
                  const SizedBox(height: 20),
                  // ---------------- 分类入口 ----------------
                  FadeSlideIn(
                    delay: 200,
                    child: SectionTitle(title: '分类'),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: 240,
                    child: _CategoryGrid(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// 为你精选：美食 + 美景 横向卡片
/// ============================================================
class _FeaturedScroller extends ConsumerWidget {
  const _FeaturedScroller({required this.city, required this.mock});
  final String city;
  final bool mock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodAsync =
        ref.watch(foodListProvider((city: city, mock: mock)));
    final sceneryAsync =
        ref.watch(sceneryListProvider((city: city, mock: mock)));

    final food = foodAsync.whenOrNull(data: (r) => r.data) ?? [];
    final scenery = sceneryAsync.whenOrNull(data: (r) => r.data) ?? [];

    // 合并前若干项（美食 + 美景交替展示）
    final items = <_FeaturedItem>[];
    for (var i = 0; i < 3; i++) {
      if (i < food.length) {
        items.add(_FeaturedItem(
          name: food[i].name,
          image: food[i].image,
          desc: food[i].desc,
          rating: food[i].rating,
          type: 'food',
          onTap: () => context.push('/food-detail/${food[i].id}'),
        ));
      }
      if (i < scenery.length) {
        items.add(_FeaturedItem(
          name: scenery[i].name,
          image: scenery[i].image,
          desc: scenery[i].desc,
          rating: scenery[i].rating,
          type: 'scenery',
          onTap: () => context.push('/scenery-detail/${scenery[i].id}'),
        ));
      }
    }

    if (items.isEmpty) {
      return const SizedBox(
        height: 180,
        child: EmptyState(
          icon: Icons.travel_explore_outlined,
          text: '暂无精选内容',
          hint: '切换城市或开启服务端数据试试',
        ),
      );
    }

    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _FeaturedCard(item: items[i]),
      ),
    );
  }
}

class _FeaturedItem {
  const _FeaturedItem({
    required this.name,
    required this.image,
    required this.desc,
    required this.rating,
    required this.type,
    required this.onTap,
  });
  final String name;
  final String image;
  final String desc;
  final double rating;
  final String type;
  final VoidCallback onTap;
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});
  final _FeaturedItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.image.isNotEmpty;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                  child: hasImage
                      ? Image.network(
                          item.image,
                          height: 104,
                          width: 148,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                    ),
                    child: Text(
                      item.type == 'food' ? '美食' : '美景',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // 文案
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    item.desc.isNotEmpty ? item.desc : '值得一去的好地方',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text(item.rating > 0 ? item.rating.toString() : '',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        height: 104,
        width: 148,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradientWith(0.18),
        ),
        alignment: Alignment.center,
        child: Text(item.type == 'food' ? '🍜' : '🏞️',
            style: const TextStyle(fontSize: 32)),
      );
}

/// ============================================================
/// 智能推荐：小途按当前城市自动生成，富文本 + 标签 + 重新生成
/// ============================================================
class _SmartRecommend extends ConsumerStatefulWidget {
  const _SmartRecommend({required this.city});
  final CityInfo city;

  @override
  ConsumerState<_SmartRecommend> createState() => _SmartRecommendState();
}

class _SmartRecommendState extends ConsumerState<_SmartRecommend> {
  String? _result;
  bool _loading = false;
  final String _prompt =
      '请为我去{city}的旅行推荐 3 个必去景点和 3 种必吃美食，'
      '每项一句话说明理由，最后给一条出行小贴士。';

  @override
  void initState() {
    super.initState();
    // 进入即自动生成（未配置 AI Key 时返回演示内容）
    _generate();
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final reply = await AiService.ask(
        _prompt.replaceAll('{city}', widget.city.name),
      );
      if (mounted) setState(() => _result = reply);
    } catch (e) {
      if (mounted) setState(() => _result = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('小途 · 旅游顾问',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text('基于「${widget.city.name}」为你智能生成',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _generate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                  child: Row(
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      if (_loading) const SizedBox(width: 4),
                      const Icon(Icons.refresh, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      const Text('重生成',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 结果区
          if (_loading && _result == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else if (_result != null)
            _RichRecommend(text: _result!)
          else
            Text('正在生成专属推荐…',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 12),
          // 标签快捷入口
          Row(
            children: [
              _Chip('🏞️ 必去景点', () => context.push('/scenery')),
              const SizedBox(width: 8),
              _Chip('🍜 必吃美食', () => context.push('/food')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 标签（白色描边，点击跳转）
class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppRadius.round),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white)),
        ),
      );
}

/// 富文本渲染：识别标题行 / 列表项 / 正文
class _RichRecommend extends StatelessWidget {
  const _RichRecommend({required this.text});
  final String text;

  static final RegExp _headerRe =
      RegExp(r'(必去|必吃|景点|美食|推荐|贴士|建议|行程|tip|tips)', caseSensitive: false);
  static final RegExp _bulletRe = RegExp(r'^([-\u2022]|\d+[.、])');

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) _line(line),
      ],
    );
  }

  Widget _line(String line) {
    if (_headerRe.hasMatch(line) && line.length <= 24) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(line,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
    }
    if (_bulletRe.hasMatch(line)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ',
                style: TextStyle(fontSize: 13, color: Colors.white)),
            Expanded(
              child: Text(line.replaceFirst(_bulletRe, ''),
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.5)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(line,
          style: const TextStyle(
              fontSize: 13, color: Colors.white, height: 1.5)),
    );
  }
}

/// ============================================================
/// 分类入口：2x2 网格
/// ============================================================
class _CategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _CatItem(Icons.restaurant_outlined, '美食', AppColors.accent,
          () => context.push('/food')),
      _CatItem(Icons.landscape_outlined, '美景', AppColors.primary,
          () => context.push('/scenery')),
      _CatItem(Icons.camera_alt_outlined, '拍照识物', AppColors.success,
          () => context.push('/photo-recognition')),
      _CatItem(Icons.tour_outlined, '一日游', Colors.purple,
          () => context.push('/oneday')),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _CatCard(item: items[i]),
    );
  }
}

class _CatItem {
  const _CatItem(this.icon, this.title, this.color, this.onTap);
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.item});
  final _CatItem item;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 10),
              // 标题改为弹性宽度 + 省略号：2 列窄卡下防止横向溢出
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      );
}
