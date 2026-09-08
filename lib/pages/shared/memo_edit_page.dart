import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/memo_item.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 备忘编辑页（对应小程序 subpackages/tools/pages/memo-edit）
/// 新建 / 编辑二合一；优先级 3 档；可选提醒时间；完成状态切换
/// ============================================================
class MemoEditPage extends ConsumerStatefulWidget {
  const MemoEditPage({super.key, this.editId});

  final String? editId; // 传 id 为编辑模式，null 为新建

  @override
  ConsumerState<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends ConsumerState<MemoEditPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int _priority = 0;
  DateTime? _remindTime;
  bool _completed = false;
  DateTime? _originalCreatedAt;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 编辑模式：回填数据
  void _initFromExisting(List<MemoItem> memos) {
    if (_initialized || widget.editId == null) return;
    final item = memos.where((m) => m.id == widget.editId).firstOrNull;
    if (item != null) {
      _titleController.text = item.title;
      _contentController.text = item.content;
      _priority = item.priority;
      _remindTime = item.remindTime;
      _completed = item.completed;
      _originalCreatedAt = item.createdAt;
    }
    _initialized = true;
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remindTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindTime ?? now),
    );
    if (time == null) return;
    setState(() {
      _remindTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    final notifier = ref.read(memoProvider.notifier);
    final item = MemoItem(
      id: widget.editId ?? AppStorage.generateId(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      priority: _priority,
      remindTime: _remindTime,
      completed: _completed,
      createdAt: widget.editId != null ? _originalCreatedAt : null,
    );
    await notifier.save(item);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (widget.editId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备忘'),
        content: const Text('确定删除这条备忘吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(memoProvider.notifier).remove(widget.editId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memoProvider);
    _initFromExisting(memos);
    final isEdit = widget.editId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: isEdit ? '编辑备忘' : '新建备忘',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ---------------- 标题 ----------------
                AppCard(
                  child: TextField(
                    controller: _titleController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: '标题（如：明天订去成都的机票）',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),

                // ---------------- 内容 ----------------
                AppCard(
                  child: TextField(
                    controller: _contentController,
                    maxLines: 5,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: '详细内容（可选）',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
                const SizedBox(height: 12),

                // ---------------- 优先级 ----------------
                const SectionTitle(title: '优先级'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (p, label) in [
                      (0, '普通'),
                      (1, '重要'),
                      (2, '紧急')
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _priority = p),
                          child: Container(
                            margin: EdgeInsets.only(right: p < 2 ? 10 : 0),
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: _priority == p
                                  ? AppColors.primaryGradient
                                  : null,
                              color: _priority == p ? null : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.card,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                color: _priority == p
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ---------------- 提醒时间 ----------------
                AppCard(
                  onTap: _pickTime,
                  child: Row(
                    children: [
                      const Icon(Icons.alarm,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _remindTime == null
                              ? '设置提醒时间（可选）'
                              : '${_remindTime!.year}/${_remindTime!.month}/${_remindTime!.day} '
                                  '${_remindTime!.hour.toString().padLeft(2, '0')}:'
                                  '${_remindTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: _remindTime == null
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_remindTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _remindTime = null),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.textHint),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---------------- 完成状态 ----------------
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('标记为已完成',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            )),
                      ),
                      Switch(
                        value: _completed,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _completed = v),
                      ),
                    ],
                  ),
                ),

                // ---------------- 保存（移入内容滚动区，置于删除按钮上方；不再固定底部） ----------------
                const SizedBox(height: 12),
                GradientButton(
                  label: '保存',
                  onPressed: _save,
                ),

                // ---------------- 删除（仅编辑态） ----------------
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: _delete,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline,
                            color: AppColors.danger, size: 18),
                        SizedBox(width: 6),
                        Text('删除备忘',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
