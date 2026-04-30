import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_header_add_button.dart';
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
    required this.selectedTimestampLabel,
    required this.totalDurationSeconds,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.onTimestampScopeChanged,
    required this.onTimestampRangeChanged,
    required this.onSendPressed,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isTimestampScoped;
  final String selectedTimestampLabel;
  final int totalDurationSeconds;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<TimestampRangeSelection> onTimestampRangeChanged;
  final VoidCallback? onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '继续追问这段总结...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                ),
                style: context.appTextStyles.summaryContentBody,
                textAlignVertical: TextAlignVertical.top,
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final hasInput = value.text.trim().isNotEmpty;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _TimestampScopeActionButton(
                        enabled: isTimestampScoped,
                        selectedLabel: selectedTimestampLabel,
                        totalDurationSeconds: totalDurationSeconds,
                        selectedStartSeconds: selectedTimestampStartSeconds,
                        selectedEndSeconds: selectedTimestampEndSeconds,
                        onEnabledChanged: onTimestampScopeChanged,
                        onRangeChanged: onTimestampRangeChanged,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ComposerAttachmentButton(onPressed: () => _showAttachmentOptions(context)),
                  if (hasInput) ...[
                    const SizedBox(width: 8),
                    _ComposerSendButton(
                      isSending: isSending,
                      onPressed: onSendPressed,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAttachmentOptions(BuildContext context) async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加内容',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _AttachmentActionTile(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照',
                  onTap: () => Navigator.of(context).pop(_AttachmentAction.camera),
                ),
                const SizedBox(height: 8),
                _AttachmentActionTile(
                  icon: Icons.photo_library_outlined,
                  label: '相册',
                  onTap: () => Navigator.of(context).pop(_AttachmentAction.gallery),
                ),
                const SizedBox(height: 8),
                _AttachmentActionTile(
                  icon: Icons.insert_drive_file_outlined,
                  label: '文件',
                  onTap: () => Navigator.of(context).pop(_AttachmentAction.file),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) {
      return;
    }

    final message = switch (action) {
      _AttachmentAction.camera => '拍照功能将在下一阶段接入。',
      _AttachmentAction.gallery => '相册功能将在下一阶段接入。',
      _AttachmentAction.file => '文件功能将在下一阶段接入。',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ComposerAttachmentButton extends StatelessWidget {
  const _ComposerAttachmentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppHeaderAddButton(onPressed: onPressed);
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.isSending,
    required this.onPressed,
  });

  final bool isSending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: isSending
            ? const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                size: 15,
                color: Colors.white,
              ),
      ),
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7DFE7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimestampScopeActionButton extends StatelessWidget {
  const _TimestampScopeActionButton({
    required this.enabled,
    required this.selectedLabel,
    required this.totalDurationSeconds,
    required this.selectedStartSeconds,
    required this.selectedEndSeconds,
    required this.onEnabledChanged,
    required this.onRangeChanged,
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
    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE8F0FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFFBFD1FF) : const Color(0xFFD7DFE7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: enabled ? const Color(0xFF2B63EB) : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                enabled ? '时间区间  $selectedLabel' : '时间区间',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? const Color(0xFF2B63EB) : AppColors.textPrimary,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (!enabled) {
      await _showIntervalPicker(context);
      return;
    }

    final action = await showModalBottomSheet<_TimestampAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '时间区间已启用',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _TimestampActionTile(
                  icon: Icons.edit_outlined,
                  label: '修改时间区间',
                  onTap: () => Navigator.of(context).pop(_TimestampAction.edit),
                ),
                const SizedBox(height: 8),
                _TimestampActionTile(
                  icon: Icons.close_rounded,
                  label: '关闭时间区间',
                  onTap: () => Navigator.of(context).pop(_TimestampAction.disable),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == _TimestampAction.edit) {
      if (!context.mounted) {
        return;
      }
      await _showIntervalPicker(context);
      return;
    }

    if (action == _TimestampAction.disable) {
      onEnabledChanged(false);
    }
  }

  Future<void> _showIntervalPicker(BuildContext context) async {
    await showTimestampIntervalPickerSheet(
      context: context,
      initialStartSeconds: selectedStartSeconds,
      initialEndSeconds: selectedEndSeconds,
      totalDurationSeconds: totalDurationSeconds,
      onRangeChanged: (range) {
        onRangeChanged(range);
        onEnabledChanged(true);
      },
    );
  }
}

class _TimestampActionTile extends StatelessWidget {
  const _TimestampActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7DFE7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TimestampAction { edit, disable }

enum _AttachmentAction { camera, gallery, file }
