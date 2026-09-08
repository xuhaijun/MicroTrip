import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 出行备忘列表页（对应小程序 subpackages/tools/pages/memo）
/// 统一「微旅途」设计语言：GradientHeader + AppCard + SectionTitle + EmptyState
/// ============================================================
class MemoListPage extends ConsumerWidget {
  const MemoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memoProvider);
    final done = memos.where((m) => m.completed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '出行备忘',
            subtitle:
                memos.isEmpty ? null : '已完成 $done / ${memos.length}',
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: '新增备忘',
                onPressed: () => context.push('/trip/memo/edit'),
              ),
            ],
          ),
          Expanded(
            child: memos.isEmpty
                ? const EmptyState(
                    icon: Icons.note_alt_outlined,
                    text: '暂无出行备忘',
                    hint: '点击右上角 + 新建一条',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: memos.length,
                    itemBuilder: (_, i) {
                      final m = memos[i];
                      return FadeSlideIn(
                        delay: i * 60,
                        child: Dismissible(
                          key: ValueKey(m.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) =>
                              ref.read(memoProvider.notifier).remove(m.id),
                          child: AppCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            onTap: () =>
                                context.push('/trip/memo/edit', extra: m.id),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      ref.read(memoProvider.notifier).toggle(m),
                                  child: Icon(
                                    m.completed
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: m.completed
                                        ? AppColors.success
                                        : AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: m.completed
                                              ? AppColors.textHint
                                              : AppColors.textPrimary,
                                          decoration: m.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (m.content.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          m.content,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                      if (m.remindTime != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.alarm,
                                                size: 13,
                                                color: AppColors.warning),
                                            const SizedBox(width: 3),
                                            Text(
                                              _fmtTime(m.remindTime!),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
