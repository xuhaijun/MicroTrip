import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_info.dart';
import '../../models/weather.dart';
import '../../providers/app_providers.dart';
import '../../services/holiday_data.dart';
import '../../services/lunar_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 首页（对应小程序 pages/index）
/// 现代重设计：统一渐变头部（城市 + 日期/农历 + 紧凑天气，天气提醒条已移出卡外独立横滑）+
/// 今日概览（海拔 / 步数，点击跳详情）→ 附近探索 → 快捷功能（两行四列，含海拔信息）→ 小途助手 → 每日提示 → 节假倒计时
/// ============================================================
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Tab 切换保活

  // 海拔 / 步数属于「次要数据」，延后到首帧之后加载，
  // 避免 Geolocator 定位与 Health Connect 授权在启动关键路径上阻塞或弹窗。
  // 二者各自独立加载，数据就绪后卡片点击分别跳转对应详情页（/altitude-detail、/step-detail）。
  double? _altitude;
  bool _altitudeLoading = true;
  int? _steps;
  bool _secondaryLoaded = false;

  /// 刷新中标记：点击右上角刷新/下拉刷新时置 true，按钮显示转圈并禁用，
  /// 给明确的「点击已接收」反馈——否则天气/步数刷新后若数值不变，界面毫无反应，
  /// 用户会误以为按钮失灵。
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    // 首帧后自动拉取天气（避免 build 中触发副作用）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final city = ref.read(cityProvider);
      ref.read(weatherProvider(city).notifier).load(city);
      // 次要数据同样延后：启动时不会触发 GPS 定位和步数授权弹窗
      _setupSecondaryListeners(); // 先注册监听（含已有缓存值兜底），再触发加载
      _loadSecondary();
    });
  }

  /// 延后加载：首帧之后并行拉取海拔（定位一次）与今日步数（健康数据源），
  /// 二者均较重且可能涉及系统授权，放到首帧之后执行以保障启动速度。
  void _loadSecondary() {
    if (_secondaryLoaded) return;
    _secondaryLoaded = true;
    _loadAltitude();
    _loadSteps();
  }

  /// 一次性注册海拔/步数 provider 的状态监听。
  /// AsyncValue 没有公开的 future getter（AsyncNotifier.future 又受 @visibleForTesting 保护），
  /// 因此改为「监听状态变化」获取结果：provider 计算完成或刷新时自动更新本地字段。
  /// fireImmediately: 注册时立即以当前状态回调一次，覆盖「provider 已有缓存值」场景。
  void _setupSecondaryListeners() {
    ref.listenManual(altitudeProvider, (prev, next) {
      if (!mounted) return;
      _altitude = next.valueOrNull;
      _altitudeLoading = next.isLoading;
      setState(() {});
    }, fireImmediately: true);
    ref.listenManual(stepProvider, (prev, next) {
      if (!mounted) return;
      _steps = next.valueOrNull?.steps;
      setState(() {});
    }, fireImmediately: true);
  }

  /// 触发当前海拔加载（GPS 定位一次）：read 启动 provider 计算，
  /// 结果经 [_setupSecondaryListeners] 注册的监听回调写入 [_altitude]。
  void _loadAltitude() {
    ref.read(altitudeProvider);
  }

  /// 触发今日步数加载（Health Connect 等健康数据源）：同上，结果写入 [_steps]。
  void _loadSteps() {
    ref.read(stepProvider);
  }

  Future<void> _reload() async {
    if (_reloading || !mounted) return;
    setState(() => _reloading = true);
    final city = ref.read(cityProvider);
    try {
      // 天气：强制跳过缓存重新拉取（force:true 会先清缓存再请求）
      await ref.read(weatherProvider(city).notifier).load(city, force: true);
      // 次要数据：用各自 notifier 的 refresh() 强制重拉（海拔走全新 GPS、步数重读健康源），
      // 结果经 initState 注册的 listenManual 回调写回本地 _altitude / _steps。
      ref.read(altitudeProvider.notifier).refresh();
      ref.read(stepProvider.notifier).refresh();
      _secondaryLoaded = true; // 标记已加载，首帧门控不再重复触发
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final city = ref.watch(cityProvider);
    final weather = ref.watch(weatherProvider(city));
    final advice = ref.watch(weatherAdviceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---------------- 统一渐变头部（城市 + 日期/农历 + 紧凑天气） ----------------
            GradientHeader(
              title: city.displayName,
              onTitleTap: () async {
                final result = await context.push<CityInfo>('/city-list');
                if (result != null) {
                  await ref.read(cityProvider.notifier).switchCity(result);
                  _reload();
                }
              },
              subtitle: _dateSubtitle(),
              actions: [
                IconButton(
                  // 刷新中：显示转圈 + 禁用，给出明确的点击反馈
                  icon: _reloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: _reloading ? null : _reload,
                  tooltip: '刷新',
                ),
              ],
              // 头部内容区：仅紧凑天气。天气提醒条已移出天气卡，作为独立横滑条置于卡外（见下方 _buildAdviceBanner）。
              child: _headerWeather(weather: weather),
            ),

            // 头部下缘内容（与渐变头部自然衔接：统一四 Tab 页布局，消除错位）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                  children: [
                    // ---------------- 天气提醒条（已移出天气卡，独立横滑条） ----------------
                    if (advice.isNotEmpty) ...[
                      FadeSlideIn(child: _buildAdviceBanner(advice)),
                      const SizedBox(height: 12),
                    ],
                    // ---------------- 今日概览：海拔 + 步数 ----------------
                    FadeSlideIn(child: _buildOverviewBar()),
                    const SizedBox(height: 12),
                    // ---------------- 附近探索（紧随步数卡片下方） ----------------
                    FadeSlideIn(delay: 80, child: _buildNearbyBanner(context)),
                    const SizedBox(height: 12),
                    // ---------------- 快捷入口（两行四列） ----------------
                    FadeSlideIn(delay: 140, child: _buildQuickEntries(context)),
                    const SizedBox(height: 12),
                    // ---------------- 小途助手 ----------------
                    FadeSlideIn(delay: 200, child: _buildAiCard(context, city)),
                    const SizedBox(height: 12),
                    // ---------------- 每日提示 ----------------
                    FadeSlideIn(delay: 230, child: _buildDailyTip()),
                    const SizedBox(height: 12),
                    // ---------------- 节假倒计时 ----------------
                    FadeSlideIn(delay: 260, child: _buildHolidayCard()),
                    const SizedBox(height: 24),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部副标题：M月D日 周X · 农历（初几/节气）
  String _dateSubtitle() {
    final now = DateTime.now();
    const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final lunar = LunarService.getLunarDayLabel(now);
    return '${now.month}月${now.day}日 ${wd[now.weekday % 7]} · 农历$lunar';
  }

  /// 头部紧凑天气（点击查看天气详情）
  Widget _headerWeather({required WeatherViewState weather}) {
    final now = weather.now;
    return GestureDetector(
      onTap: () => context.push('/weather-detail'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      now?.temp ?? '--',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1),
                    ),
                    const Text('℃',
                        style: TextStyle(
                            fontSize: 16, color: Colors.white70)),
                    const SizedBox(width: 8),
                    if (now != null)
                      // 与天气详情页共用 WeatherUtils.iconOf（按和风 v7 代码映射），
                      // 避免两套 emoji 映射导致首页与详情页图标不一致
                      Text(WeatherUtils.iconOf(now.icon),
                          style: const TextStyle(fontSize: 26)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  now != null ? '${now.text} · 体感 ${now.feelsLike}℃' : '天气加载中…',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                if (now != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 均分剩余宽度 + 省略号，杜绝窄屏横向 RenderFlex 溢出
                      Expanded(child: _weatherMeta('💧 ${now.humidity}%')),
                      const SizedBox(width: 10),
                      Expanded(child: _weatherMeta('🌬️ ${now.windDir} ${now.windScale}级')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 今明温度速览
          if (weather.daily.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('今日 ${weather.daily.first.tempMin}~${weather.daily.first.tempMax}℃',
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                  if (weather.daily.length > 1) ...[
                    const SizedBox(height: 2),
                    Text('明日 ${weather.daily[1].tempMin}~${weather.daily[1].tempMax}℃',
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _weatherMeta(String text) => Text(text,
      style: const TextStyle(fontSize: 11, color: Colors.white70),
      overflow: TextOverflow.ellipsis,
      softWrap: false);

  /// 今日概览：海拔 + 步数（两列卡片，点击分别跳转海拔/步数详情页）
  /// 海拔/步数来自延后加载的本地状态（_altitude / _steps），
  /// 不再在 build 中 watch 对应 FutureProvider，避免启动即触发定位与健康授权。
  Widget _buildOverviewBar() {
    final altitude = _altitude;
    final steps = _steps;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: PressableScale(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/altitude-detail'),
                child: _OverviewItem(
                  icon: Icons.terrain_outlined,
                  label: '当前海拔',
                  // 三态：定位中（loading）→ 暂不可用（超时/未授权）→ 数值
                  value: _altitudeLoading
                      ? '定位中…'
                      : altitude == null
                          ? '暂不可用'
                          : '${altitude.round()} m',
                ),
              ),
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: PressableScale(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/step-detail'),
                child: _OverviewItem(
                  icon: Icons.directions_walk_outlined,
                  label: '今日步数',
                  value: steps == null ? '—' : '$steps 步',
                  valueColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 天气提醒条（已移出天气卡，作为独立横滑条置于卡外）
  /// 浅色芯片 + 主色文字，在页面背景上比卡内白字更清爽、不臃肿。
  Widget _buildAdviceBanner(List<WeatherAdvice> advice) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: advice.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.round),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(advice[i].icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                advice[i].text,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 每日提示卡（离线可用，按日轮换）
  Widget _buildDailyTip() {
    final tip = ref.watch(dailyTipProvider);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lightbulb_outline,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('每日提示',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(tip,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 节假倒计时卡（距离最近假期还有 N 天）
  Widget _buildHolidayCard() {
    final upcoming = HolidayData.getUpcomingHolidays(1);
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;
    final days = next.daysFromNow;
    final sub = days == 0 ? '就是今天，安排起来！' : '还有 $days 天';

    return GestureDetector(
      // 携带节日日期跳转：万年历页直接定位到该节日对应日期
      onTap: () => context.push('/calendar', extra: next.date),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradientWith(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.event_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('距离 ${next.name}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Text('${next.date.substring(5)}\n${next.name}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  /// 附近探索：首页醒目卡片入口（从 3x3 宫格提升为横幅，强调地图能力）
  Widget _buildNearbyBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/nearby'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.explore, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('附近探索',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(height: 3),
                  Text('发现周边的景点、美食与酒店',
                      style:
                          TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: const Text('去探索',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  /// 快捷入口宫格（两行四列满 8 项：美食/美景/录制轨迹/拍照识物/一日游/万年历/备忘提醒/海拔信息）
  Widget _buildQuickEntries(BuildContext context) {
    final entries = [
      (Icons.restaurant_outlined, '美食', () => context.push('/food')),
      (Icons.landscape_outlined, '美景', () => context.push('/scenery')),
      (Icons.fiber_manual_record, '录制轨迹', () => context.push('/trajectory-record')),
      (Icons.camera_alt_outlined, '拍照识物', () => context.push('/photo-recognition')),
      (Icons.explore_outlined, '一日游', () => context.push('/oneday')),
      (Icons.calendar_month_outlined, '万年历', () => context.push('/calendar')),
      (Icons.edit_note_outlined, '备忘提醒', () => context.push('/trip/memo')),
      (Icons.terrain_outlined, '海拔信息', () => context.push('/altitude-detail')),
    ];
    return AppCard(
      // 底部留 14 呼吸空间：宫格内容与卡片下边缘不再紧贴
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片标题
          const Text('快捷功能',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          // 标题与宫格间距：原 12 过大 → 6，让标题紧贴功能区
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              // 功能项间距调大：行距 10→14，列距 4→8，格子更疏朗
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              // 列距变大后每列略窄，aspectRatio 0.9→0.87 让格子更高，
              // 抵消宽度收缩，保证 48px 图标 + 文字不溢出
              childAspectRatio: 0.87,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return FadeSlideIn(
                delay: 360 + i * 40,
                child: PressableScale(
                  child: GestureDetector(
                    onTap: e.$3,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(e.$1, size: 24, color: AppColors.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(e.$2,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 小途 AI 助手卡片（对应「微旅途 旅行助手」）
  Widget _buildAiCard(BuildContext context, CityInfo city) {
    return GradientCard(
      onTap: () => context.push('/ai-chat'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🤖', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('微旅途 · 旅行助手',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('问问小途：${city.name}有什么好玩的？',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
        ],
      ),
    );
  }

}

/// 今日概览单项
class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            )),
      ],
    );
  }
}
