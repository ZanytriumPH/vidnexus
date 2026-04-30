import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_bottom_nav.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/composer_attachment_button.dart';
import '../knowledge_base_models.dart';

class KnowledgeBaseTopBar extends StatelessWidget {
  const KnowledgeBaseTopBar({
    required this.currentSection,
    required this.onSectionSelected,
    required this.title,
    this.onLeadingPressed,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.showTitle = true,
    this.trailing,
    super.key,
  });

  final AppNavSection currentSection;
  final ValueChanged<AppNavSection> onSectionSelected;
  final String title;
  final VoidCallback? onLeadingPressed;
  final IconData leadingIcon;
  final Widget? trailing;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeaderBar(
          current: currentSection,
          onSelected: onSectionSelected,
          leading: onLeadingPressed == null
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
                ),
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
    this.hintText = '继续追问资料，或让它输出结构化结论',
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String hintText;

  @override
  State<KnowledgeBaseComposer> createState() => _KnowledgeBaseComposerState();
}

class _KnowledgeBaseComposerState extends State<KnowledgeBaseComposer> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final hasInput = value.text.trim().isNotEmpty;
        final expanded = _hasFocus || hasInput;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        filled: false,
                        isDense: true,
                        contentPadding: expanded
                            ? const EdgeInsets.fromLTRB(6, 3, 6, 10)
                            : const EdgeInsets.fromLTRB(6, 0, 6, 0),
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
                  if (!expanded) const ComposerAttachmentButton(),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Spacer(),
                    const ComposerAttachmentButton(),
                    if (hasInput) ...[
                      const SizedBox(width: 8),
                      AppInlineSubmitButton(
                        isLoading: false,
                        onPressed: widget.onSubmit,
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

  Widget _buildCollapsed(BuildContext context) => const SizedBox.shrink();
  Widget _buildExpanded(BuildContext context, bool hasInput) =>
      const SizedBox.shrink();
}
