import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_bottom_nav.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/composer_attachment_button.dart';
import '../../../services/attachment_service.dart';
import '../../../services/models/video_qa_dto.dart' show AttachmentInfo;
import '../knowledge_base_models.dart';

class KnowledgeBaseTopBar extends StatelessWidget {
  const KnowledgeBaseTopBar({
    required this.currentSection,
    required this.onSectionSelected,
    required this.title,
    this.onLeadingPressed,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.leading,
    this.showTitle = true,
    this.trailing,
    this.onSettingsPressed,
    super.key,
  });

  final AppNavSection currentSection;
  final ValueChanged<AppNavSection> onSectionSelected;
  final String title;
  final VoidCallback? onLeadingPressed;
  final IconData leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final bool showTitle;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeaderBar(
          current: currentSection,
          onSelected: onSectionSelected,
          leading: leading ??
              (onLeadingPressed == null
                  ? null
                  : InkWell(
                      onTap: onLeadingPressed,
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(
                            leadingIcon,
                            size: 24,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )),
          trailing: trailing,
        ),
        if (showTitle) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

KnowledgeConversationPreview buildEmptyKnowledgeConversation({
  required String libraryTitle,
}) {
  return KnowledgeConversationPreview(
    id: 'new-${DateTime.now().millisecondsSinceEpoch}',
    title: '新的会话',
    preview: '已进入新会话，可以直接围绕当前知识库继续提问。',
    dateLabel: '刚刚',
    messages: [
      KnowledgeChatMessage(
        sender: KnowledgeChatSender.system,
        text: '已为“$libraryTitle”新建会话。你可以直接提问，我会只基于当前知识库的资料继续回答。',
      ),
    ],
  );
}

class KnowledgeBaseComposer extends StatefulWidget {
  const KnowledgeBaseComposer({
    required this.controller,
    required this.onSubmit,
    this.onAttachmentsChanged,
    this.hintText = '继续追问资料，或让它输出结构化结论',
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<List<AttachmentInfo>>? onAttachmentsChanged;
  final String hintText;
  final bool enabled;

  @override
  State<KnowledgeBaseComposer> createState() => _KnowledgeBaseComposerState();
}

class _KnowledgeBaseComposerState extends State<KnowledgeBaseComposer>
    with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  final List<AttachmentInfo> _pendingAttachments = [];
  final _attachmentService = const AttachmentService();
  bool _keyboardVisible = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (isKeyboardVisible == _keyboardVisible) return;
    setState(() {
      _keyboardVisible = isKeyboardVisible;
    });
    if (!isKeyboardVisible) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final hasInput = value.text.trim().isNotEmpty;
        final expanded = _keyboardVisible || hasInput;

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
                _KbAttachmentPreviewStrip(
                  attachments: _pendingAttachments,
                  onRemove: _removeAttachment,
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        filled: false,
                        isDense: true,
                        contentPadding: expanded
                            ? const EdgeInsets.fromLTRB(6, 3, 6, 10)
                            : const EdgeInsets.fromLTRB(6, 7, 6, 11),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: context.appTextStyles.summaryContentBody
                          .copyWith(height: 1.2),
                      strutStyle: const StrutStyle(
                        height: 1.2,
                        leading: 0,
                        forceStrutHeight: true,
                      ),
                      textAlignVertical: TextAlignVertical.top,
                      minLines: 1,
                      maxLines: expanded ? 4 : 1,
                    ),
                  ),
                  if (!expanded)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ComposerAttachmentButton(
                        onImagePicked: _onImagePicked,
                        enabled: !_uploading,
                      ),
                    ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Spacer(),
                    ComposerAttachmentButton(
                      onImagePicked: _onImagePicked,
                      enabled: !_uploading,
                    ),
                    if (hasInput || _pendingAttachments.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AppInlineSubmitButton(
                        isLoading: !widget.enabled || _uploading,
                        onPressed: widget.enabled ? widget.onSubmit : null,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 知识库输入框附件缩略图预览条。
class _KbAttachmentPreviewStrip extends StatelessWidget {
  const _KbAttachmentPreviewStrip({
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
                child: att.presignedUrl != null && att.presignedUrl!.isNotEmpty
                    ? Image.network(
                        att.presignedUrl!,
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
