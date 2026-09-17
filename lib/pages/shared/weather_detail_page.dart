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

  /// 右上角刷新按钮入口：强制重拉并给出明确反馈。
  /// 原「无反应」根因：按钮 fire-and-forget 调 _load，既无 loading 态也无 Toast，
  /// 且天气数值秒级不变（API 失败还会静默降级 Mock），用户感知像死按钮。
  Future<void> _refreshWithFeedback() async {
    final city = ref.read(cityProvider);
    await ref.read(weatherProvider(city).notifier).load(city, force: true);
    _hourly = await WeatherService.getHourly(city);
    if (!mounted) return;
    setState(() {});
    final w = ref.read(weatherProvider(city));
    final msg = w.error != null
        ? '刷新失败，请检查网络'
        : (w.now?.isMock == true ? '已刷新（离线数据）' : '已刷新');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
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
                // 加载中禁用并显示转圈，给出明确点击反馈（修复「点了没反应」）
                onPressed: weather.loading ? null : _refreshWithFeedback,
                icon: weather.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
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
                            // 内边距只留上下 8（默认 16）：条目在轨道里垂直居中，
                            // 收掉内边距即少上下各 8 的空白（2026-09-14）。
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.md),
                            child: SizedBox(
                              // 逐小时项为竖向 Column：文字 12/16 + 图标 22 + 两处 8 间距，
                              // 显式给每个 TextStyle 设 height:1.2 后内容实测 14.4+8+22+8+19.2 = 71.6 高。
                              // 轨道 90：既留住呼吸感，又容得下系统大字体。
                              // 原值 120 是「怕溢出」的过度保守值，会留出约 40 的上下空白。
                              //
                              // ⚠️ 不准把 90 再往下压：温度行「21°」按 fontSize 16 排版，
                              // 在字宽偏大的字体下会超过 48 的槽宽**折成两行**（实测 46 高），
                              // 整列变成 101 → 溢出 11px（2026-09-14 由 120 收到 90 时暴露）。
                              // 现已用 maxLines/softWrap + FittedBox 双保险堵住折行，
                              // 但改动高度前请先跑 test/weather_hourly_fit_test.dart。
                              height: 90,
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
                                    // FittedBox 仅作兜底：极端字体缩放时等比缩小，
                                    // 避免固定高度轨道溢出（与 10 天预报 _dayCard 同一策略）；
                                    // 正常缩放下 scale=1，原样显示，不影响观感。
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        // mainAxisSize.min：仅取内容高度，配合轨道高度居中
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(label,
                                              // 折行会把整列顶高、撑爆固定轨道；高度还必须显式写死，
                                              // 否则中文默认行高约 1.42 会让估算失真。
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.2,
                                                  color: AppColors.textHint)),
                                          const SizedBox(height: 8),
                                          // 天气图标：与实时卡/10 天预报同一映射源
                                          Icon(weatherIconOf(h.icon),
                                              size: 22,
                                              color: AppColors.primary),
                                          const SizedBox(height: 8),
                                          Text('${h.temp}°',
                                              // 「21°」在 48 宽的槽里只差 1px，必须禁止折行
                                              maxLines: 1,
                                              softWrap: false,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  height: 1.2,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary)),
                                        ],
                                      ),
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
                          // 180 → 132：卡片内边距收到 8 后内容实测约 103 高，
                          // 轨道跟着收紧，上下空白从约 36 压到约 15（2026-09-14）。
                          height: 132,
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
        // 上下内边距 12 → 8：卡片内容本来就在轨道里居中，收掉内边距即少上下各 4 的空白
        padding:
            const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 6),
        // AppCard 内层 Container 无 alignment，子内容会落在卡片左侧；
        // 用 Align 把整列在 88 宽卡片内水平+垂直居中，避免"内容偏左未居中"。
        child: Align(
          alignment: Alignment.center,
          // FittedBox 仅作兜底：系统字体放大到极端值时等比缩小，避免固定高度轨道溢出；
          // 正常缩放下 scale=1，原样显示，不影响观感。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Icon(weatherIconOf(d.iconDay),
                  size: 26, color: AppColors.primary),
              const SizedBox(height: 6),
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
              const SizedBox(height: 5),
              Text(d.textDay,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
            ),
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
