import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_buttons.dart';
import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'home_shell_widgets.dart';
import 'video_summary_processing_widgets.dart';

class DraftStageWorkspace extends StatelessWidget {
  const DraftStageWorkspace({
    required this.highlighted,
    required this.videoAsset,
    required this.draftResult,
    required this.guidanceController,
    required this.draftBodyController,
    required this.isDraftEditMode,
    required this.isGenerating,
    required this.onUploadCardPressed,
    required this.onDraftEditModeChanged,
    required this.onGenerateFinalPressed,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final DraftResult draftResult;
  final TextEditingController guidanceController;
  final TextEditingController draftBodyController;
  final bool isDraftEditMode;
  final bool isGenerating;
  final VoidCallback onUploadCardPressed;
  final ValueChanged<bool> onDraftEditModeChanged;
  final VoidCallback? onGenerateFinalPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroCard(
                  stage: VideoSummaryStage.draft,
                  highlighted: highlighted,
                  videoAsset: videoAsset,
                  processingSnapshot: null,
                  processingExpanded: false,
                  onTap: onUploadCardPressed,
                ),
                const SizedBox(height: 12),
                DraftBodyCard(
                  draftBodyController: draftBodyController,
                  isEditMode: isDraftEditMode,
                  onModeChanged: onDraftEditModeChanged,
                ),
                const SizedBox(height: 10),
                const SectionLabel(title: '总结指导（可选）', centered: true),
                const SizedBox(height: 6),
                PreferenceCard(
                  controller: guidanceController,
                  hintText: draftResult.suggestionHint,
                  prominent: true,
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        AppPrimaryButton(
          label: isGenerating ? '正在整理最终稿...' : '生成最终稿',
          labelStyle: context.appTextStyles.primaryActionButtonLabel,
          onPressed: onGenerateFinalPressed,
        ),
      ],
    );
  }
}

class DraftBodyCard extends StatelessWidget {
  const DraftBodyCard({
    required this.draftBodyController,
    required this.isEditMode,
    required this.onModeChanged,
    super.key,
  });

  final TextEditingController draftBodyController;
  final bool isEditMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final messageStyles = context.appMessageStyles;

    return AppCard(
      radius: messageStyles.draftRadius,
      padding: messageStyles.draftPadding,
      backgroundColor: messageStyles.draftSurface,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '初稿正文',
                  style: context.appTextStyles.summarySectionTitle,
                ),
              ),
              MiniTab(
                active: isEditMode,
                label: isEditMode ? '完成' : '编辑',
                onTap: () => onModeChanged(!isEditMode),
              ),
            ],
          ),
          SizedBox(height: messageStyles.messageSpacing),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 168),
            child: isEditMode
                ? TextField(
                    controller: draftBodyController,
                    maxLines: null,
                    minLines: 8,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                      hintText: '点击这里直接修改初稿内容',
                      hintStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    style: context.appTextStyles.summaryContentBody,
                  )
                : Text(
                    draftBodyController.text,
                    style: context.appTextStyles.summaryContentBody,
                  ),
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
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E2430) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
