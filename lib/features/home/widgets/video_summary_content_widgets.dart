import 'package:flutter/material.dart';

import '../video_summary_models.dart';
import 'video_summary_draft_stage_workspace.dart';
import 'video_summary_final_chat_stage_workspace.dart';
import 'video_summary_processing_stage_workspace.dart';
import 'video_summary_ready_stage_workspace.dart';

class VideoSummaryWorkspace extends StatelessWidget {
  const VideoSummaryWorkspace({
    required this.stage,
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
    required this.preferenceController,
    required this.chatController,
    required this.draftBodyController,
    required this.processingExpanded,
    required this.isDraftEditMode,
    required this.isGenerating,
    required this.isSendingChat,
    required this.isTimestampScoped,
    required this.selectedTimestampLabel,
    required this.totalDurationSeconds,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.onUploadCardPressed,
    required this.onProcessingCardPressed,
    required this.onDraftEditModeChanged,
    required this.onStartPressed,
    required this.onGenerateFinalPressed,
    required this.onSendChatPressed,
    required this.onTimestampScopeChanged,
    required this.onTimestampRangeChanged,
    super.key,
  });

  final VideoSummaryStage stage;
  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
  final TextEditingController preferenceController;
  final TextEditingController chatController;
  final TextEditingController draftBodyController;
  final bool processingExpanded;
  final bool isDraftEditMode;
  final bool isGenerating;
  final bool isSendingChat;
  final bool isTimestampScoped;
  final String selectedTimestampLabel;
  final int totalDurationSeconds;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final VoidCallback onUploadCardPressed;
  final VoidCallback onProcessingCardPressed;
  final ValueChanged<bool> onDraftEditModeChanged;
  final VoidCallback? onStartPressed;
  final VoidCallback? onGenerateFinalPressed;
  final VoidCallback? onSendChatPressed;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<TimestampRangeSelection> onTimestampRangeChanged;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      VideoSummaryStage.ready => ReadyStageWorkspace(
        highlighted: highlighted,
        videoAsset: videoAsset,
        preferenceController: preferenceController,
        isGenerating: isGenerating,
        onUploadCardPressed: onUploadCardPressed,
        onStartPressed: onStartPressed,
      ),
      VideoSummaryStage.processing when processingSnapshot != null =>
        ProcessingStageWorkspace(
          highlighted: highlighted,
          videoAsset: videoAsset,
          processingSnapshot: processingSnapshot!,
          processingExpanded: processingExpanded,
          onProcessingCardPressed: onProcessingCardPressed,
        ),
      VideoSummaryStage.draft when draftResult != null => DraftStageWorkspace(
        highlighted: highlighted,
        videoAsset: videoAsset,
        draftResult: draftResult!,
        preferenceController: preferenceController,
        draftBodyController: draftBodyController,
        isDraftEditMode: isDraftEditMode,
        isGenerating: isGenerating,
        onUploadCardPressed: onUploadCardPressed,
        onDraftEditModeChanged: onDraftEditModeChanged,
        onGenerateFinalPressed: onGenerateFinalPressed,
      ),
      VideoSummaryStage.finalChat when finalSummaryData != null =>
        FinalChatStageWorkspace(
          highlighted: highlighted,
          videoAsset: videoAsset,
          finalSummaryData: finalSummaryData!,
          chatMessages: chatMessages,
          chatController: chatController,
          isSendingChat: isSendingChat,
          isTimestampScoped: isTimestampScoped,
          selectedTimestampLabel: selectedTimestampLabel,
          totalDurationSeconds: totalDurationSeconds,
          selectedTimestampStartSeconds: selectedTimestampStartSeconds,
          selectedTimestampEndSeconds: selectedTimestampEndSeconds,
          onUploadCardPressed: onUploadCardPressed,
          onSendChatPressed: onSendChatPressed,
          onTimestampScopeChanged: onTimestampScopeChanged,
          onTimestampRangeChanged: onTimestampRangeChanged,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
