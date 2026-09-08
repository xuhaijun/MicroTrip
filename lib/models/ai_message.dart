/// ============================================================
/// AI 聊天消息模型
/// 对应小程序存储键 travel_aiChatHistory：[{ role, content, time }]
/// ============================================================
class AiMessage {
  AiMessage({
    required this.role,
    required this.content,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  /// 'user' | 'assistant' | 'system'
  final String role;
  final String content;
  final DateTime time;

  bool get isUser => role == 'user';

  factory AiMessage.fromMap(Map<String, dynamic> map) => AiMessage(
        role: map['role']?.toString() ?? 'user',
        content: map['content']?.toString() ?? '',
        time: map['time'] != null
            ? DateTime.tryParse(map['time'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
        'time': time.toIso8601String(),
      };
}
