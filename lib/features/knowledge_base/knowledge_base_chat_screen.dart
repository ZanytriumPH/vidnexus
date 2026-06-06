import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_markdown_body.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../app/widgets/citation_card.dart';
import '../../services/service_providers.dart';
import 'application/knowledge_base_chat_controller.dart';
import 'application/knowledge_base_controller.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseChatScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseChatScreen({
    required this.kbid,
    required this.initialConversation,
    super.key,
  });

  final String kbid;
  final KnowledgeConversationPreview initialConversation;

  @override
  ConsumerState<KnowledgeBaseChatScreen> createState() =>
      _KnowledgeBaseChatScreenState();
}

class _KnowledgeBaseChatScreenState extends ConsumerState<KnowledgeBaseChatScreen> {
  late final KnowledgeBaseChatController _chatController;
  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();

    final qaService = ref.read(globalQAServiceProvider);
    _chatController = KnowledgeBaseChatController(
      qaService: qaService,
      kbid: widget.kbid,
      chatId: widget.initialConversation.id,
      initialMessages: widget.initialConversation.messages,
    )..addListener(_onChatStateChanged)
     ..triggerInitialQA();
  }

  void _onChatStateChanged() {
    if (!mounted) return;
    setState(() {}); // ChangeNotifier 驱动重建
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatController
      ..removeListener(_onChatStateChanged)
      ..dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _chatController.messages;
    final isWaiting = _chatController.isWaitingForAnswer;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: KnowledgeBaseTopBar(
                currentSection: AppNavSection.knowledgeBase,
                onSectionSelected: (section) {
                  switch (section) {
                    case AppNavSection.videoSummary:
                      AppNavigator.goToHomeRoot(context);
                    case AppNavSection.knowledgeBase:
                      AppNavigator.popToKnowledgeBaseHome(context);
                  }
                },
                title: ref.watch(selectedLibraryControllerProvider).selectedLibrary?.title ?? '对话',
                onLeadingPressed: () => AppNavigator.popCurrent(context),
                trailing: AppHeaderAddButton(onPressed: _startEmptyConversation),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                itemCount: messages.length + (isWaiting ? 1 : 0),
                separatorBuilder: (context, index) => SizedBox(
                  height: context.appMessageStyles.messageSpacing,
                ),
                itemBuilder: (context, index) {
                  if (isWaiting && index == messages.length) {
                    return const _KnowledgeTypingIndicator();
                  }
                  final message = messages[index];
                  // 空系统消息不渲染，此时 "AI正在思考..." 的 typing indicator 正在展示
                  if (message.sender == KnowledgeChatSender.system &&
                      message.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _KnowledgeChatBubble(message: message);
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: KnowledgeBaseComposer(
                controller: _composerController,
                onSubmit: _sendMessage,
                enabled: !isWaiting,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    _composerController.clear();
    _chatController.sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startEmptyConversation() async {
    final chatService = ref.read(globalChatServiceProvider);
    final kbid = widget.kbid;

    try {
      final resp = await chatService.createChat(kbid: kbid, chatTitle: '新的会话');
      final chatId = resp.data?.chatId;
      if (chatId != null && chatId.isNotEmpty && mounted) {
        final newConv = KnowledgeConversationPreview(
          id: chatId,
          title: '新的会话',
          preview: '已进入新会话，可以直接围绕当前知识库继续提问。',
          dateLabel: '刚刚',
          messages: [
            KnowledgeChatMessage(
              sender: KnowledgeChatSender.system,
              text: '已为"${ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? ''}"新建会话。你可以直接提问，我会只基于当前知识库的资料继续回答。',
            ),
          ],
        );
        if (!mounted) return;
        AppNavigator.openKnowledgeBaseChat(
          context,
          kbid: kbid,
          initialConversation: newConv,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppNavigator.openKnowledgeBaseChat(
        context,
        kbid: kbid,
        initialConversation: buildEmptyKnowledgeConversation(
          libraryTitle: ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? '',
        ),
      );
    }
  }
}

/// AI 正在思考的动画指示器。
class _KnowledgeTypingIndicator extends StatefulWidget {
  const _KnowledgeTypingIndicator();

  @override
  State<_KnowledgeTypingIndicator> createState() =>
      _KnowledgeTypingIndicatorState();
}

class _KnowledgeTypingIndicatorState extends State<_KnowledgeTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _TypingDot(),
              SizedBox(width: 6),
              _TypingDot(),
              SizedBox(width: 6),
              _TypingDot(),
              SizedBox(width: 10),
              Text(
                'AI 正在思考…',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF8E8E93),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _KnowledgeChatBubble extends StatelessWidget {
  const _KnowledgeChatBubble({required this.message});

  final KnowledgeChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == KnowledgeChatSender.user;
    final messageStyles = context.appMessageStyles;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 351),
          padding: messageStyles.bubblePadding,
          decoration: BoxDecoration(
            color: messageStyles.userSurface,
            borderRadius: BorderRadius.circular(messageStyles.chatBubbleRadius),
          ),
          child: Text(
            message.text,
            style: context.appTextStyles.summaryContentBody,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: messageStyles.bubblePadding,
      decoration: BoxDecoration(
        color: messageStyles.systemSurface,
        borderRadius: BorderRadius.circular(messageStyles.chatBubbleRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMarkdownBody(data: message.text),
          if (message.citedSources != null &&
              message.citedSources!.isNotEmpty) ...[
            const SizedBox(height: 12),
            CitationCards(
              citedSources: message.citedSources!,
              onCitationTap: (source) {
                // 优先按 taskId 精确跳转（避免 listTasks+videoId 匹配到同一视频的其他 task）
                final taskId = source.taskId;
                final videoId = source.videoId;
                if (taskId != null && taskId.isNotEmpty) {
                  AppNavigator.goToHomeWithVideo(
                    context,
                    videoId: videoId ?? '',
                    taskId: taskId,
                  );
                } else if (videoId != null && videoId.isNotEmpty) {
                  AppNavigator.goToHomeWithVideo(context, videoId: videoId);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
