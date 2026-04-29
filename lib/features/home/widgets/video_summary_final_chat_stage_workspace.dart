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
        HeroCard(
          stage: VideoSummaryStage.finalChat,
          highlighted: highlighted,
          videoAsset: videoAsset,
          processingSnapshot: null,
          processingExpanded: false,
          onTap: onUploadCardPressed,
        ),
        const SizedBox(height: 12),
        FinalSummaryCard(summary: finalSummaryData),
        const SizedBox(height: 10),
        ChatThread(messages: chatMessages),
        const MessageActionRow(),
        const SizedBox(height: 12),
        TimestampSection(
          enabled: isTimestampScoped,
          selectedLabel: selectedTimestampLabel,
          totalDurationSeconds: totalDurationSeconds,
          selectedStartSeconds: selectedTimestampStartSeconds,
          selectedEndSeconds: selectedTimestampEndSeconds,
          onEnabledChanged: onTimestampScopeChanged,
          onRangeChanged: onTimestampRangeChanged,
        ),
        const SizedBox(height: 10),
        ChatComposer(
          controller: chatController,
          isSending: isSendingChat,
          onSendPressed: onSendChatPressed,
        ),
      ],
    );
  }
}