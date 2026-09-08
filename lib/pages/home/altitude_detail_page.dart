import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 海拔信息详情页（首页「当前海拔」卡片 / 快捷入口「海拔信息」点击进入）
/// 展示当前 GPS 海拔，并说明数据来源与精度，支持下拉刷新重新定位。
/// ============================================================
class AltitudeDetailPage extends ConsumerStatefulWidget {
  const AltitudeDetailPage({super.key});

  @override
  ConsumerState<AltitudeDetailPage> createState() => _AltitudeDetailPageState();
}

class _AltitudeDetailPageState extends ConsumerState<AltitudeDetailPage> {
  /// 强制刷新：忽略系统缓存，重新 GPS 定位取最新海拔。
  /// （不能只 invalidate —— 原 provider 优先读 getLastKnownPosition，
  ///  每次拿到的都是旧缓存位置，表现为「点刷新无反应」。）
  Future<void> _refresh() => ref.read(altitudeProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final altitudeAsync = ref.watch(altitudeProvider);
    final date = DateTime.now();
    final dateLabel =
        '${date.year}年${date.month}月${date.day}日 ${_weekdayOf(date)}';

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: '海拔信息',
            subtitle: dateLabel,
            actions: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              IconButton(
                tooltip: '重新定位',
                onPressed: altitudeAsync.isLoading ? null : _refresh,
                icon: altitudeAsync.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // ---------------- 当前海拔大卡 ----------------
                  FadeSlideIn(
                    child: GradientCard(
                      child: altitudeAsync.when(
                        loading: () => _bigCard('--', '定位中…'),
                        error: (_, _) => _bigCard('--', '定位失败，请检查权限'),
                        data: (alt) => alt == null
                            ? _bigCard('--', '未授权定位权限')
                            : _bigCard('${alt.round()}', '当前海拔（米）'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // ---------------- 说明 ----------------
                  FadeSlideIn(
                    delay: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(title: '关于海拔数据'),
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('· 数据来自设备 GPS 定位，为大地高（椭球高）。',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.5)),
                              SizedBox(height: 6),
                              Text('· GPS 海拔精度通常弱于水平定位，山区 / 高楼间可能有数十米偏差。',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.5)),
                              SizedBox(height: 6),
                              Text('· 点击右上角刷新可重新获取当前位置海拔。',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.5)),
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

  /// 大数值卡片内部：数值 + 标签（标签置于数值下方，避免窄屏横向溢出）
  Widget _bigCard(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 15, color: Colors.white70)),
        ],
      );

  String _weekdayOf(DateTime d) {
    const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return wd[d.weekday - 1];
  }
}
