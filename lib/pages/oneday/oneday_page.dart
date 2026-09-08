import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../models/oneday_plan.dart';
import '../../providers/app_providers.dart';
import '../../services/oneday_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 一日游攻略页（迁移自小程序 subpackages/travel/pages/oneday/oneday.js）
/// - 城市 / 主题输入 + 一键生成（mock 或 AI 自动降级）
/// - 富文本卡片分段展示：景点 / 美食 / 路线，可重生成
/// - 顶部分享按钮：一键复制当日行程文案
/// ============================================================
class OneDayPage extends ConsumerStatefulWidget {
  const OneDayPage({super.key});

  @override
  ConsumerState<OneDayPage> createState() => _OneDayPageState();
}

class _OneDayPageState extends ConsumerState<OneDayPage> {
  /// AI 优化结果文案（null = 尚未生成）
  String? _aiResult;

  /// AI 请求进行中标记（按钮转圈 + 防重复点击）
  bool _aiLoading = false;

  late final TextEditingController _cityCtrl;
  late final TextEditingController _themeCtrl;

  @override
  void initState() {
    super.initState();
    _cityCtrl =
        TextEditingController(text: ref.read(cityProvider).name);
    _themeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _themeCtrl.dispose();
    super.dispose();
  }

  /// 当前生效的城市名（输入框为空时回退到当前城市）
  String get _activeCity {
    final t = _cityCtrl.text.trim();
    return t.isEmpty ? ref.read(cityProvider).name : t;
  }

  @override
  Widget build(BuildContext context) {
    final timeline = OneDayService.buildTimeline(_activeCity);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: '一日游攻略',
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              IconButton(
                tooltip: '分享行程',
                onPressed: () => _sharePlan(_activeCity, timeline),
                icon: Icon(Icons.ios_share, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
              children: [
                // ---------------- AI 优化说明 ----------------
                FadeSlideIn(
                  delay: 0,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: AppColors.accent, size: 22),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('小途 · AI 行程优化',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              SizedBox(height: 2),
                              Text('结合天气与城市特色，一键生成适合今天的个性化安排',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---------------- 输入区 ----------------
                FadeSlideIn(
                  delay: 60,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _cityCtrl,
                          decoration: InputDecoration(
                            labelText: '城市',
                            hintText: '想去的城市',
                            prefixIcon: const Icon(Icons.location_city,
                                color: AppColors.textHint),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _themeCtrl,
                          decoration: InputDecoration(
                            labelText: '主题偏好',
                            hintText: '亲子 / 美食 / 拍照 / 文艺…',
                            prefixIcon: const Icon(Icons.local_offer,
                                color: AppColors.textHint),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GradientButton(
                          label: _aiLoading ? '生成中…' : '生成一日游攻略',
                          onPressed: _generate,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ---------------- 行程安排 ----------------
                const SectionTitle(title: '行程安排'),
                const SizedBox(height: 4),
                for (var i = 0; i < timeline.length; i++)
                  FadeSlideIn(
                    delay: 120 + i * 60,
                    child: _buildTimelineRow(timeline[i],
                        isLast: i == timeline.length - 1),
                  ),

                // ---------------- AI 优化建议 ----------------
                if (_aiResult != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(
                    delay: 120 + timeline.length * 60,
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🤖',
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(width: AppSpacing.sm),
                              const Expanded(
                                child: Text('AI 优化建议',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                              ),
                              TextButton(
                                onPressed: _generate,
                                child: const Text('重新生成',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _aiResult!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ---------------- 推荐路线 ----------------
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: 180 + timeline.length * 60,
                  child: _buildRouteCard(timeline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 调用 AI 优化行程（未配置 Key 时服务层自动降级 mock 文案）
  Future<void> _generate() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    final city = _activeCity;
    final theme = _themeCtrl.text.trim();
    final prompt = theme.isNotEmpty ? '$city（偏好：$theme）' : city;
    final result = await OneDayService.optimize(prompt);
    if (!mounted) return;
    setState(() {
      _aiResult = result;
      _aiLoading = false;
    });
  }

  // ==================== 时间轴 ====================

  /// 构建单段行程行（左侧时间 + 竖线 + 圆点 + 右侧卡片）
  Widget _buildTimelineRow(OneDayPlanItem item, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧：时间 + 竖线 + 圆点
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: AppColors.divider),
                ),
              ],
            ),
          ),
          // 时间轴圆点（骑在竖线上）
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFFFFC078)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: AppShadows.card,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：行程卡片
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _TimelineCard(item: item),
            ),
          ),
        ],
      ),
    );
  }

  /// 推荐路线汇总卡
  Widget _buildRouteCard(List<OneDayPlanItem> timeline) {
    final route = timeline.map((e) => '${e.time} ${e.title}').join(' → ');
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: AppColors.primary, size: 18),
              SizedBox(width: AppSpacing.sm),
              Text('推荐路线',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            route,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 分享 ====================

  /// 复制行程文案到剪贴板（对应小程序 onShareAppMessage 能力）
  Future<void> _sharePlan(String city, List<OneDayPlanItem> timeline) async {
    final sb = StringBuffer('🏙 $city一日游攻略\n');
    for (final item in timeline) {
      sb.writeln('${item.time} ${item.icon} ${item.title}：${item.desc}');
    }
    if (_aiResult != null) sb.writeln('\n🤖 AI 优化建议：\n$_aiResult');
    sb.writeln('\n—— 来自「微旅途」');
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('行程文案已复制，去粘贴给好友吧～')),
    );
  }
}

/// 单段行程卡片：时段徽章 + 分类标签 + emoji 图标 + 标题 + 描述
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.item});

  final OneDayPlanItem item;

  @override
  Widget build(BuildContext context) {
    // 由 emoji 推断分类：餐饮类归「美食」，其余归「景点」
    final isFood = item.icon == '🍜' || item.icon == '🍢';
    final category = isFood ? '美食' : '景点';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // emoji 图标
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientWith(0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(item.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 时段徽章
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.round),
                      ),
                      child: Text(
                        item.period,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 分类标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.round),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
