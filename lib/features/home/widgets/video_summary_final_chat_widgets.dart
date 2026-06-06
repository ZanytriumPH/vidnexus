import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/composer_attachment_button.dart';
import '../../../services/service_providers.dart';
import '../../knowledge_base/application/knowledge_base_controller.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'timestamp_interval_picker_sheet.dart';
import 'video_summary_markdown_body.dart';

class ChatThread extends StatelessWidget {
  const ChatThread({
    required this.summary,
    required this.messages,
    this.onAddToKbPressed,
    this.isWaiting = false,
    super.key,
  });

  final FinalSummaryData summary;
  final List<ChatMessage> messages;
  final VoidCallback? onAddToKbPressed;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    final messageStyles = context.appMessageStyles;
    // 空系统消息不渲染（此时 typing indicator 正在展示）
    final visibleMessages = messages.where((m) =>
        m.sender == SummaryChatSender.user || m.text.isNotEmpty);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
          child: _FinalSummaryBubble(
            summary: summary,
            onAddToKbPressed: onAddToKbPressed,
          ),
        ),
        ...visibleMessages.map(
          (message) => Padding(
            padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
            child: _SummaryChatBubble(message: message),
          ),
        ),
        if (isWaiting)
          const _SummaryTypingIndicator(),
      ],
    );
  }
}

class _FinalSummaryBubble extends StatelessWidget {
  const _FinalSummaryBubble({
    required this.summary,
    this.onAddToKbPressed,
  });

  final FinalSummaryData summary;
  final VoidCallback? onAddToKbPressed;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summary.summaryTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF275FD8),
                  ),
                ),
              ),
              const Spacer(),
              if (onAddToKbPressed != null) ...[
                _AddToKbButton(onPressed: onAddToKbPressed),
                const SizedBox(width: 6),
              ],
            ],
          ),
          SizedBox(height: messageStyles.messageSpacing),
          VideoSummaryMarkdownBody(
            data: summary.summaryBody,
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
    final bool isSystemMessage = message.sender == SummaryChatSender.system;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSystemMessage)
          VideoSummaryMarkdownBody(data: message.text)
        else
          Text(message.text, style: context.appTextStyles.summaryContentBody),
        if (message.timestampLabel != null) ...[
          const SizedBox(height: 10),
          Text(
            message.timestampLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: AppColors.textHint,
            ),
          ),
        ],
        if (message.citations != null && message.citations!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _VideoCitationSection(citations: message.citations!),
        ],
      ],
    );
  }
}

class _VideoCitationSection extends StatefulWidget {
  const _VideoCitationSection({required this.citations});

  final List<ChatMessageCitation> citations;

  @override
  State<_VideoCitationSection> createState() => _VideoCitationSectionState();
}

