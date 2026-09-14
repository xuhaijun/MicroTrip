import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/config/data_config.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/weather_push_service.dart';
import '../shared/widgets/common_widgets.dart';

/// 卡片内列表分隔线：左端对齐行标题文字、右端内缩 12，两端都不顶到卡片边。
///
/// `indent: 40` 来自**实测 + 源码双重核对**：本页所有行都是
/// `ListTile(contentPadding: EdgeInsets.zero)`，其标题起点为
/// `max(minLeadingWidth, leading 宽) + horizontalTitleGap`。
/// Material 3 下 `minLeadingWidth = 24`（**不是 M2 的 40**）、
/// `horizontalTitleGap = 16`，leading 图标 20 < 24 → 标题起点 = 24 + 16 = **40**，
/// 与 `getRect` 实测的「标题文字左 − 行左 = 40」完全一致。
/// endIndent 12 与「我的」页 / 关于页 / 权限页统一（全 App 同一观感）。
/// 相关回归用例：`test/settings_divider_align_test.dart`。
const Divider _kListDivider = Divider(height: 1, indent: 40, endIndent: 12);

/// ============================================================
/// 设置页（对应小程序 subpackages/tools/pages/settings）
/// 支持 App 内覆盖 天气 / AI 接口配置（持久化到 prefs，
/// 优先级高于内置默认值），并提供「恢复默认」。
/// Phase 4：新增「后端服务地址」配置（登录接口切换本地/云端）。
/// 数据演示：新增「模拟数据总开关」（美食/美景等从服务端 or 本地示例）。
/// 注：天气 / AI 配置区块当前「暂时隐藏」（_showWeatherAiConfig=false），
/// 代码与存储逻辑保留，日后改回 true 即可恢复展示。
/// ============================================================
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// 调试开关：天气服务 / 智能助手配置区块是否展示。
  /// 当前暂时隐藏（false），代码与存储逻辑保留，日后改回 true 即可恢复。
  static const bool _showWeatherAiConfig = false;

  late final TextEditingController _weatherHost;
  late final TextEditingController _weatherKey;
  late final TextEditingController _aiUrl;
  late final TextEditingController _aiKey;
  late final TextEditingController _aiModel;
  late final TextEditingController _authServer;
  late bool _weatherNotif; // 天气提醒开关（userSettings.weatherNotif）

  /// 后端连通性自检状态（设置页「测试连接」按钮）
  bool _pinging = false;
  ServerPingResult? _pingResult;

  @override
  void initState() {
    super.initState();
    final wc = AppStorage.getObject(AppStorage.kWeatherConfig);
    final ac = AppStorage.getObject(AppStorage.kAiConfig);
    _weatherHost = TextEditingController(
        text: (wc is Map ? wc['apiHost'] : null) ?? AppConfig.weatherApiHost);
    _weatherKey = TextEditingController(
        text: (wc is Map ? wc['apiKey'] : null) ?? AppConfig.weatherApiKey);
    _aiUrl = TextEditingController(
        text: (ac is Map ? ac['apiUrl'] : null) ?? AppConfig.aiApiUrl);
    _aiKey = TextEditingController(
        text: (ac is Map ? ac['apiKey'] : null) ?? AppConfig.aiApiKey);
    _aiModel = TextEditingController(
        text: (ac is Map ? ac['model'] : null) ?? AppConfig.aiModel);
    _authServer = TextEditingController(text: AuthService.serverUrl);
    _weatherNotif = WeatherPushService.isEnabled;
  }

  @override
  void dispose() {
    _weatherHost.dispose();
    _weatherKey.dispose();
    _aiUrl.dispose();
    _aiKey.dispose();
    _aiModel.dispose();
    _authServer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 天气 / AI 配置虽暂时隐藏，仍一并保存，保证开关恢复后配置不丢失
    await AppStorage.setObject(AppStorage.kWeatherConfig, {
      'apiHost': _weatherHost.text.trim(),
      'apiKey': _weatherKey.text.trim(),
    });
    await AppStorage.setObject(AppStorage.kAiConfig, {
      'apiUrl': _aiUrl.text.trim(),
      'apiKey': _aiKey.text.trim(),
      'model': _aiModel.text.trim(),
    });
    await AuthService.setServerUrl(_authServer.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存（天气缓存将在下次刷新时生效）')));
    }
  }

  /// 测试后端连接：调用 [AuthService.ping] 探活 {地址}/api/v1/health，
  /// 把地址填错 / 证书不受信 / 超时等问题在配置阶段就暴露，而非等到同步轨迹才报错。
  Future<void> _testConnection() async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      _pingResult = null;
    });
    final result = await AuthService.ping(url: _authServer.text.trim());
    if (mounted) {
      setState(() {
        _pinging = false;
        _pingResult = result;
      });
      _showSnack(result.message);
    }
  }

  /// 同步状态描述（设置页实时展示）
  String get _syncStatusText {
    if (AuthService.serverUrl.isEmpty) {
      return '未配置后端地址，无法同步';
    }
    if (!AuthService.isLoggedIn) {
      return '登录后可将本地轨迹备份到云端';
    }
    return '上次同步：${SyncService.lastSyncAtText}';
  }

  /// 手动同步：进度对话框逐条上传，完成后汇总结果
  Future<void> _syncNow() async {
    if (!AuthService.isLoggedIn) {
      _showSnack('请先登录账号');
      return;
    }
    if (AuthService.serverUrl.isEmpty) {
      _showSnack('请先填写「后端服务地址」');
      return;
    }

    // 进度对话框（同步期间不可关闭）
    final progress = ValueNotifier<String>('准备中…');
    // ignore: use_build_context_synchronously
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('同步轨迹到云端'),
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, text, _) => Row(
            children: [
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await SyncService.syncAll(onProgress: (done, total) {
        progress.value = '正在同步 $done/$total 条…';
      });
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 关闭进度框
        setState(() {}); // 刷新上次同步时间
        // 云端条数/里程已变化，「我的」页的云端足迹卡片需重新拉取统计
        ref.invalidate(cloudStatsProvider);
        _showSnack(result.total == 0
            ? '暂无本地轨迹可同步'
            : result.failed == 0
                ? '同步完成：${result.synced}/${result.total} 条全部成功'
                : '同步完成：成功 ${result.synced}，失败 ${result.failed} 条');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack('同步失败: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 模拟数据开关：切换即持久化，并刷新美景/美食数据源 provider
  Future<void> _toggleUseMock(bool value) async {
    ref.read(useMockDataProvider.notifier).state = value;
    await DataConfig.setUseMockData(value);
    // 让已打开的美食/美景页立即按新数据源重载
    ref.invalidate(sceneryListProvider);
    ref.invalidate(sceneryDetailProvider);
    ref.invalidate(sceneryNearbyProvider);
    ref.invalidate(foodListProvider);
    ref.invalidate(foodDetailProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? '已切换为本地模拟数据' : '已切换为从服务端获取数据'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  /// 天气提醒开关：立即生效（持久化 + 排程/取消通知）
  Future<void> _toggleWeatherNotif(bool value) async {
    setState(() => _weatherNotif = value);
    // 切换城市后内容可能变化，但开关本身只需持久化 + 排程/取消；
    // 排程内部会用持久化城市重新拉取最新天气组装内容
    await WeatherPushService.setEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? '已开启：每天 08:00 推送今日天气' : '已关闭天气提醒'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _reset() async {
    await AppStorage.remove(AppStorage.kWeatherConfig);
    await AppStorage.remove(AppStorage.kAiConfig);
    await AuthService.setServerUrl('');
    // 恢复默认 = 服务端优先（无法连接时回退本地示例）
    await DataConfig.setUseMockData(false);
    ref.read(useMockDataProvider.notifier).state = false;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已恢复内置默认配置')));
      Navigator.of(context).pop();
    }
  }

  /// 卡片内开关行（图标 + 标题 + 副标题 + 右侧 Switch，由主题控制色）
  Widget _switchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(title,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint))
            : null,
        trailing: Switch(value: value, onChanged: onChanged),
      );

  /// 注销账号：两步确认（合规要求，避免误触）→ 调用服务删除 → 跳登录页。
  Future<void> _deleteAccount() async {
    final user = AuthService.currentUser;
    // 第一步：风险告知
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: Text(
            '将永久删除账号「${user?.phone ?? ''}」及云端同步的轨迹等数据，注销后无法恢复。\n\n确定要继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    // 第二步：最终确认
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('最终确认'),
        content: const Text('注销操作不可撤销，云端数据将立即删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;
    final ok = await AuthService.deleteAccount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '账号已注销，期待下次再见' : '注销失败，请检查网络后稍后再试'),
    ));
    if (ok) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final useMock = ref.watch(useMockDataProvider);
    final autoLocate = ref.watch(autoLocateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GradientHeader(
            title: '设置',
            actions: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              TextButton(
                onPressed: _save,
                child: const Text('保存',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- 天气服务（和风天气） ----------------
                // 注：当前暂时隐藏（_showWeatherAiConfig=false），保留代码便于日后恢复。
                // 核心配置区不包 FadeSlideIn 进场动画——动画期间 opacity=0，
                // 若延迟/首帧异常会导致区块「看不到」。配置页直接渲染最稳妥。
                if (_showWeatherAiConfig) ...[
                  const SectionTitle(title: '天气服务（和风天气）'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _field(_weatherHost, '专属 API Host',
                            '形如 https://xxxx.re.qweatherapi.com'),
                        const Divider(height: 24),
                        _field(_weatherKey, 'API Key', '和风天气控制台获取'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------------- 智能助手（OpenAI 兼容） ----------------
                  const SectionTitle(title: '智能助手（OpenAI 兼容）'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _field(_aiUrl, 'API 地址', 'https://…/chat/completions'),
                        const Divider(height: 24),
                        _field(_aiKey, 'API Key', 'sk-…'),
                        const Divider(height: 24),
                        _field(_aiModel, '模型名', 'glm-4.7-flash / deepseek-chat…'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ---------------- 账号与后端服务（Phase 4） ----------------
                const SectionTitle(title: '账号与后端服务'),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      _field(_authServer, '后端服务地址',
                          '留空 = 本地演示模式（离线可用）\n填写 https://… 后登录/注册走真实接口\n'
                          '（http:// 仅 debug 包可用，正式包会被系统禁止明文传输）'),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '接口约定：POST {地址}/api/v1/auth/login、/auth/register、/auth/logout\n响应格式：{token, user:{id,nickname,avatar,phone}}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _pinging ? null : _testConnection,
                            icon: _pinging
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.network_check, size: 18),
                            label: Text(_pinging ? '测试中…' : '测试连接'),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          // 内联结果：绿=连通，红=失败（同时也会弹 SnackBar 汇总文案）
                          if (_pingResult != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _pingResult!.ok
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    size: 16,
                                    color: _pingResult!.ok
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _pingResult!.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _pingResult!.ok
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ---------------- 账号注销（商店合规：小米等渠道强制要求提供） ----------------
                if (AuthService.isLoggedIn)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever_outlined,
                          size: 22, color: AppColors.danger),
                      title: const Text('注销账号',
                          style: TextStyle(
                              fontSize: 15,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text('删除账号及云端同步数据，不可恢复',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.textHint)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textHint),
                      onTap: _deleteAccount,
                    ),
                  ),
                const SizedBox(height: 20),

                // ---------------- 数据与位置（新增自动定位开关） ----------------
                const SectionTitle(title: '数据与位置'),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      _switchRow(
                        icon: Icons.dataset_outlined,
                        title: '使用模拟数据',
                        subtitle: AuthService.serverUrl.isEmpty
                            ? '未配置后端地址：当前暂用本地示例（设置中填写地址即切服务端）'
                            : '开启：内置示例；关闭：服务端优先（请求失败自动回退本地）',
                        value: useMock,
                        onChanged: _toggleUseMock,
                      ),
                      _kListDivider,
                      _switchRow(
                        icon: Icons.notifications_active_outlined,
                        title: '每日天气提醒',
                        subtitle: '每天早上 8:00 推送当前城市天气（本地通知）',
                        value: _weatherNotif,
                        onChanged: _toggleWeatherNotif,
                      ),
                      _kListDivider,
                      _switchRow(
                        icon: Icons.my_location_outlined,
                        title: '自动定位',
                        subtitle: '进入 App 时自动获取当前城市',
                        value: autoLocate,
                        onChanged: (v) =>
                            ref.read(autoLocateProvider.notifier).set(v),
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.admin_panel_settings_outlined,
                            size: 20, color: AppColors.primary),
                        title: const Text('权限管理',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                        subtitle: const Text('查看与申请定位 / 通知 / 健康数据授权',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => context.push('/profile/permissions'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- 数据同步（Phase 5） ----------------
                const SectionTitle(title: '数据同步（轨迹云端备份）'),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_sync_outlined,
                            color: AppColors.primary),
                        title: const Text('手动同步轨迹',
                            style: TextStyle(fontSize: 15)),
                        subtitle: Text(_syncStatusText,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                        trailing: FilledButton.icon(
                          onPressed: SyncService.isConfigured ? _syncNow : null,
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('立即同步'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                        ),
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_queue_outlined,
                            color: AppColors.primary),
                        title: const Text('云端历史',
                            style: TextStyle(fontSize: 15)),
                        subtitle: const Text('查看已上传的轨迹（可下载到本地）',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => context.push('/profile/cloud-trajectories'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- 其它（恢复默认 / 清除 / 关于 / 隐私） ----------------
                const SectionTitle(title: '其它'),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restore,
                            size: 20, color: AppColors.textSecondary),
                        title: const Text('恢复默认接口配置',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: _reset,
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.danger),
                        title: const Text('清除全部本地数据',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.danger)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('清除本地数据'),
                              content: const Text(
                                  '将删除城市、备忘、聊天记录、收藏等全部本地数据，且不可恢复。确定继续吗？'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('清除')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await AppStorage.clearAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已清除全部本地数据')));
                            }
                          }
                        },
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline,
                            size: 20, color: AppColors.primary),
                        title: const Text('关于微旅途',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => context.push('/profile/about'),
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined,
                            size: 20, color: AppColors.primary),
                        title: const Text('用户协议',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => context.push('/user-agreement'),
                      ),
                      _kListDivider,
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined,
                            size: 20, color: AppColors.primary),
                        title: const Text('隐私政策',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => context.push('/privacy-policy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '提示：接口配置仅存储在本机，用于个人调试；请勿在共享设备上填写生产密钥。',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
}
