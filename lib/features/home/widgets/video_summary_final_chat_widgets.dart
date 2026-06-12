import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/app_typing_indicator.dart';
import '../../../app/widgets/composer_attachment_button.dart';
import '../../../services/api/api_client.dart';
import '../../../services/attachment_service.dart';
import '../../../services/models/common_dto.dart';
import '../../../services/models/video_summary_task_dto.dart';
import '../../../services/models/video_qa_dto.dart' show AttachmentInfo;
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
    this.onCloneToKbPressed,
    this.isWaiting = false,
    super.key,
  });

  final FinalSummaryData summary;
  final List<ChatMessage> messages;
  final VoidCallback? onCloneToKbPressed;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    final messageStyles = context.appMessageStyles;
    // 空系统消息不渲染（此时 typing indicator 正在展示）
    final visibleMessages = messages.where(
      (m) => m.sender == SummaryChatSender.user || m.text.isNotEmpty,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
          child: _FinalSummaryBubble(
            summary: summary,
            onCloneToKbPressed: onCloneToKbPressed,
          ),
        ),
        ...visibleMessages.map(
          (message) => Padding(
            padding: EdgeInsets.only(bottom: messageStyles.messageSpacing),
            child: _SummaryChatBubble(message: message),
          ),
        ),
        if (isWaiting) const AppTypingIndicator(),
      ],
    );
  }
}

class _FinalSummaryBubble extends StatelessWidget {
  const _FinalSummaryBubble({
    required this.summary,
    this.onCloneToKbPressed,
  });

  final FinalSummaryData summary;
  final VoidCallback? onCloneToKbPressed;

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
              if (onCloneToKbPressed != null)
                _AddToOtherKbButton(onPressed: onCloneToKbPressed),
            ],
          ),
          SizedBox(height: messageStyles.messageSpacing),
          VideoSummaryMarkdownBody(data: summary.summaryBody),
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
        // 附件图片（用户消息气泡，显示在文字上方）
        if (!isSystemMessage && message.attachments.isNotEmpty) ...[
          _AttachmentImageGrid(attachments: message.attachments),
          const SizedBox(height: 8),
        ],
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

