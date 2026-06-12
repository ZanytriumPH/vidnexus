import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_markdown_body.dart';
import '../../app/widgets/app_typing_indicator.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../app/widgets/citation_card.dart';
import '../../app/widgets/thinking_process_section.dart';
import '../../services/service_providers.dart';
import 'application/knowledge_base_chat_controller.dart';
import 'application/knowledge_base_controller.dart';
import '../home/video_summary_presentation_models.dart' show ChatAttachment;
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
  final List<AttachmentInfo> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();

    final qaService = ref.read(globalQAServiceProvider);
    _chatController = getOrCreateKbChatController(
      qaService: qaService,
      kbid: widget.kbid,
      chatId: widget.initialConversation.id,
      initialMessages: widget.initialConversation.messages,
    )..addListener(_onChatStateChanged);

    // 仅当 controller 未在等待回答时触发初始 QA 流程，
    // 避免在 SSE 流进行中重发请求。
    if (!_chatController.isWaitingForAnswer) {
      _chatController.triggerInitialQA();
    }
  }

  void _onChatStateChanged() {
    if (!mounted) return;
    setState(() {}); // ChangeNotifier 驱动重建
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatController.removeListener(_onChatStateChanged);
    // 不 dispose controller：实例由 _activeControllers 缓存管理，
    // 保留以便 SSE 流跨页面导航继续消费。
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
                    String? progressMessage;
                    if (messages.isNotEmpty) {
                      final lastMsg = messages.last;
                      if (lastMsg.sender == KnowledgeChatSender.system) {
                        final steps = lastMsg.progressSteps;
                        if (steps != null && steps.isNotEmpty) {
                          progressMessage = steps.last.message;
                        }
                      }
                    }
                    return AppTypingIndicator(message: progressMessage);
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
                onAttachmentsChanged: (attachments) {
                  _pendingAttachments
                    ..clear()
                    ..addAll(attachments);
                },
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
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    FocusScope.of(context).unfocus();
    _composerController.clear();

    final attachments = List<AttachmentInfo>.from(_pendingAttachments);
    _pendingAttachments.clear();

    final finalText = text.isEmpty ? '请分析用户上传的图片' : text;
    _chatController.sendMessage(finalText, attachments: attachments);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.attachments.isNotEmpty) ...[
                _KbAttachmentImageGrid(attachments: message.attachments),
                const SizedBox(height: 8),
              ],
              Text(
                message.text,
                style: context.appTextStyles.summaryContentBody,
              ),
            ],
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
          if (message.progressSteps != null &&
              message.progressSteps!.isNotEmpty) ...[
            ThinkingProcessSection(steps: message.progressSteps!),
            const SizedBox(height: 12),
          ],
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
                    forceFinal: true,
                  );
                } else if (videoId != null && videoId.isNotEmpty) {
                  AppNavigator.goToHomeWithVideo(
                    context,
                    videoId: videoId,
                    forceFinal: true,
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 知识库聊天气泡中的附件图片网格。
class _KbAttachmentImageGrid extends StatelessWidget {
  const _KbAttachmentImageGrid({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final displayCount = attachments.length > 4 ? 4 : attachments.length;
    final overflow = attachments.length - displayCount;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < displayCount; i++)
          GestureDetector(
            onTap: () => _showFullImage(context, attachments[i]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: attachments[i].ossKey.isNotEmpty
                    ? Image.network(
                        _thumbnailUrl(attachments[i].ossKey),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
          ),
        if (overflow > 0)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _thumbnailUrl(String ossKey) {
    final base = ApiClient.instance.options.baseUrl;
    return '$base/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 24, color: AppColors.textHint),
      ),
    );
  }

  void _showFullImage(BuildContext context, ChatAttachment attachment) {
    if (attachment.ossKey.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              _thumbnailUrl(attachment.ossKey),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 200,
                child: Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
