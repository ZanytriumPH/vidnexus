import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../home/home_screen.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseChatScreen extends StatefulWidget {
  const KnowledgeBaseChatScreen({
    required this.library,
    required this.initialConversation,
    super.key,
  });

  final KnowledgeBaseLibrary library;
  final KnowledgeConversationPreview initialConversation;

  @override
  State<KnowledgeBaseChatScreen> createState() =>
      _KnowledgeBaseChatScreenState();
}

class _KnowledgeBaseChatScreenState extends State<KnowledgeBaseChatScreen> {
  late final TextEditingController _composerController;
  late List<KnowledgeChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _messages = List<KnowledgeChatMessage>.from(
      widget.initialConversation.messages,
    );
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: KnowledgeBaseTopBar(
                currentSection: AppNavSection.knowledgeBase,
                onSectionSelected: (section) {
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
                title: widget.library.title,
                onLeadingPressed: () => Navigator.of(context).pop(),
                trailing: InkWell(
                  onTap: _startEmptyConversation,
                  borderRadius: BorderRadius.circular(17.5),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17.5),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _KnowledgeChatBubble(message: message);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: KnowledgeBaseComposer(
                controller: _composerController,
                onSubmit: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: text),
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '我会基于“${widget.library.title}”里的资料继续回答：$text',
        ),
      ];
      _composerController.clear();
    });
  }

  void _startEmptyConversation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeBaseChatScreen(
          library: widget.library,
          initialConversation: buildEmptyKnowledgeConversation(
            libraryTitle: widget.library.title,
          ),
        ),
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

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 351),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        message.text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.35,
        ),
      ),
    );
  }
}
