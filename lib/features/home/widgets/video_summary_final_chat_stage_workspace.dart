import 'package:flutter/material.dart';

import '../../../../app/widgets/app_typing_indicator.dart';
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
    this.onCloneToKbPressed,
    this.onVideoPlayback,
    this.isGenerating = false,
    this.finalDraftProgressMessage,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final FinalSummaryData? finalSummaryData;
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
  final VoidCallback? onCloneToKbPressed;
  final VoidCallback? onVideoPlayback;
  final bool isGenerating;
  final String? finalDraftProgressMessage;

  @override
  State<FinalChatStageWorkspace> createState() =>
      _FinalChatStageWorkspaceState();
}

class _FinalChatStageWorkspaceState extends State<FinalChatStageWorkspace>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _keyboardWasVisible = false;

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (_keyboardWasVisible && !isKeyboardVisible) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _keyboardWasVisible = isKeyboardVisible;
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    FocusScope.of(context).unfocus();
    widget.onSendChatPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    // ★ 生成中：只显示 HeroCard + AI 思考动画，无正文卡片、无追问输入框
    if (widget.isGenerating) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroCard(
              stage: VideoSummaryStage.finalChat,
              highlighted: widget.highlighted,
              videoAsset: widget.videoAsset,
              processingSnapshot: null,
              processingExpanded: false,
              isFinalGenerating: true,
              finalDraftProgressMessage: widget.finalDraftProgressMessage,
              onTap: null,
              onVideoPlayback: widget.onVideoPlayback,
            ),
            const SizedBox(height: 12),
            const AppTypingIndicator(),
          ],
        ),
      );
    }

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
                  onTap: null,
                  onVideoPlayback: widget.onVideoPlayback,
                ),
                const SizedBox(height: 12),
                ChatThread(
                  summary: widget.finalSummaryData!,
                  messages: widget.chatMessages,
                  onCloneToKbPressed: widget.onCloneToKbPressed,
                  isWaiting: widget.isSendingChat,
                ),
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
