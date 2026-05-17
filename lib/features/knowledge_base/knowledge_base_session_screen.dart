import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../app/widgets/app_card.dart';
import '../../services/service_providers.dart';
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
                            '历史对话',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (library.conversations.isEmpty)
                            Text(
                              '暂无对话',
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
    if (prompt.isEmpty) {
      return;
    }

    _composerController.clear();
    final chatService = ref.read(globalChatServiceProvider);
    final kbid = widget.kbid;

    // 先跳转到加载态，再异步创建真实会话
    final tempPreview = KnowledgeConversationPreview(
      id: 'creating-${DateTime.now().millisecondsSinceEpoch}',
      title: prompt,
      preview: '正在创建会话…',
      dateLabel: '刚刚',
      messages: [
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: prompt),
        const KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '正在思考…',
        ),
      ],
    );
    _openConversation(tempPreview);

    // 异步创建真实会话并通知 chat screen 刷新
    chatService.createChat(kbid: kbid, chatTitle: prompt).then((resp) {
      final chatId = resp.data?.chatId;
      if (chatId != null && chatId.isNotEmpty && mounted) {
        // chat screen 已通过 initialConversation.id 获取到临时 ID，
        // 此处通过 Controller 通知更新 chatId 并自动触发首次 QA。
        // 为简单起见，我们用 pushReplacement 替换路由。
        final realConversation = KnowledgeConversationPreview(
          id: chatId,
          title: prompt,
          preview: '新对话已创建，正在围绕这组资料继续追问。',
          dateLabel: '刚刚',
          messages: [
            KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: prompt),
          ],
        );
        AppNavigator.popCurrent(context);
        AppNavigator.openKnowledgeBaseChat(
          context,
          kbid: kbid,
          initialConversation: realConversation,
        );
      }
    }).catchError((_) {
      // 创建失败时 chat screen 仍显示临时状态，用户可重试
    });
  }

  void _startEmptyConversation() {
    final chatService = ref.read(globalChatServiceProvider);
    final kbid = widget.kbid;

    final tempPreview = buildEmptyKnowledgeConversation(
      libraryTitle: ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? '',
    );
    _openConversation(tempPreview);

    chatService.createChat(kbid: kbid, chatTitle: '新的会话').then((resp) {
      final chatId = resp.data?.chatId;
      if (chatId != null && chatId.isNotEmpty && mounted) {
        final realConversation = KnowledgeConversationPreview(
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
        AppNavigator.popCurrent(context);
        AppNavigator.openKnowledgeBaseChat(
          context,
          kbid: kbid,
          initialConversation: realConversation,
        );
      }
    }).catchError((_) {});
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
                  ),
                  const SizedBox(height: 6),
                  Text(
                    conversation.preview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
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
