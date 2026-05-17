import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_markdown_body.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../services/global_qa_service.dart';
import '../../services/service_providers.dart';
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
  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();
  late List<KnowledgeChatMessage> _messages;
  bool _isWaitingForAnswer = false;

  GlobalQAService get _qaService => ref.read(globalQAServiceProvider);

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _messages = List<KnowledgeChatMessage>.from(
      widget.initialConversation.messages,
    );

    // 如果初始消息中只有用户问题没有系统回答，自动触发 QA 创建
    _maybeTriggerInitialQA();
  }

  /// 检测是否需要为初始问题发起 QA 请求。
  void _maybeTriggerInitialQA() {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    // 如果最后一条是用户消息（说明还没得到回答），且 chatId 是真实的（非临时占位）
    if (lastMessage.sender == KnowledgeChatSender.user &&
        !widget.initialConversation.id.startsWith('creating-') &&
        !widget.initialConversation.id.startsWith('new-')) {
      // 移除占位的系统回复（如果有），然后发起真实 QA
      _messages = _messages
          .where((m) => m.sender == KnowledgeChatSender.user)
          .toList();
      _sendChatMessage(lastMessage.text);
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                title: ref.watch(knowledgeBaseControllerProvider).selectedLibrary?.title ?? '对话',
                onLeadingPressed: () => AppNavigator.popCurrent(context),
                trailing: AppHeaderAddButton(onPressed: _startEmptyConversation),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                itemCount: _messages.length + (_isWaitingForAnswer ? 1 : 0),
                separatorBuilder: (context, index) => SizedBox(
                  height: context.appMessageStyles.messageSpacing,
                ),
                itemBuilder: (context, index) {
                  if (_isWaitingForAnswer && index == _messages.length) {
                    return const _KnowledgeTypingIndicator();
                  }
                  final message = _messages[index];
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
                enabled: !_isWaitingForAnswer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _composerController.text.trim();
    if (text.isEmpty || _isWaitingForAnswer) {
      return;
    }

    FocusScope.of(context).unfocus();
    _composerController.clear();

    setState(() {
      _messages = [
        ..._messages,
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: text),
      ];
    });

    _sendChatMessage(text);
  }

  /// 发起真实 QA 请求并轮询等待回答。
  Future<void> _sendChatMessage(String text) async {
    final chatId = widget.initialConversation.id;
    final kbid = widget.kbid;

    // 如果是临时 ID，不发起真实请求
    if (chatId.startsWith('creating-') || chatId.startsWith('new-')) {
      return;
    }

    setState(() => _isWaitingForAnswer = true);

    try {
      // 1. 创建 QA
      final createResp = await _qaService.createQA(
        kbid: kbid,
        chatId: chatId,
        questionContent: text,
      );
      final qaId = createResp.data?.qaId;
      if (qaId == null || qaId.isEmpty) {
        throw Exception('QA creation returned empty qaId');
      }

      // 2. 轮询等待回答
      final answer = await _pollForAnswer(kbid: kbid, chatId: chatId, qaId: qaId);

      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: answer,
          ),
        ];
        _isWaitingForAnswer = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '抱歉，回答生成失败：$e',
          ),
        ];
        _isWaitingForAnswer = false;
      });
    }

    _scrollToBottom();
  }

  /// 轮询 GlobalQAService.getQA 直到 answer_content 非空。
  Future<String> _pollForAnswer({
    required String kbid,
    required String chatId,
    required String qaId,
  }) async {
    final stopwatch = Stopwatch()..start();
    const timeout = Duration(seconds: 60);
    const interval = Duration(seconds: 2);

    while (true) {
      if (stopwatch.elapsed > timeout) {
        throw Exception('回答生成超时（${timeout.inSeconds}秒）');
      }

      final resp = await _qaService.getQA(kbid, chatId, qaId);
      final dto = resp.data;
      if (dto != null && dto.answerContent != null && dto.answerContent!.isNotEmpty) {
        return dto.answerContent!;
      }

      await Future<void>.delayed(interval);
    }
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
              text: '已为"${ref.read(knowledgeBaseControllerProvider).selectedLibrary?.title ?? ''}"新建会话。你可以直接提问，我会只基于当前知识库的资料继续回答。',
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
      // 创建失败时回退到本地模式
      if (!mounted) return;
      AppNavigator.openKnowledgeBaseChat(
        context,
        kbid: kbid,
        initialConversation: buildEmptyKnowledgeConversation(
          libraryTitle: ref.read(knowledgeBaseControllerProvider).selectedLibrary?.title ?? '',
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
      child: AppMarkdownBody(data: message.text),
    );
  }
}
