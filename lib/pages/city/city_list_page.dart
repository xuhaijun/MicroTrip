import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_info.dart';
import '../../providers/app_providers.dart';
import '../../services/city_data.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 城市选择页（对应小程序 subpackages/city/pages/city-list）
/// 功能：搜索 / GPS 定位 / 热门城市 / 按省份分组 / 最近访问
/// 选择后 pop 返回 CityInfo，由调用方切换城市
/// ============================================================
class CityListPage extends ConsumerStatefulWidget {
  const CityListPage({super.key});

  @override
  ConsumerState<CityListPage> createState() => _CityListPageState();
}

class _CityListPageState extends ConsumerState<CityListPage> {
  String _keyword = '';
  bool _locating = false;

  /// GPS 定位并直接选中（触发 locateProvider，统一状态管理）
  Future<void> _locate() async {
    setState(() => _locating = true);
    ref.invalidate(locateProvider);
    final city = await ref.read(locateProvider.future);
    if (!mounted) return;
    setState(() => _locating = false);
    if (city != null && city.name.isNotEmpty) {
      context.pop(city);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('定位失败，请检查定位权限或手动选择城市')),
      );
    }
  }

  void _select(CityInfo city) => context.pop(city);

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentCitiesProvider);
    final current = ref.watch(cityProvider);
    final results = CityData.search(_keyword);
    final recentList = recents.valueOrNull ?? [];

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: '选择城市',
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              IconButton(
                tooltip: '定位当前城市',
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // ---------------- 搜索框 ----------------
                TextField(
                  onChanged: (v) => setState(() => _keyword = v.trim()),
                  decoration: InputDecoration(
                    hintText: '搜索城市名 / 省份',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.round),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---------------- 浏览模式 ----------------
                if (_keyword.isEmpty) ...[
                  // 定位
                  FadeSlideIn(
                    delay: 0,
                    child: AppCard(
                      onTap: _locating ? null : _locate,
                      child: Row(
                        children: [
                          _locating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.my_location,
                                  color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            _locating ? '正在定位…' : 'GPS 定位当前城市',
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.textPrimary),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textHint),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 最近访问（横向 chips）
                  if (recentList.isNotEmpty) ...[
                    const SectionTitle(title: '最近访问'),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      delay: 60,
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentList.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (_, i) => _chip(
                            recentList[i].name,
                            () => _select(recentList[i]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // 热门城市
                  const SectionTitle(title: '热门城市'),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                    delay: 120,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final m in CityData.hotCities)
                          _chip(m['name'] as String,
                              () => _select(CityData.toCity(m))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 按省份分组
                  for (var i = 0;
                      i < CityData.provinceCities.entries.length;
                      i++)
                    ..._provinceBlock(i),
                ]

                // ---------------- 搜索结果 ----------------
                else ...[
                  if (results.isEmpty)
                    const EmptyState(
                        icon: Icons.search_off, text: '未找到匹配的城市')
                  else
                    for (var i = 0; i < results.length; i++)
                      FadeSlideIn(
                        delay: i * 60,
                        child: _cityTile(results[i], current,
                            trailing: results[i].province.isEmpty
                                ? null
                                : results[i].province),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个省份分组区块（标题 + chips），返回需要插入的 widget 列表
  List<Widget> _provinceBlock(int i) {
    final entry = CityData.provinceCities.entries.elementAt(i);
    return [
      SectionTitle(title: entry.key),
      const SizedBox(height: AppSpacing.md),
      FadeSlideIn(
        delay: 180 + i * 40,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final name in entry.value)
              _chip(name,
                  () => _select(CityInfo(name: name, province: entry.key))),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.round),
            boxShadow: AppShadows.card,
          ),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ),
      );

  Widget _cityTile(CityInfo city, CityInfo current, {String? trailing}) =>
      ListTile(
        title: Text(city.name),
        subtitle: trailing != null ? Text(trailing) : null,
        trailing: city.name == current.name
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
        onTap: () => _select(city),
      );
}
