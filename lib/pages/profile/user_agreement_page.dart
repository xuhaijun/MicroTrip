import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 用户协议页（P1：上架硬性要求，与《隐私政策》配套）
/// 覆盖服务说明 / 账号规则 / 用户行为规范 / 免责声明 / 协议变更等。
/// 首次启动的《用户协议 & 隐私政策》弹框即引用本页与隐私政策页。
/// 联系邮箱统一取 AppConfig.contactEmail（单点维护）。
/// ============================================================
class UserAgreementPage extends StatefulWidget {
  const UserAgreementPage({super.key});

  /// 协议更新日期（正式发布时改为实际日期）
  static const String updatedDate = '2026-08-21';

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
  final ScrollController _scroll = ScrollController();

  /// 协议分段（标题 + 正文），统一可滚动展示
  static const List<(String, String)> _sections = [
    (
      '一、协议的接受',
      '欢迎使用「微旅途」（以下简称"本应用"）。在使用本应用前，请你仔细阅读并理解本《用户协议》（以下简称"本协议"）的全部内容。'
      '你点击"同意"或实际使用本应用，即视为你已阅读、理解并同意接受本协议的全部条款。若你不同意本协议的任何内容，请停止使用本应用。'
    ),
    (
      '二、服务内容',
      '本应用为你提供以下服务（以实际界面为准）：\n'
      '1. 天气查询：实时天气、10 天预报及出行建议；\n'
      '2. 旅行规划：城市选择、美食与景点推荐、万年历与节假日查询；\n'
      '3. 轨迹记录：GPS 轨迹录制、里程/海拔统计与历史回放；\n'
      '4. 智能助手：基于你配置的大模型接口提供问答与行程建议；\n'
      '5. 个人数据：备忘、收藏、今日步数等本地化功能。\n'
      '本应用功能可能随版本迭代调整，具体以实际提供为准。'
    ),
    (
      '三、账号规则',
      '1. 本应用支持本地账号与服务端账号两种模式。本地模式下账号数据仅存储在你的设备中；'
      '服务端模式需你在「设置」中自行配置后端服务地址。\n'
      '2. 你应妥善保管账号与密码，因个人原因导致的账号泄露、数据丢失由你自行承担责任。\n'
      '3. 你承诺不以任何方式恶意注册、批量注册账号，不得利用账号从事违法违规活动。'
    ),
    (
      '四、用户行为规范',
      '你承诺在使用本应用过程中遵守法律法规，不得利用本应用从事以下行为：\n'
      '1. 发布、传输违法信息或侵犯他人合法权益的内容；\n'
      '2. 对本应用进行反向工程、破解或干扰其正常运行；\n'
      '3. 利用漏洞或技术手段获取他人数据；\n'
      '4. 其他违反法律法规或损害本应用及第三方利益的行为。\n'
      '如你违反上述规范，本应用有权视情况采取警示、限制功能直至封禁账号等措施。'
    ),
    (
      '五、数据与隐私',
      '本应用高度重视你的个人信息保护。你在使用过程中的数据收集、使用与保护规则，'
      '详见《隐私政策》。本协议与《隐私政策》共同构成你与本应用之间的完整约定。'
    ),
    (
      '六、第三方服务',
      '本应用的部分功能依赖第三方服务（如和风天气、你配置的 AI 服务等）。'
      '此类服务由第三方独立运营，其数据收集与处理适用其各自的条款与隐私政策，'
      '本应用不为其行为承担责任。'
    ),
    (
      '七、免责声明',
      '1. 本应用按"现状"提供服务，不保证服务不中断、不保证数据绝对准确；\n'
      '2. 天气、景点、美食等资讯来源于第三方，可能存在延迟或误差，请以官方渠道信息为准；\n'
      '3. 你在使用 GPS 轨迹、定位等功能时应遵守交通法规，因使用本应用产生的风险由你自行承担；\n'
      '4. 本应用不对因不可抗力、网络故障、设备问题等导致的损失承担责任。'
    ),
    (
      '八、知识产权',
      '本应用的界面设计、图标、文案及代码等知识产权归开发者所有，未经许可不得擅自复制、修改、传播或用于商业用途。'
    ),
    (
      '九、协议的变更与终止',
      '本应用可能适时更新本协议，更新后的协议将在本页面发布并自发布之日起生效。'
      '若你在协议更新后继续使用本应用，即视为接受更新后的条款。\n'
      '你可以随时停止使用本应用；当你注销账号或清除全部本地数据后，本协议约定的服务关系相应终止。'
    ),
    (
      '十、法律适用与争议解决',
      '本协议的订立、履行与解释均适用中华人民共和国法律。'
      '因本协议产生的争议，双方应友好协商解决；协商不成的，任何一方可向本应用运营方所在地有管辖权的人民法院提起诉讼。'
    ),
    (
      '十一、联系我们',
      '如对本协议有任何疑问或建议，可通过邮箱 ${AppConfig.contactEmail} 与我们联系。'
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
            title: '用户协议',
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
                  Text('更新日期：${UserAgreementPage.updatedDate}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _sections.length; i++) ...[
                    _AgreementSection(_sections[i].$1, _sections[i].$2),
                    const SizedBox(height: 16),
                  ],
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

/// 用户协议单节：标题 + 正文，统一用 AppCard 包裹
class _AgreementSection extends StatelessWidget {
  final String title;
  final String body;
  const _AgreementSection(this.title, this.body);

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
