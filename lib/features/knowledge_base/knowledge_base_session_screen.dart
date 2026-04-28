import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_card.dart';
import '../home/home_screen.dart';
import 'knowledge_base_chat_screen.dart';
import 'knowledge_base_models.dart';
import 'knowledge_base_sources_screen.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseSessionScreen extends StatefulWidget {
  const KnowledgeBaseSessionScreen({required this.library, super.key});

  final KnowledgeBaseLibrary library;

  @override
  State<KnowledgeBaseSessionScreen> createState() =>
      _KnowledgeBaseSessionScreenState();
}

class _KnowledgeBaseSessionScreenState
    extends State<KnowledgeBaseSessionScreen> {
  late final TextEditingController _composerController;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KnowledgeBaseTopBar(
                      title: widget.library.title,
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),
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
                            '查看 ${widget.library.sourceCount} 个来源',
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
                    ...widget.library.conversations.map(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: AppBottomNav(
                current: AppNavSection.knowledgeBase,
                onSelected: (section) {
                  switch (section) {
                    case AppNavSection.videoSummary:
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        HomeScreen.routeName,
                        (route) => false,
                      );
                    case AppNavSection.knowledgeBase:
                      Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConversation(KnowledgeConversationPreview conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeBaseChatScreen(
          library: widget.library,
          initialConversation: conversation,
        ),
      ),
    );
  }

  void _openSources() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeBaseSourcesScreen(library: widget.library),
      ),
    );
  }

  void _startNewConversation() {
    final prompt = _composerController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    _composerController.clear();
    final newConversation = KnowledgeConversationPreview(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      title: prompt,
      preview: '新对话已创建，正在围绕这组资料继续追问。',
      dateLabel: '刚刚',
      messages: [
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: prompt),
        const KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '好的，我会基于当前知识库里的资料来回答这个新问题。接下来可以继续追问、要结构化结论，或者指定要看的来源范围。',
        ),
      ],
    );

    _openConversation(newConversation);
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