/// 附件图片网格，最多显示 4 张，超出显示 "+N"。
class _AttachmentImageGrid extends StatelessWidget {
  const _AttachmentImageGrid({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final displayCount = attachments.length > 4 ? 4 : attachments.length;
    final overflow = attachments.length - displayCount;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < displayCount; i++)
          GestureDetector(
            onTap: () => _showFullImage(context, attachments[i]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: attachments[i].ossKey.isNotEmpty
                    ? Image.network(
                        _thumbnailUrl(attachments[i].ossKey),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
          ),
        if (overflow > 0)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _thumbnailUrl(String ossKey) {
    final base = ApiClient.instance.options.baseUrl;
    return '$base/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 24, color: AppColors.textHint),
      ),
    );
  }

  void _showFullImage(BuildContext context, ChatAttachment attachment) {
    if (attachment.ossKey.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              _thumbnailUrl(attachment.ossKey),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 200,
                child: Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
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

class _AddToOtherKbButton extends StatelessWidget {
  const _AddToOtherKbButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD0DAF0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.content_copy, size: 15, color: Color(0xFF3B5FA0)),
            SizedBox(width: 5),
            Text(
              '添加到其他知识库',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B5FA0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatComposer extends StatefulWidget {
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
    this.onAttachmentsChanged,
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
  final ValueChanged<List<AttachmentInfo>>? onAttachmentsChanged;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final List<AttachmentInfo> _pendingAttachments = [];
  final _attachmentService = const AttachmentService();
  bool _uploading = false;

  void _notifyAttachmentsChanged() {
    widget.onAttachmentsChanged?.call(List.from(_pendingAttachments));
  }

  Future<void> _onImagePicked(File file) async {
    setState(() => _uploading = true);
    try {
      final resp = await _attachmentService.uploadAttachment(
        filePath: file.path,
        fileName: file.path.split('/').last.split('\\').last,
      );
      final data = resp.data;
      if (data != null) {
        setState(() {
          _pendingAttachments.add(AttachmentInfo(
            name: data.name,
            ossKey: data.ossKey,
            mimeType: data.mimeType,
            sizeBytes: data.sizeBytes,
            presignedUrl: data.presignedUrl,
          ));
        });
        _notifyAttachmentsChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
    _notifyAttachmentsChanged();
  }

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
          // 附件预览条
          if (_pendingAttachments.isNotEmpty)
            _AttachmentPreviewStrip(
              attachments: _pendingAttachments,
              onRemove: _removeAttachment,
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: widget.controller,
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
            valueListenable: widget.controller,
            builder: (context, value, child) {
              final hasInput = value.text.trim().isNotEmpty;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _TimestampScopeActionButton(
                        enabled: widget.isTimestampScoped,
                        selectedLabel: widget.selectedTimestampLabel,
                        totalDurationSeconds: widget.totalDurationSeconds,
                        selectedStartSeconds: widget.selectedTimestampStartSeconds,
                        selectedEndSeconds: widget.selectedTimestampEndSeconds,
                        onEnabledChanged: widget.onTimestampScopeChanged,
                        onRangeChanged: widget.onTimestampRangeChanged,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ComposerAttachmentButton(
                    onImagePicked: _onImagePicked,
                    enabled: !_uploading,
                  ),
                  if (hasInput || _pendingAttachments.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    AppInlineSubmitButton(
                      isLoading: widget.isSending || _uploading,
                      onPressed: widget.onSendPressed != null
                          ? () {
                              widget.onSendPressed!();
                              setState(() => _pendingAttachments.clear());
                            }
                          : null,
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
  String? taskId,
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
        taskId: taskId,
      );
    },
  );
}

class _AddToKnowledgeBaseSheet extends ConsumerStatefulWidget {
  const _AddToKnowledgeBaseSheet({
    required this.ref,
    required this.videoId,
    this.taskId,
  });

  final WidgetRef ref;
  final String videoId;
  final String? taskId;

  @override
  ConsumerState<_AddToKnowledgeBaseSheet> createState() =>
      _AddToKnowledgeBaseSheetState();
}

class _AddToKnowledgeBaseSheetState
    extends ConsumerState<_AddToKnowledgeBaseSheet> {
  bool _isCreating = false;

  Future<void> _handleKbSelected(
    BuildContext context,
    String kbid,
    String kbName,
  ) async {
    setState(() => _isCreating = true);
    try {
      // 将任务结果添加到目标知识库
      final taskService = ref.read(taskServiceProvider);
      debugPrint('[AddToOtherKb] 开始添加 taskId=${widget.taskId} kbid=$kbid');
      await taskService.cloneTaskToKb(widget.taskId!, kbid: kbid);
      debugPrint('[AddToOtherKb] 添加成功');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加到「$kbName」'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (context.mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      debugPrint(
        '[AddToOtherKb] DioException statusCode=${e.response?.statusCode} '
        'taskId=${widget.taskId}',
      );
      if (e.response?.statusCode == 409) {
        // 409: 目标知识库中已存在同一视频的摘要任务
        final conflict = TaskConflictData.tryExtract(e.response?.data);
        debugPrint('[AddToOtherKb] 409 conflict: existingTaskId=${conflict?.existingTaskId}');
        if (conflict != null && context.mounted) {
          final replace = await _showCloneConflictDialog(
            context,
            conflict,
            kbName,
          );
          debugPrint('[AddToOtherKb] 用户选择替换: $replace');
          if (replace == true && context.mounted) {
            try {
              final taskService = ref.read(taskServiceProvider);
              debugPrint(
                '[AddToOtherKb] 带 replaceExistingTaskId=${conflict.existingTaskId} 重试',
              );
              await taskService.cloneTaskToKb(
                widget.taskId!,
                kbid: kbid,
                replaceExistingTaskId: conflict.existingTaskId,
              );
              debugPrint('[AddToOtherKb] 替换添加成功');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已添加到「$kbName」'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e2) {
              debugPrint('[AddToOtherKb] 替换添加失败: $e2');
              if (context.mounted) {
                final msg = e2 is DioException
                    ? ApiError.fromDioException(e2).userMessage
                    : e2.toString();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('添加失败：$msg'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
        // Pop sheet after conflict handling (whether replaced or cancelled)
        if (context.mounted) Navigator.of(context).pop();
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('操作失败：${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[AddToOtherKb] 非 Dio 异常: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<bool> _showCloneConflictDialog(
    BuildContext context,
    TaskConflictData conflict,
    String kbName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('任务已存在'),
        content: Text(
          '「$kbName」中已存在同一视频的摘要任务，是否替换？',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('替换', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    return result ?? false;
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建知识库失败，请重试')));
        return;
      }

      // 将任务结果添加到新创建的知识库
      final taskService = ref.read(taskServiceProvider);
      await taskService.cloneTaskToKb(widget.taskId!, kbid: newLibrary.id);

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop(); // 关闭选择 sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text('已创建「$name」并添加'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _KbSheetStrings.of(context);
    final librariesState = ref.watch(libraryListControllerProvider);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
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
              // 知识库列表 — 可滚动
              if (librariesState.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (librariesState.libraries.isEmpty)
                Expanded(
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
                Expanded(
                  child: ListView(
                    children: librariesState.libraries
                        .where((l) => l.title != '默认知识库')
                        .map(
                          (library) => _KnowledgeBaseTile(
                            title: library.title,
                            meta: library.meta,
                            onTap: () => _handleKbSelected(
                              context,
                              library.id,
                              library.title,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
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

/// 简单本地化字符串封装，避免散写中文。
class _KbSheetStrings {
  const _KbSheetStrings._();

  static _KbSheetStrings of(BuildContext context) => const _KbSheetStrings._();

  String get title => '添加到其他知识库';
  String get emptyHint => '暂无知识库，请先创建';
  String success(String kbName) => '已添加到「$kbName」';
  String failure(String error) => '添加失败：$error';
}

/// 附件缩略图预览条，水平滚动，支持点击删除。
class _AttachmentPreviewStrip extends StatelessWidget {
  const _AttachmentPreviewStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<AttachmentInfo> attachments;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final att = attachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: att.ossKey.isNotEmpty
                    ? Image.network(
                        _thumbnailUrl(att.ossKey),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF999999),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _thumbnailUrl(String ossKey) {
    final base = ApiClient.instance.options.baseUrl;
    return '$base/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, size: 24, color: AppColors.textHint),
    );
  }
}
