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
              child: _SummaryChatBubble(message: message),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryChatBubble extends StatelessWidget {
  const _SummaryChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == SummaryChatSender.user;

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
          child: _SummaryChatBubbleBody(message: message),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: _SummaryChatBubbleBody(message: message),
    );
  }
}

class _SummaryChatBubbleBody extends StatelessWidget {
  const _SummaryChatBubbleBody({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.55,
            color: AppColors.textPrimary,
          ),
        ),
        if (message.timestampLabel != null) ...[
          const SizedBox(height: 10),
          Text(
            message.timestampLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: AppColors.textHint,
            ),
          ),
        ],
      ],
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
    required this.enabled,
    required this.selectedLabel,
    required this.totalDurationSeconds,
    required this.selectedStartSeconds,
    required this.selectedEndSeconds,
    required this.onEnabledChanged,
    required this.onRangeChanged,
    super.key,
  });

  final bool enabled;
  final String selectedLabel;
  final int totalDurationSeconds;
  final int selectedStartSeconds;
  final int selectedEndSeconds;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<TimestampRangeSelection> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '时间区间追问，发送时附加这段片段',
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
        if (enabled) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showIntervalPicker(context),
            borderRadius: BorderRadius.circular(18),
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
                      Icons.schedule_rounded,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedLabel,
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
      ],
    );
  }

  Future<void> _showIntervalPicker(BuildContext context) async {
    var draftStart = selectedStartSeconds.toDouble();
    var draftEnd = selectedEndSeconds.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final currentSeconds = (draftEnd - draftStart).round();

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义时间区间',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '用户可自由设置开始和结束时间，最短 10 秒，最长不超过视频总长度。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD7DFE7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatClockLabel(draftStart.round())} - ${_formatClockLabel(draftEnd.round())}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前区间长度 ${_formatRangeLength(currentSeconds)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RangeSlider(
                            values: RangeValues(draftStart, draftEnd),
                            min: 0,
                            max: totalDurationSeconds.toDouble(),
                            divisions: totalDurationSeconds,
                            activeColor: const Color(0xFF2B63EB),
                            inactiveColor: const Color(0xFFDCE6FA),
                            labels: RangeLabels(
                              _formatClockLabel(draftStart.round()),
                              _formatClockLabel(draftEnd.round()),
                            ),
                            onChanged: (values) {
                              var nextStart = values.start.round();
                              var nextEnd = values.end.round();

                              if (nextEnd - nextStart < 10) {
                                if ((nextStart - draftStart).abs() >
                                    (nextEnd - draftEnd).abs()) {
                                  nextStart = nextEnd - 10;
                                } else {
                                  nextEnd = nextStart + 10;
                                }
                              }

                              nextStart = nextStart.clamp(0, totalDurationSeconds - 10);
                              nextEnd = nextEnd.clamp(nextStart + 10, totalDurationSeconds);

                              setModalState(() {
                                draftStart = nextStart.toDouble();
                                draftEnd = nextEnd.toDouble();
                              });
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _RangeValueTile(
                                  label: '开始',
                                  value: _formatClockLabel(draftStart.round()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _RangeValueTile(
                                  label: '结束',
                                  value: _formatClockLabel(draftEnd.round()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: '应用这个时间区间',
                      onPressed: () {
                        onRangeChanged(
                          TimestampRangeSelection(
                            startSeconds: draftStart.round(),
                            endSeconds: draftEnd.round(),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatClockLabel(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRangeLength(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '$seconds秒';
    }
    if (seconds == 0) {
      return '$minutes分';
    }
    return '$minutes分$seconds秒';
  }
}

class _RangeValueTile extends StatelessWidget {
  const _RangeValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class TimestampRangeSelection {
  const TimestampRangeSelection({
    required this.startSeconds,
    required this.endSeconds,
  });

  final int startSeconds;
  final int endSeconds;
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
