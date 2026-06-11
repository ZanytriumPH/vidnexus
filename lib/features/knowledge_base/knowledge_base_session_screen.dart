import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../app/widgets/app_card.dart';
import '../../services/models/video_qa_dto.dart' show AttachmentInfo;
import '../../services/service_providers.dart';
import '../home/video_summary_presentation_models.dart' show ChatAttachment;
import 'application/knowledge_base_controller.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseSessionScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseSessionScreen({required this.kbid, super.key});

  final String kbid;

  @override
  ConsumerState<KnowledgeBaseSessionScreen> createState() =>
      _KnowledgeBaseSessionScreenState();
}

class _KnowledgeBaseSessionScreenState
    extends ConsumerState<KnowledgeBaseSessionScreen> {
  late final TextEditingController _composerController;
  final List<AttachmentInfo> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    // 进入页面时加载知识库详情
    Future.microtask(() {
      ref.read(selectedLibraryControllerProvider.notifier).selectLibrary(widget.kbid);
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(selectedLibraryControllerProvider);
    final library = state.selectedLibrary;

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
                title: library?.title ?? '加载中…',
                onLeadingPressed: () => AppNavigator.popCurrent(context),
                trailing: AppHeaderAddButton(onPressed: _startEmptyConversation),
              ),
            ),
            Expanded(
              child: library == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: _openSources,
                              borderRadius: BorderRadius.circular(21),
                              child: Container(
                                height: 45,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(21),
                                  border: Border.all(color: AppColors.borderStrong),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '查看 ${library.sourceCount} 个来源',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '历史会话',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (library.conversations.isEmpty)
                            Text(
                              '暂无会话',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                            )
                          else
                            ...library.conversations.map(
                              (conversation) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ConversationPreviewCard(
                                  conversation: conversation,
                                  onTap: () => _openConversation(conversation),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: KnowledgeBaseComposer(
                controller: _composerController,
                onSubmit: _startNewConversation,
                onAttachmentsChanged: (attachments) {
                  _pendingAttachments
                    ..clear()
                    ..addAll(attachments);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConversation(KnowledgeConversationPreview conversation) {
    AppNavigator.openKnowledgeBaseChat(
      context,
      kbid: widget.kbid,
      initialConversation: conversation,
    );
  }

  void _openSources() {
    AppNavigator.openKnowledgeBaseSources(
      context,
      kbid: widget.kbid,
    );
  }

  void _startNewConversation() {
    final prompt = _composerController.text.trim();
    final attachments = List<AttachmentInfo>.from(_pendingAttachments);
    _pendingAttachments.clear();

    if (prompt.isEmpty && attachments.isEmpty) return;

    final finalPrompt = prompt.isEmpty ? '请分析上传的图片' : prompt;
    final chatAttachments = attachments
        .map((a) => ChatAttachment(
              name: a.name,
              ossKey: a.ossKey,
              mimeType: a.mimeType,
              presignedUrl: a.presignedUrl,
            ))
        .toList();

    _composerController.clear();
    final chatService = ref.read(globalChatServiceProvider);
    final controller = ref.read(selectedLibraryControllerProvider.notifier);
    final kbid = widget.kbid;
    final nowLabel = _nowLabel();

    // 先用临时 ID 跳转到聊天页
    final tempId = 'creating-${DateTime.now().millisecondsSinceEpoch}';
    final tempPreview = KnowledgeConversationPreview(
      id: tempId,
      title: finalPrompt,
      preview: '正在创建会话…',
      dateLabel: nowLabel,
      messages: [
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.user,
          text: finalPrompt,
          attachments: chatAttachments,
        ),
        const KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '正在思考…',
        ),
      ],
    );
    _openConversation(tempPreview);

    // 异步创建真实会话（title 限制 255 字符，换行替换为空格）
    final safeTitle = _sanitizeChatTitle(finalPrompt);
    chatService.createChat(kbid: kbid, chatTitle: safeTitle).then((resp) {
      final chatId = resp.data?.chatId;
      if (chatId == null || chatId.isEmpty || !mounted) return;

      final realConversation = KnowledgeConversationPreview(
        id: chatId,
        title: finalPrompt,
        preview: '新对话已创建，正在围绕库中资料进行回答。',
        dateLabel: nowLabel,
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: finalPrompt,
            attachments: chatAttachments,
          ),
        ],
      );

      // ★ 立即插入到对话列表，用户返回时即可看到
      controller.addConversation(realConversation);

      // 替换路由为真实会话
      AppNavigator.popCurrent(context);
      AppNavigator.openKnowledgeBaseChat(
        context,
        kbid: kbid,
        initialConversation: realConversation,
      );
    }).catchError((_) {
      // 创建失败时 chat screen 仍显示临时状态，用户可重试
    });
  }

  void _startEmptyConversation() {
    final chatService = ref.read(globalChatServiceProvider);
    final controller = ref.read(selectedLibraryControllerProvider.notifier);
    final kbid = widget.kbid;
    final nowLabel = _nowLabel();

    final tempPreview = buildEmptyKnowledgeConversation(
      libraryTitle: ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? '',
    );
    _openConversation(tempPreview);

    chatService.createChat(kbid: kbid, chatTitle: '新的会话').then((resp) {
      final chatId = resp.data?.chatId;
      if (chatId == null || chatId.isEmpty || !mounted) return;

      final realConversation = KnowledgeConversationPreview(
        id: chatId,
        title: '新的会话',
        preview: '已进入新会话，可以直接围绕当前知识库继续提问。',
        dateLabel: nowLabel,
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '已为"${ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? ''}"新建会话。你可以直接提问，我会只基于当前知识库的资料继续回答。',
          ),
        ],
      );

      // ★ 立即插入到对话列表
      controller.addConversation(realConversation);

      AppNavigator.popCurrent(context);
      AppNavigator.openKnowledgeBaseChat(
        context,
        kbid: kbid,
        initialConversation: realConversation,
      );
    }).catchError((_) {});
  }

  /// 生成 "M月d日" 格式的时间标签（与后端 _buildDateLabel 一致）。
  String _nowLabel() {
    final now = DateTime.now();
    return '${now.month}月${now.day}日';
  }

  /// 将用户输入裁剪为合法的 chat_title（≤255 字符，换行替换为空格）。
  String _sanitizeChatTitle(String input) {
    var sanitized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.length > 255) {
      sanitized = sanitized.substring(0, 255);
    }
    return sanitized;
  }
}

class _ConversationPreviewCard extends StatelessWidget {
  const _ConversationPreviewCard({
    required this.conversation,
    required this.onTap,
  });

  final KnowledgeConversationPreview conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFCFEDFF), Colors.white],
        ),
        borderColor: AppColors.borderStrong,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    conversation.preview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              conversation.dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
