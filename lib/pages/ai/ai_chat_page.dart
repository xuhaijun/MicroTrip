import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 小途 AI 助手聊天页（对应小程序 subpackages/travel/pages/suggest）
/// - 气泡式对话 UI（用户右侧蓝色 / 小途左侧白色）
/// - 历史记录持久化（travel_aiChatHistory）
/// - 发送中「正在思考…」占位
/// ============================================================
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || ref.read(aiChatProvider).sending) return;
    _controller.clear();
    await ref.read(aiChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 60,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空会话'),
        content: const Text('确定清空全部聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(aiChatProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatProvider);

    // 发送中自动滚到底部（思考气泡出现时）
    if (chat.sending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '小途助手',
            subtitle: '你的 AI 旅行搭子 · 问天气 / 美食 / 攻略',
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                tooltip: '清空会话',
                onPressed: _confirmClear,
              ),
            ],
          ),
          Expanded(
            child: chat.messages.isEmpty && !chat.sending
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    text: '你好，我是小途！',
                    hint: '问我天气、美食、景点、行程规划…',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      // 发送中的「思考中」占位气泡
                      if (i == chat.messages.length) {
                        return FadeSlideIn(
                          delay: i * 60,
                          child: _bubble(
                            maxWidth: maxBubbleWidth,
                            isUser: false,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('小途正在思考…',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHint,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }
                      final m = chat.messages[i];
                      return FadeSlideIn(
                        delay: i * 60,
                        child: _bubble(
                          maxWidth: maxBubbleWidth,
                          isUser: m.isUser,
                          child: Text(
                            m.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: m.isUser ? Colors.white : AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // ---------------- 输入栏 ----------------
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '问问小途…',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.round),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: chat.sending ? null : _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: chat.sending
                            ? const LinearGradient(
                                colors: [Color(0xFFB8C4CC), Color(0xFFB8C4CC)],
                              )
                            : AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        size: 18,
                        color: chat.sending ? Colors.white70 : Colors.white,
                      ),
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

  /// 消息气泡（用户右对齐主色渐变白字，助手左对齐白卡深色字）
  Widget _bubble({
    required double maxWidth,
    required bool isUser,
    required Widget child,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.primaryGradient : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadius.lg),
          ),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }
}
