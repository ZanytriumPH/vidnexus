import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import 'home_shell_widgets.dart';
import 'video_summary_final_chat_widgets.dart';
import 'video_summary_processing_widgets.dart';

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
    final children = <Widget>[
      HeroCard(
        stage: stage,
        highlighted: highlighted,
        videoAsset: videoAsset,
        processingSnapshot: processingSnapshot,
        processingExpanded: processingExpanded,
        onTap: stage == VideoSummaryStage.processing
            ? onProcessingCardPressed
            : onUploadCardPressed,
      ),
    ];

    if (stage == VideoSummaryStage.ready) {
      children.addAll([
        const SizedBox(height: 24),
        Text(
          '总结偏好（可选）',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        PreferenceCard(
          controller: preferenceController,
          hintText: '例如：请先给我按行业、声线和行动建议展开。',
          prominent: true,
        ),
        const SizedBox(height: 24),
        ReadyPrimaryButton(
          label: isGenerating ? '正在生成中...' : '开始生成初稿',
          onPressed: onStartPressed,
        ),
      ]);
    }

    if (stage == VideoSummaryStage.processing && processingSnapshot != null) {
      children.addAll([
        const SizedBox(height: 12),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: processingExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: ProcessingDetailCard(snapshot: processingSnapshot!),
          secondChild: const ProcessingCollapsedHintCard(),
        ),
      ]);
    }

    if (stage == VideoSummaryStage.draft && draftResult != null) {
      children.addAll([
        const SizedBox(height: 12),
        DraftBodyCard(
          draft: draftResult!,
          draftBodyController: draftBodyController,
          isEditMode: isDraftEditMode,
          onModeChanged: onDraftEditModeChanged,
        ),
        const SizedBox(height: 10),
        const SectionLabel(title: '总结指导（可选）', centered: false),
        const SizedBox(height: 6),
        PreferenceCard(
          controller: preferenceController,
          hintText: draftResult!.suggestionHint,
          singleLine: true,
        ),
        const SizedBox(height: 14),
        AppPrimaryButton(
          label: isGenerating ? '正在整理最终稿...' : '生成最终稿',
          onPressed: onGenerateFinalPressed,
        ),
      ]);
    }

    if (stage == VideoSummaryStage.finalChat && finalSummaryData != null) {
      children.addAll([
        const SizedBox(height: 12),
        FinalSummaryCard(summary: finalSummaryData!),
        const SizedBox(height: 10),
        ChatThread(messages: chatMessages),
        const SizedBox(height: 0),
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
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class ReadyPrimaryButton extends StatelessWidget {
  const ReadyPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x261B55D9),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F69E8),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF8AAEF6),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class DraftBodyCard extends StatelessWidget {
  const DraftBodyCard({
    required this.draft,
    required this.draftBodyController,
    required this.isEditMode,
    required this.onModeChanged,
    super.key,
  });

  final DraftResult draft;
  final TextEditingController draftBodyController;
  final bool isEditMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '初稿正文',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              MiniTab(
                active: isEditMode,
                label: '编辑',
                onTap: () => onModeChanged(true),
              ),
              const SizedBox(width: 6),
              MiniTab(
                active: !isEditMode,
                label: '预览',
                onTap: () => onModeChanged(false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '可复制出口到其它模式，连续阅读再补上下文。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6DEE6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEditMode)
                  TextField(
                    controller: draftBodyController,
                    maxLines: null,
                    minLines: 6,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      height: 1.55,
                      color: AppColors.textPrimary,
                    ),
                  )
                else
                  Text(
                    draftBodyController.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  draft.overview,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '当前版本：结构稿',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
              ),
              const Spacer(),
              Text(
                '切换预览后自动接入几次指令细节层',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniTab extends StatelessWidget {
  const MiniTab({
    required this.active,
    required this.label,
    this.onTap,
    super.key,
  });

  final bool active;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E2430) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
