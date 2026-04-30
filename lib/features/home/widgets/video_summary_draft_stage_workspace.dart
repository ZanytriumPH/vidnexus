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
          draft: draftResult,
          draftBodyController: draftBodyController,
          isEditMode: isDraftEditMode,
          onModeChanged: onDraftEditModeChanged,
        ),
        const SizedBox(height: 10),
        const SectionLabel(title: '总结指导（可选）', centered: false),
        const SizedBox(height: 6),
        PreferenceCard(
          controller: guidanceController,
          hintText: draftResult.suggestionHint,
          prominent: true,
        ),
        const SizedBox(height: 14),
        AppPrimaryButton(
          label: isGenerating ? '正在整理最终稿...' : '生成最终稿',
          onPressed: onGenerateFinalPressed,
        ),
      ],
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
                    style: context.appTextStyles.summaryContentBody,
                  )
                else
                  Text(
                    draftBodyController.text,
                    style: context.appTextStyles.summaryContentBody,
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