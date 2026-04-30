import 'package:flutter/material.dart';

import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'video_summary_final_chat_widgets.dart';
import 'video_summary_processing_widgets.dart';

class FinalChatStageWorkspace extends StatefulWidget {
  const FinalChatStageWorkspace({
    required this.highlighted,
    required this.videoAsset,
    required this.finalSummaryData,
    required this.chatMessages,
    required this.chatController,
    required this.isSendingChat,
    required this.isTimestampScoped,
    required this.selectedTimestampLabel,
    required this.totalDurationSeconds,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.onUploadCardPressed,
    required this.onSendChatPressed,
    required this.onTimestampScopeChanged,
    required this.onTimestampRangeChanged,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final FinalSummaryData finalSummaryData;
  final List<ChatMessage> chatMessages;
  final TextEditingController chatController;
  final bool isSendingChat;
  final bool isTimestampScoped;
  final String selectedTimestampLabel;
  final int totalDurationSeconds;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final VoidCallback onUploadCardPressed;
  final VoidCallback? onSendChatPressed;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<TimestampRangeSelection> onTimestampRangeChanged;

  @override
  State<FinalChatStageWorkspace> createState() =>
      _FinalChatStageWorkspaceState();
}

class _FinalChatStageWorkspaceState extends State<FinalChatStageWorkspace> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(FinalChatStageWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatMessages.length != oldWidget.chatMessages.length) {
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    FocusScope.of(context).unfocus();
    widget.onSendChatPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroCard(
                  stage: VideoSummaryStage.finalChat,
                  highlighted: widget.highlighted,
                  videoAsset: widget.videoAsset,
                  processingSnapshot: null,
                  processingExpanded: false,
                  onTap: widget.onUploadCardPressed,
                ),
                const SizedBox(height: 12),
                ChatThread(
                  summary: widget.finalSummaryData,
                  messages: widget.chatMessages,
                ),
                if (widget.chatMessages.isNotEmpty) const MessageActionRow(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ChatComposer(
          controller: widget.chatController,
          isSending: widget.isSendingChat,
          isTimestampScoped: widget.isTimestampScoped,
          selectedTimestampLabel: widget.selectedTimestampLabel,
          totalDurationSeconds: widget.totalDurationSeconds,
          selectedTimestampStartSeconds: widget.selectedTimestampStartSeconds,
          selectedTimestampEndSeconds: widget.selectedTimestampEndSeconds,
          onTimestampScopeChanged: widget.onTimestampScopeChanged,
          onTimestampRangeChanged: widget.onTimestampRangeChanged,
          onSendPressed: widget.onSendChatPressed != null ? _handleSend : null,
        ),
      ],
    );
  }
}