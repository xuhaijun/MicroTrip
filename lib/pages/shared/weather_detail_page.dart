import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/weather_icons.dart';
import '../../models/weather.dart';
import '../../providers/app_providers.dart';
import '../../services/weather_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 天气详情页（对应小程序 subpackages/tools/pages/weather）
/// 实时详情 + 10 天预报 + 逐小时趋势 + 出行建议
/// ============================================================
class WeatherDetailPage extends ConsumerStatefulWidget {
  const WeatherDetailPage({super.key});

  @override
  ConsumerState<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends ConsumerState<WeatherDetailPage> {
  List<WeatherHourly> _hourly = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final city = ref.read(cityProvider);
    await ref.read(weatherProvider(city).notifier).load(city, force: force);
    _hourly = await WeatherService.getHourly(city);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(cityProvider);
    final weather = ref.watch(weatherProvider(city));
    final advice = ref.watch(weatherAdviceProvider);
    final now = weather.now;
    final date = DateTime.now();
    final dateLabel =
        '${date.year}年${date.month}月${date.day}日 ${_weekdayOf(date)}';

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: city.name,
            subtitle: dateLabel,
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // ---------------- 实时大卡 ----------------
                  FadeSlideIn(
                    delay: 0,
                    child: GradientCard(
                      child: Column(
                        children: [
                          // 天气图标：weatherIconOf 按和风 v7 代码统一定位到 Material 图标
                          if (now != null)
                            Icon(weatherIconOf(now.icon),
                                size: 56, color: Colors.white),
                          if (now != null) const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(now?.temp ?? '--',
                                  style: const TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.1)),
                              const Text('℃',
                                  style: TextStyle(
                                      fontSize: 20, color: Colors.white70)),
                            ],
                          ),
                          Text(
                            now != null
                                ? '${now.text} · 体感 ${now.feelsLike}℃'
                                : '加载中…',
                            style: const TextStyle(
                                fontSize: 15, color: Colors.white),
                          ),
                          if (now != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '湿度 ${now.humidity}% · ${now.windDir}${now.windScale}级 · 气压 ${now.pressure}hPa',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---------------- 逐小时 ----------------
                  if (_hourly.isNotEmpty) ...[
                    FadeSlideIn(
                      delay: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '未来 24 小时'),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: SizedBox(
                              // 逐小时项为竖向 Column，含 emoji 图标（字号 22，实际行高偏高），
                              // 96 在窄屏/真机字号下会被撑出 ~14px 溢出；抬到 120 留足余量。
                              // 见 overflow_scan_test：weather_detail_page.dart:150 Column overflow 14px
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _hourly.length.clamp(0, 24),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: AppSpacing.lg),
                                itemBuilder: (_, i) {
                                  final h = _hourly[i];
                                  final t = DateTime.tryParse(h.fxTime);
                                  final label = i == 0
                                      ? '现在'
                                      : '${t?.hour.toString().padLeft(2, '0')}时';
                                  return SizedBox(
                                    width: 48,
                                    child: Column(
                                      // mainAxisSize.min：仅取内容高度，配合外层 120 高度居中，
                                      // 彻底杜绝「内容略高于固定高度」导致的底部溢出。
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(label,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textHint)),
                                        const SizedBox(height: 8),
                                        // 天气图标：与实时卡/10 天预报同一映射源
                                        Icon(weatherIconOf(h.icon),
                                            size: 22,
                                            color: AppColors.primary),
                                        const SizedBox(height: 8),
                                        Text('${h.temp}°',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ---------------- 10 天预报（横向卡片） ----------------
                  FadeSlideIn(
                    delay: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: '10 天预报'),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: weather.daily.take(10).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (_, i) =>
                                _dayCard(weather.daily[i], i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---------------- 出行建议（chips） ----------------
                  if (advice.isNotEmpty)
                    FadeSlideIn(
                      delay: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '出行建议'),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final a in advice) _adviceChip(a),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 10 天预报横向卡片
  Widget _dayCard(WeatherDaily d, int index) {
    final date = DateTime.tryParse(d.fxDate);
    final now = DateTime.now();
    final label = date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day
        ? '今天'
        : '${date?.month ?? ''}/${date?.day ?? ''} ${date != null ? _weekdayOf(date) : ''}';
    return SizedBox(
      width: 88,
      child: AppCard(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpacing.sm),
        // AppCard 内层 Container 无 alignment，子内容会落在卡片左侧；
        // 用 Align 把整列在 88 宽卡片内水平+垂直居中，避免"内容偏左未居中"。
        child: Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Icon(weatherIconOf(d.iconDay),
                  size: 26, color: AppColors.primary),
              const SizedBox(height: 8),
              Text('${d.tempMax}°',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text('${d.tempMin}°',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 6),
              Text(d.textDay,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  /// 出行建议标签
  Widget _adviceChip(WeatherAdvice a) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.round),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(adviceIconOf(a.icon),
                size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(a.text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      );

  String _weekdayOf(DateTime d) {
    const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return wd[d.weekday - 1];
  }
}
