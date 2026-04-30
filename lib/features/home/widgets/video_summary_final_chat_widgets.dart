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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FinalSummaryBubble(summary: summary),
        ),
        ...messages.map(
          (message) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7DFE7)),
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
          const SizedBox(height: 10),
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
                  fontSize: 13,
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
    await showTimestampIntervalPickerSheet(
      context: context,
      initialStartSeconds: selectedStartSeconds,
      initialEndSeconds: selectedEndSeconds,
      totalDurationSeconds: totalDurationSeconds,
      onRangeChanged: onRangeChanged,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
              ),
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