class _VideoCitationSectionState extends State<_VideoCitationSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '参考来源 (${widget.citations.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: widget.citations
                  .map((citation) => _VideoCitationRow(citation: citation))
                  .toList(),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _VideoCitationRow extends StatelessWidget {
  const _VideoCitationRow({required this.citation});

  final ChatMessageCitation citation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            size: 14,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              citation.quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          if (citation.timeRange != null) ...[
            const SizedBox(width: 6),
            Text(
              citation.timeRange!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddToKbButton extends StatelessWidget {
  const _AddToKbButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBFD1FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.library_books_rounded,
              size: 15,
              color: Color(0xFF275FD8),
            ),
            SizedBox(width: 5),
            Text(
              '加入知识库',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF275FD8),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '继续追问这段总结...',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.fromLTRB(6, 3, 6, 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                ),
                style: context.appTextStyles.summaryContentBody.copyWith(
                  height: 1.2,
                ),
                strutStyle: const StrutStyle(
                  height: 1.2,
                  leading: 0,
                  forceStrutHeight: true,
                ),
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
                  const ComposerAttachmentButton(),
                  if (hasInput) ...[
                    const SizedBox(width: 8),
                    AppInlineSubmitButton(
                      isLoading: isSending,
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
    const buttonHeight = 28.0;

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(buttonHeight / 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: buttonHeight,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE8F0FF) : const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(buttonHeight / 2),
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
              size: 15,
              color: enabled
                  ? const Color(0xFF2B63EB)
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                enabled ? '时间区间  $selectedLabel' : '时间区间',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1,
                  // fontWeight: FontWeight.w700,
                  color: enabled
                      ? const Color(0xFF2B63EB)
                      : AppColors.textPrimary,
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
                  onTap: () =>
                      Navigator.of(context).pop(_TimestampAction.disable),
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

/// 弹出知识库选择底部弹窗，用户选择后将当前视频加入对应知识库。
Future<void> showAddToKnowledgeBaseSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String videoId,
}) async {
  final librariesAsync = ref.read(libraryListControllerProvider);

  // 确保知识库列表已加载
  if (librariesAsync.libraries.isEmpty && !librariesAsync.isLoading) {
    ref.read(libraryListControllerProvider.notifier).refresh();
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return _AddToKnowledgeBaseSheet(
        ref: ref,
        videoId: videoId,
      );
    },
  );
}

class _AddToKnowledgeBaseSheet extends ConsumerStatefulWidget {
  const _AddToKnowledgeBaseSheet({
    required this.ref,
    required this.videoId,
  });

  final WidgetRef ref;
  final String videoId;

  @override
  ConsumerState<_AddToKnowledgeBaseSheet> createState() =>
      _AddToKnowledgeBaseSheetState();
}

class _AddToKnowledgeBaseSheetState
    extends ConsumerState<_AddToKnowledgeBaseSheet> {
  bool _isCreating = false;

  Future<void> _createAndBind(BuildContext context) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('新建知识库'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '知识库名称'),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isCreating = true);

    try {
      final controller = ref.read(libraryListControllerProvider.notifier);
      final newLibrary = await controller.createLibrary(name: name);
      if (newLibrary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建知识库失败，请重试')),
        );
        return;
      }

      final kbService = ref.read(knowledgeBaseServiceProvider);
      await kbService.bindVideo(kbid: newLibrary.id, videoId: widget.videoId);

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop(); // 关闭选择 sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text('已创建「$name」并加入'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _KbSheetStrings.of(context);
    final librariesState = ref.watch(libraryListControllerProvider);
    final kbService = ref.watch(knowledgeBaseServiceProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // 新建知识库 — 固定置顶
            _NewKbTile(
              isLoading: _isCreating,
              onTap: _isCreating ? null : () => _createAndBind(context),
            ),
            const SizedBox(height: 8),
            if (librariesState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (librariesState.libraries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.emptyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              )
            else
              ...librariesState.libraries.map(
                (library) => _KnowledgeBaseTile(
                  title: library.title,
                  meta: library.meta,
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await kbService.bindVideo(
                        kbid: library.id,
                        videoId: widget.videoId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.success(library.title)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.failure(e.toString())),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 新建知识库条目，固定在列表顶部。
class _NewKbTile extends StatelessWidget {
  const _NewKbTile({required this.isLoading, this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD0DAF0),
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF5B7EC2),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF5B7EC2),
                    ),
            ),
            const SizedBox(width: 10),
            Text(
              '新建知识库',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B5FA0),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF8FA8D0),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeBaseTile extends StatelessWidget {
  const _KnowledgeBaseTile({
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
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
              const Icon(
                Icons.library_books_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI 正在思考的动画指示器（与知识库聊天的 typing indicator 样式一致）。
class _SummaryTypingIndicator extends StatefulWidget {
  const _SummaryTypingIndicator();

  @override
  State<_SummaryTypingIndicator> createState() =>
      _SummaryTypingIndicatorState();
}

class _SummaryTypingIndicatorState extends State<_SummaryTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _SummaryTypingDot(),
              SizedBox(width: 6),
              _SummaryTypingDot(),
              SizedBox(width: 6),
              _SummaryTypingDot(),
              SizedBox(width: 10),
              Text(
                'AI 正在思考…',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTypingDot extends StatelessWidget {
  const _SummaryTypingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF8E8E93),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 简单本地化字符串封装，避免散写中文。
class _KbSheetStrings {
  const _KbSheetStrings._();

  static _KbSheetStrings of(BuildContext context) =>
      const _KbSheetStrings._();

  String get title => '加入知识库';
  String get emptyHint => '暂无知识库，请先创建';
  String success(String kbName) => '已加入知识库「$kbName」';
  String failure(String error) => '加入失败：$error';
}
