import 'package:flutter/material.dart';

import '../../app/routing/app_route_arguments.dart';
import '../../app/routing/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_markdown_body.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
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
  final ScrollController _scrollController = ScrollController();
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
                title: widget.library.title,
                onLeadingPressed: () => AppNavigator.popCurrent(context),
                trailing: AppHeaderAddButton(onPressed: _startEmptyConversation),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => SizedBox(
                  height: context.appMessageStyles.messageSpacing,
                ),
                itemBuilder: (context, index) {
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

    FocusScope.of(context).unfocus();
    setState(() {
      _messages = [
        ..._messages,
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: text),
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '我会基于"${widget.library.title}"里的资料继续回答：$text',
        ),
      ];
      _composerController.clear();
    });
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

  void _startEmptyConversation() {
    AppNavigator.openKnowledgeBaseChat(
      context,
      arguments: KnowledgeBaseChatRouteArguments(
        library: widget.library,
        initialConversation: buildEmptyKnowledgeConversation(
          libraryTitle: widget.library.title,
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
