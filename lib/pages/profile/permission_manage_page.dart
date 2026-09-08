import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../services/health_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 权限管理页（Phase 6：用户授权集中管理）
///
/// 汇总展示本 App 用到的系统权限状态，并支持：
///  - 未授权 → 点击直接发起系统授权申请
///  - 永久拒绝 / 系统设置中关闭 → 引导跳转系统设置开启
///  - 相机 / 相册：image_picker 无状态查询 API，展示用途说明
///
/// 原则：遵循「最小必要」，仅列本 App 真实使用到的权限；
/// 拒绝任一权限不影响其它功能使用。
/// ============================================================
class PermissionManagePage extends StatefulWidget {
  const PermissionManagePage({super.key});

  @override
  State<PermissionManagePage> createState() => _PermissionManagePageState();
}

class _PermissionManagePageState extends State<PermissionManagePage> {
  /// 定位权限状态（null = 查询失败）
  LocationPermission? _location;
  /// 通知权限（null = 未请求/未知；Android 13 以下恒为 true）
  bool? _notifEnabled;
  /// 健康数据（步数）授权状态（null = 未知）
  bool? _healthGranted;
  /// 状态刷新中
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 重新查询全部权限状态（进入页面 / 每次操作后调用）
  Future<void> _refresh() async {
    setState(() => _loading = true);

    // ---- 定位（geolocator） ----
    LocationPermission? loc;
    try {
      loc = await Geolocator.checkPermission();
    } catch (_) {/* 查询失败保持 null */}

    // ---- 通知（flutter_local_notifications，需插件已初始化） ----
    bool? notif;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        notif = await android?.areNotificationsEnabled();
      } else if (Platform.isIOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final opt = await ios?.checkPermissions();
        notif = opt?.isEnabled ?? false;
      }
    } catch (_) {/* 插件未初始化等情况，显示「未知」 */}

    // ---- 健康步数（HealthKit / Health Connect） ----
    final health = await HealthService.hasPermission();

    if (!mounted) return;
    setState(() {
      _location = loc;
      _notifEnabled = notif;
      _healthGranted = health;
      _loading = false;
    });
  }

  // ==================== 各权限操作 ====================

  /// 申请定位权限；永久拒绝则引导去系统设置
  Future<void> _handleLocation() async {
    final cur = _location;
    if (cur == LocationPermission.denied) {
      final res = await Geolocator.requestPermission();
      if (res == LocationPermission.deniedForever) {
        _showSnack('定位权限已被永久拒绝，请前往系统设置开启');
        await Geolocator.openAppSettings();
      } else {
        _showSnack(res == LocationPermission.whileInUse ||
                res == LocationPermission.always
            ? '定位权限已开启'
            : '已拒绝定位权限');
      }
    } else if (cur == LocationPermission.deniedForever) {
      _showSnack('请前往系统设置开启定位权限');
      await Geolocator.openAppSettings();
    } else if (cur == LocationPermission.whileInUse ||
        cur == LocationPermission.always) {
      _showSnack('定位权限已开启，可在系统设置中管理');
      await Geolocator.openAppSettings();
    }
    await _refresh();
  }

  /// 申请通知权限；关闭状态跳系统设置
  Future<void> _handleNotification() async {
    if (_notifEnabled == false) {
      if (Platform.isAndroid) {
        // Android 13+：直接发起系统通知授权申请
        try {
          final android = FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          final ok = await android?.requestNotificationsPermission();
          _showSnack(ok == true ? '通知权限已开启' : '未开启通知权限，可稍后在系统设置中开启');
        } catch (_) {
          _showSnack('请前往系统设置开启通知权限');
          await Geolocator.openAppSettings();
        }
      } else {
        // iOS：通知授权需在 App 设置页管理
        _showSnack('请前往系统设置开启通知权限');
        await Geolocator.openAppSettings();
      }
    } else {
      _showSnack('通知权限已开启，可在系统设置中管理');
      await Geolocator.openAppSettings();
    }
    await _refresh();
  }

  /// 申请健康步数授权（需在用户手势中调用）
  Future<void> _handleHealth() async {
    final granted = await HealthService.requestAuthorization();
    _showSnack(granted ? '健康步数授权成功' : '未获得健康数据授权（可在系统设置中开启）');
    await _refresh();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '权限管理',
            subtitle: '查看与申请定位 / 通知 / 健康数据授权',
            actions: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _refresh,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------------- 权限清单 ----------------
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _PermissionRow(
                        icon: Icons.my_location,
                        title: '定位',
                        subtitle: '获取当前城市天气、海拔与 GPS 轨迹录制',
                        status: _locStatusText,
                        statusColor: _locStatusColor,
                        actionLabel: _locActionLabel,
                        onAction: _loading ? null : _handleLocation,
                      ),
                      const Divider(height: 1, indent: 56),
                      _PermissionRow(
                        icon: Icons.notifications_active_outlined,
                        title: '通知',
                        subtitle: '每日 08:00 推送当前城市天气提醒',
                        status: _notifStatusText,
                        statusColor: _notifStatusColor,
                        actionLabel: _notifActionLabel,
                        onAction: _loading ? null : _handleNotification,
                      ),
                      const Divider(height: 1, indent: 56),
                      _PermissionRow(
                        icon: Icons.directions_walk,
                        title: '健康数据（步数）',
                        subtitle: '读取系统步数用于「今日步数」展示',
                        status: _healthStatusText,
                        statusColor: _healthStatusColor,
                        actionLabel: _healthActionLabel,
                        onAction: _loading ? null : _handleHealth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 说明性权限 ----------------
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_camera_outlined,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          const Text('相机 / 相册',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '「拍照识物」使用相机或相册选择图片时，系统会弹出授权框，无需在此提前申请。\n'
                        '拒绝后仅拍照识物不可用，不影响其它功能。',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 说明 ----------------
                const Text(
                  '提示：\n'
                  '1. 本应用遵循「最小必要」原则，仅在对应功能使用时申请权限；\n'
                  '2. 拒绝某一权限不影响其它功能正常使用；\n'
                  '3. 已开启的权限可随时在系统设置中关闭（路径：系统设置 - 应用 - 微旅途 - 权限）。',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textHint, height: 1.7),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 状态文案与操作标签 ====================

  String get _locStatusText => switch (_location) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          '已授权',
        LocationPermission.denied => '未授权',
        LocationPermission.deniedForever => '已永久拒绝',
        LocationPermission.unableToDetermine => '未知',
        null => '未知',
      };

  Color get _locStatusColor => _location == LocationPermission.always ||
          _location == LocationPermission.whileInUse
      ? AppColors.success
      : AppColors.danger;

  String get _locActionLabel => _location == LocationPermission.denied
      ? '去授权'
      : (_location == LocationPermission.always ||
              _location == LocationPermission.whileInUse)
          ? '管理'
          : '去设置';

  String get _notifStatusText => switch (_notifEnabled) {
        true => '已开启',
        false => '未开启',
        null => '未知',
      };

  Color get _notifStatusColor =>
      _notifEnabled == true ? AppColors.success : AppColors.danger;

  String get _notifActionLabel =>
      _notifEnabled == true ? '管理' : '去开启';

  String get _healthStatusText => switch (_healthGranted) {
        true => '已授权',
        false => '未授权',
        null => '未知',
      };

  Color get _healthStatusColor =>
      _healthGranted == true ? AppColors.success : AppColors.danger;

  String get _healthActionLabel =>
      _healthGranted == true ? '已授权' : '去授权';
}

/// 权限行：图标 + 名称 + 说明 + 状态 + 操作按钮
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Text(status,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(actionLabel,
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
