import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import 'home_shell_widgets.dart';
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
    required this.processingExpanded,
    required this.isGenerating,
    required this.isSendingChat,
    required this.isTimestampScoped,
    required this.selectedTimestampIndex,
    required this.onUploadCardPressed,
    required this.onProcessingCardPressed,
    required this.onStartPressed,
    required this.onGenerateFinalPressed,
    required this.onSendChatPressed,
    required this.onTimestampScopeChanged,
    required this.onTimestampSelected,
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
  final bool processingExpanded;
  final bool isGenerating;
  final bool isSendingChat;
  final bool isTimestampScoped;
  final int selectedTimestampIndex;
  final VoidCallback onUploadCardPressed;
  final VoidCallback onProcessingCardPressed;
  final VoidCallback? onStartPressed;
  final VoidCallback? onGenerateFinalPressed;
  final VoidCallback? onSendChatPressed;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<int> onTimestampSelected;

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
        const SizedBox(height: 18),
        const SectionLabel(title: '总结指导（可选）', centered: false),
        const SizedBox(height: 6),
        PreferenceCard(
          controller: preferenceController,
          hintText: '例如：请先给我按行业、声线和行动建议展开。',
        ),
        const SizedBox(height: 16),
        AppPrimaryButton(
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
        DraftBodyCard(draft: draftResult!),
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
        const SizedBox(height: 10),
        const MessageActionRow(),
        const SizedBox(height: 12),
        TimestampSection(
          chips: finalSummaryData!.timestampChips,
          enabled: isTimestampScoped,
          selectedIndex: selectedTimestampIndex,
          onEnabledChanged: onTimestampScopeChanged,
          onSelected: onTimestampSelected,
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

class DraftBodyCard extends StatelessWidget {
  const DraftBodyCard({required this.draft, super.key});

  final DraftResult draft;

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
                  '聚合稿正文',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const MiniTab(active: true, label: '编辑'),
              const SizedBox(width: 6),
              const MiniTab(active: false, label: '预览'),
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
                Text(
                  draft.paragraphs.join('\n\n'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.55),
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
  const MiniTab({required this.active, required this.label, super.key});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class FinalSummaryCard extends StatelessWidget {
  const FinalSummaryCard({required this.summary, super.key});

  final FinalSummaryData summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.summaryTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DFE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.summaryBody,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.55),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    summary.summaryTimestampLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatThread extends StatelessWidget {
  const ChatThread({required this.messages, super.key});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages
          .map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: message.sender == SummaryChatSender.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: message.sender == SummaryChatSender.user ? 290 : 320,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD7DFE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                      if (message.timestampLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          message.timestampLabel!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 9,
                                color: AppColors.textHint,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class MessageActionRow extends StatelessWidget {
  const MessageActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ActionIconButton(icon: Icons.copy_all_outlined),
        SizedBox(width: 6),
        ActionIconButton(icon: Icons.note_alt_outlined),
        SizedBox(width: 6),
        ActionIconButton(icon: Icons.image_outlined),
        SizedBox(width: 6),
        ActionIconButton(icon: Icons.photo_outlined),
      ],
    );
  }
}

class ActionIconButton extends StatelessWidget {
  const ActionIconButton({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    );
  }
}

class TimestampSection extends StatelessWidget {
  const TimestampSection({
    required this.chips,
    required this.enabled,
    required this.selectedIndex,
    required this.onEnabledChanged,
    required this.onSelected,
    super.key,
  });

  final List<TimestampChipData> chips;
  final bool enabled;
  final int selectedIndex;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '时间戳追问，发送时附加这段片段',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: enabled,
                onChanged: onEnabledChanged,
                activeTrackColor: const Color(0xFF2B63EB),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD8DEE7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled
              ? () => onSelected((selectedIndex + 1) % chips.length)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7DFE7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFD7DFE7)),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chips[selectedIndex].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FA8B7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSendPressed,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback? onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '继续追问这段总结...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSendPressed,
              padding: EdgeInsets.zero,
              icon: isSending
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
