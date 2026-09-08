import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 隐私政策页（P1：上架硬性要求）
/// 较完整的示例正文，贴近本 App 实际功能；
/// 正式上架前请将「联系邮箱」替换为运营方真实信息，
/// 并视需要将本文托管到可访问 URL 填入各商店后台。
/// ============================================================
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  /// 政策更新日期（正式发布时改为实际日期）
  static const String updatedDate = '2026-08-21';

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  final ScrollController _scroll = ScrollController();

  /// 政策分段（标题 + 正文），统一可滚动展示
  static const List<(String, String)> _sections = [
    (
      '一、我们如何对待你的数据',
      '微旅途（MicroTrip）致力于保护你的隐私。在默认情况下，你的城市选择、天气缓存、'
      '备忘、收藏、聊天记录、轨迹等个人数据均仅保存在你本机设备中，不会主动上传至任何服务器。\n\n'
      '仅当你在「设置 - 账号与后端服务」中主动填写后端服务地址并登录后，轨迹数据才会按你的'
      '操作备份到你所指定的服务端；你随时可在设置中清除本地数据或退出账号。'
    ),
    (
      '二、我们获取的信息',
      '1. 位置信息：用于获取当前城市天气、海拔以及 GPS 轨迹录制。'
      'iOS / Android 均在你授权后获取，可随时在系统设置中关闭。\n'
      '2. 健康与运动数据：步数来自系统健康平台（Android Health Connect / iOS HealthKit），'
      '仅在授权后读取，用于「今日步数」展示。\n'
      '3. 通知：用于每日天气提醒（本地系统通知，不收集通知内容）。\n'
      '4. 账号信息：仅当你启用云端后端时，手机号 / 昵称等用于登录注册，存储在你指定的服务端。\n'
      '5. 轨迹数据：GPS 轨迹点、距离、海拔、停留点等，默认仅存储在本机。\n'
      '6. 图片：拍照识物时拍摄或选择的图片，若已配置视觉模型则发往该模型；未配置时仅本地处理，不上传。\n'
      '7. 聊天内容：与小途 AI 的对话会发往你配置的 AI 服务（OpenAI 兼容接口）。'
    ),
    (
      '三、第三方服务',
      '为提供核心功能，本应用会直接向以下第三方服务发起请求'
      '（由其独立收集并处理数据，适用其各自的隐私政策）：\n'
      '· 天气数据：和风天气 QWeather；\n'
      '· 智能助手：你配置的 AI 服务（如智谱 GLM 等 OpenAI 兼容服务）；\n'
      '· 视觉识别：你配置的视觉模型（如未配置则不调用）。'
    ),
    (
      '四、信息的存储与安全',
      '本机数据通过系统存储（SharedPreferences / 文件系统）保存，仅本机应用可访问。'
      '云端数据由你指定的服务端负责安全存储，请仅使用你信任的后端服务。'
      '我们不会出售你的个人信息。\n'
      '数据保留期限：本地数据在你主动清除前持续保留；退出登录不清除本地数据；'
      '使用「清除全部本地数据」后相关本地信息将被删除。云端数据由你指定的服务端按其规则管理。'
    ),
    (
      '五、敏感权限的使用',
      '本应用在获得你授权后会使用以下系统能力，均可在系统设置中随时关闭：\n'
      '1. 定位：获取当前城市天气、海拔与 GPS 轨迹录制（仅前台使用；开启后台录制时持续使用）；\n'
      '2. 健康数据：读取步数用于「今日步数」展示（仅读取，不写入）；\n'
      '3. 通知：每日天气提醒（本地系统通知，不收集通知内容）；\n'
      '4. 相机 / 相册：拍照识物时拍摄或选择图片（图片仅在已配置视觉模型时上传至该模型）。\n'
      '我们遵循「最小必要」原则：仅在对应功能使用时申请权限，拒绝授权不影响其它功能使用。'
    ),
    (
      '六、你的权利',
      '· 查看与删除本机数据：设置 - 清除全部本地数据；\n'
      '· 关闭敏感权限：在系统设置或「设置 - 权限管理」中随时撤销定位 / 健康 / 通知权限；\n'
      '· 撤回同意：你可随时撤回对《用户协议》与《隐私政策》的同意（清除本地数据后重新启动将再次征询）；\n'
      '· 账号注销：退出登录并清除本地数据即可；云端账号的注销请联系对应服务端运营方。'
    ),
    (
      '七、儿童隐私',
      '本应用不面向 13 岁以下儿童，我们不会有意收集儿童个人信息。'
      '若你为未成年人，请在监护人指导下使用本应用。'
    ),
    (
      '八、政策变更',
      '我们可能适时更新本隐私政策，更新内容将发布在本页面。'
      '若更新涉及你的重要权益，我们会在本页面显著提示。建议你定期查看。'
    ),
    (
      '九、联系我们',
      '如对本隐私政策有疑问，可通过邮箱 privacy@microtrip.example 与我们联系，'
      '我们将在 15 个工作日内回复。'
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '隐私政策',
            actions: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('更新日期：${PrivacyPolicyPage.updatedDate}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _sections.length; i++) ...[
                    FadeSlideIn(
                      delay: i * 60,
                      child: _PolicySection(_sections[i].$1, _sections[i].$2),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    '本政策适用于「微旅途」全部功能。如对内容有疑问，可联系 privacy@microtrip.example。',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: '返回顶部',
                    onPressed: () => _scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 隐私政策单节：标题 + 正文，统一用 AppCard 包裹
class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _PolicySection(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.8)),
        ],
      ),
    );
  }
}
