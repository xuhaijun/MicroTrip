import '../core/config/app_config.dart';
import '../core/http/http_client.dart';
import '../core/storage/app_storage.dart';
import '../models/ai_message.dart';

/// ============================================================
/// AI 大模型服务（OpenAI 兼容 Chat Completions）
/// 迁移自小程序 utils/ai.js：
///  - 默认智谱 GLM，可切换 DeepSeek / 通义千问（设置页覆盖）
///  - 保留最近 20 条历史作为上下文
///  - 未配置 / 网络失败 → 关键词匹配 Mock 回复
/// ============================================================
class AiService {
  AiService._();

  /// 读取当前生效的 AI 配置（用户覆盖 > 内置默认）
  static ({
    String apiUrl,
    String apiKey,
    String model,
    String systemPrompt,
    int maxTokens,
    double temperature,
  }) get config {
    final saved = AppStorage.getObject(AppStorage.kAiConfig);
    String url = AppConfig.aiApiUrl;
    String key = AppConfig.aiApiKey;
    String model = AppConfig.aiModel;
    if (saved is Map) {
      url = saved['apiUrl']?.toString() ?? url;
      key = saved['apiKey']?.toString() ?? key;
      model = saved['model']?.toString() ?? model;
    }
    return (
      apiUrl: url,
      apiKey: key,
      model: model,
      systemPrompt: AppConfig.aiSystemPrompt,
      maxTokens: AppConfig.aiMaxTokens,
      temperature: AppConfig.aiTemperature,
    );
  }

  /// 发送对话（messages 为完整上下文，服务内部追加 system 提示）
  static Future<String> chat(List<AiMessage> messages) async {
    final c = config;

    // 未配置 Key → Mock 回复
    if (c.apiKey.isEmpty || c.apiKey.contains('YOUR_')) {
      return _mockReply(messages);
    }

    final body = {
      'model': c.model,
      'messages': [
        {'role': 'system', 'content': c.systemPrompt},
        ...messages.map((m) => {'role': m.role, 'content': m.content}),
      ],
      'max_tokens': c.maxTokens,
      'temperature': c.temperature,
      'stream': false,
    };

    final data = await HttpClient.post(
      c.apiUrl,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${c.apiKey}',
      },
    );

    final choices = data?['choices'];
    if (choices is List && choices.isNotEmpty) {
      final content = choices.first['message']?['content'];
      if (content is String && content.isNotEmpty) return content;
    }
    final errMsg = data?['error']?['message'] ?? '智能助手暂不可用';
    throw ServiceException(errMsg.toString());
  }

  /// 单条提问（附带上下文，如当前城市/天气）
  static Future<String> ask(String message, {String context = ''}) {
    final msgs = <AiMessage>[];
    if (context.isNotEmpty) {
      // 上下文以 system 角色注入（与小程序一致）
      msgs.add(AiMessage(
        role: 'system',
        content: '当前上下文信息：\n$context\n\n请基于以上信息回答用户问题。',
      ));
    }
    msgs.add(AiMessage(role: 'user', content: message));
    return chat(msgs);
  }

  /// Mock 回复：关键词匹配（迁移自小程序 getMockResponse 思路并扩充）
  static String _mockReply(List<AiMessage> messages) {
    final last = messages.lastWhere((m) => m.isUser, orElse: () =>
        messages.first).content;
    if (last.contains('天气')) {
      return '今天天气不错，适合出行哦～建议关注首页天气卡片获取实时信息。'
          '（当前为演示回复，请在「设置」中配置 AI API Key 体验真实小途助手）';
    }
    if (last.contains('吃') || last.contains('美食')) {
      return '为您推荐当地特色美食：火锅、串串香、担担面、龙抄手……'
          '发现页有更详细的美食推荐，快去看看吧！（演示回复）';
    }
    if (last.contains('景') || last.contains('玩')) {
      return '推荐打卡景点：宽窄巷子、锦里、大熊猫基地、都江堰……'
          '合理安排行程，注意查看天气预报哦！（演示回复）';
    }
    if (last.contains('行程') || last.contains('规划')) {
      return '为您规划一日游：上午打卡地标景点 → 中午品尝本地美食 → '
          '下午逛特色街区 → 傍晚看日落夜景。祝旅途愉快！（演示回复）';
    }
    return '你好，我是小途，你的专属旅行助手！可以问我天气、美食、景点、行程规划等问题。'
        '（当前为演示回复，请在「设置-智能助手」中配置 AI API Key 体验完整能力）';
  }
}
