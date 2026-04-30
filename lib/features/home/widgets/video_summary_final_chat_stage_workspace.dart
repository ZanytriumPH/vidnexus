import 'package:flutter/material.dart';

import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'video_summary_final_chat_widgets.dart';
import 'video_summary_processing_widgets.dart';

class FinalChatStageWorkspace extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroCard(
                  stage: VideoSummaryStage.finalChat,
                  highlighted: highlighted,
                  videoAsset: videoAsset,
                  processingSnapshot: null,
                  processingExpanded: false,
                  onTap: onUploadCardPressed,
                ),
                const SizedBox(height: 12),
                ChatThread(summary: finalSummaryData, messages: chatMessages),
                if (chatMessages.isNotEmpty) const MessageActionRow(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ChatComposer(
          controller: chatController,
          isSending: isSendingChat,
          isTimestampScoped: isTimestampScoped,
          selectedTimestampLabel: selectedTimestampLabel,
          totalDurationSeconds: totalDurationSeconds,
          selectedTimestampStartSeconds: selectedTimestampStartSeconds,
          selectedTimestampEndSeconds: selectedTimestampEndSeconds,
          onTimestampScopeChanged: onTimestampScopeChanged,
          onTimestampRangeChanged: onTimestampRangeChanged,
          onSendPressed: onSendChatPressed,
        ),
      ],
    );
  }
}