/// ============================================================
/// 备忘模型
/// 对应小程序存储键 travel_memoList：
/// [{ id, title, content, priority, remindTime, completed, createdAt }]
/// ============================================================
class MemoItem {
  MemoItem({
    required this.id,
    required this.title,
    this.content = '',
    this.priority = 0, // 0 普通 / 1 重要 / 2 紧急
    this.remindTime, // 提醒时间（可空）
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String content;
  final int priority;
  final DateTime? remindTime;
  final bool completed;
  final DateTime createdAt;

  String get priorityLabel => switch (priority) {
        2 => '紧急',
        1 => '重要',
        _ => '普通',
      };

  factory MemoItem.fromMap(Map<String, dynamic> map) => MemoItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        priority: (map['priority'] as num?)?.toInt() ?? 0,
        remindTime: map['remindTime'] != null
            ? DateTime.tryParse(map['remindTime'].toString())
            : null,
        completed: map['completed'] == true,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'priority': priority,
        'remindTime': remindTime?.toIso8601String(),
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  MemoItem copyWith({
    String? title,
    String? content,
    int? priority,
    DateTime? remindTime,
    bool? completed,
  }) =>
      MemoItem(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        priority: priority ?? this.priority,
        remindTime: remindTime ?? this.remindTime,
        completed: completed ?? this.completed,
        createdAt: createdAt,
      );
}
