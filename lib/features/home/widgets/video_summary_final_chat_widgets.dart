import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'timestamp_interval_picker_sheet.dart';

class ChatThread extends StatelessWidget {
  const ChatThread({
    required this.summary,
    required this.messages,
    super.key,
  });

  final FinalSummaryData summary;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final messageStyles = context.appMessageStyles;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
          child: _FinalSummaryBubble(summary: summary),
        ),
        ...messages.map(
          (message) => Padding(
            padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
            child: _SummaryChatBubble(message: message),
          ),
        ),
      ],
    );
  }
}

class _FinalSummaryBubble extends StatelessWidget {
  const _FinalSummaryBubble({required this.summary});

  final FinalSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final messageStyles = context.appMessageStyles;

    return Container(
      width: double.infinity,
      padding: messageStyles.finalPadding,
      decoration: BoxDecoration(
        color: messageStyles.finalSurface,
        borderRadius: BorderRadius.circular(messageStyles.chatBubbleRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summary.summaryTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF275FD8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: messageStyles.messageSpacing),
          Text(
            summary.summaryBody,
            style: context.appTextStyles.summaryContentBody,
          ),
        ],
      ),
    );
  }
}

class _SummaryChatBubble extends StatelessWidget {
  const _SummaryChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == SummaryChatSender.user;
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
          child: _SummaryChatBubbleBody(message: message),
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
          style: context.appTextStyles.summaryContentBody,
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

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.isSending,
    required this.isTimestampScoped,
    required this.onTimestampScopeChanged,
    required this.onSendPressed,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isTimestampScoped;
  final ValueChanged<bool> onTimestampScopeChanged;
  final VoidCallback? onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '继续追问这段总结...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TimestampScopeToggleButton(
                enabled: isTimestampScoped,
                onTap: () => onTimestampScopeChanged(!isTimestampScoped),
              ),
              const Spacer(),
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
        ],
      ),
    );
  }
}

class TimestampRangePickerBar extends StatelessWidget {
  const TimestampRangePickerBar({
    required this.selectedLabel,
    required this.totalDurationSeconds,
    required this.selectedStartSeconds,
    required this.selectedEndSeconds,
    required this.onRangeChanged,
    super.key,
  });

  final String selectedLabel;
  final int totalDurationSeconds;
  final int selectedStartSeconds;
  final int selectedEndSeconds;
  final ValueChanged<TimestampRangeSelection> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }

  Future<void> _showIntervalPicker(BuildContext context) async {
    await showTimestampIntervalPickerSheet(
      context: context,
      initialStartSeconds: selectedStartSeconds,
      initialEndSeconds: selectedEndSeconds,
      totalDurationSeconds: totalDurationSeconds,
      onRangeChanged: onRangeChanged,
    );
  }
}

class _TimestampScopeToggleButton extends StatelessWidget {
  const _TimestampScopeToggleButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE8F0FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFFBFD1FF) : const Color(0xFFD7DFE7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: enabled ? const Color(0xFF2B63EB) : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '时间区间',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enabled ? const Color(0xFF2B63EB) : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
