import 'package:flutter/material.dart';

import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import '../application/video_summary_result_mapper.dart';
import 'video_summary_draft_stage_workspace.dart';
import 'video_summary_final_chat_stage_workspace.dart';
import 'video_summary_processing_stage_workspace.dart';
import 'video_summary_ready_stage_workspace.dart';

/// 这是页面内部的“阶段分发器”，只根据 stage 决定显示哪个 workspace。
class VideoSummaryWorkspace extends StatelessWidget {
  const VideoSummaryWorkspace({
    required this.stage,
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
    required this.draftGuidanceController,
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
    required this.onGenerateFinalPressed,
    required this.onSendChatPressed,
    required this.onTimestampScopeChanged,
    required this.onTimestampRangeChanged,
    required this.isUploading,
    required this.uploadProgress,
    this.finalDraftProgressMessage,
    this.onCloneToKbPressed,
    this.onVideoPlayback,
    this.onRefreshPressed,
    super.key,
  });

  final VideoSummaryStage stage;
  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
  final TextEditingController draftGuidanceController;
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
  final VoidCallback? onGenerateFinalPressed;
  final VoidCallback? onSendChatPressed;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<TimestampRangeSelection> onTimestampRangeChanged;
  final bool isUploading;
  final double uploadProgress;
  final String? finalDraftProgressMessage;
  final VoidCallback? onCloneToKbPressed;
  final VoidCallback? onVideoPlayback;
  final VoidCallback? onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      VideoSummaryStage.ready => ReadyStageWorkspace(
        highlighted: highlighted,
        videoAsset: videoAsset,
        isGenerating: isGenerating,
        onUploadCardPressed: onUploadCardPressed,
        isUploading: isUploading,
        uploadProgress: uploadProgress,
      ),
      VideoSummaryStage.processing => ProcessingStageWorkspace(
        highlighted: highlighted,
        videoAsset: videoAsset,
        processingSnapshot:
            processingSnapshot ?? buildInitialProcessingSnapshot(),
        processingExpanded: processingExpanded,
        onProcessingCardPressed: onProcessingCardPressed,
        onRefreshPressed: onRefreshPressed,
      ),
      VideoSummaryStage.draft when draftResult != null => DraftStageWorkspace(
        highlighted: highlighted,
        videoAsset: videoAsset,
        draftResult: draftResult!,
        guidanceController: draftGuidanceController,
        draftBodyController: draftBodyController,
        isDraftEditMode: isDraftEditMode,
        isGenerating: isGenerating,
        onUploadCardPressed: onUploadCardPressed,
        onDraftEditModeChanged: onDraftEditModeChanged,
        onGenerateFinalPressed: onGenerateFinalPressed,
        onVideoPlayback: onVideoPlayback,
      ),
      VideoSummaryStage.finalChat
          when finalSummaryData != null || isGenerating =>
        FinalChatStageWorkspace(
          highlighted: highlighted,
          videoAsset: videoAsset,
          finalSummaryData: finalSummaryData,
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
          onCloneToKbPressed: onCloneToKbPressed,
          onVideoPlayback: onVideoPlayback,
          isGenerating: isGenerating,
          finalDraftProgressMessage: finalDraftProgressMessage,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
