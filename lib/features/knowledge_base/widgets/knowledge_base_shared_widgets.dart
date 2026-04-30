import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_bottom_nav.dart';
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

class KnowledgeBaseComposer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hintText,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '+',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: onSubmit,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F2937),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
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
