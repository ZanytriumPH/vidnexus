import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../video_summary_models.dart';
import 'home_shell_widgets.dart';
import 'video_summary_processing_widgets.dart';

class ReadyStageWorkspace extends StatelessWidget {
  const ReadyStageWorkspace({
    required this.highlighted,
    required this.videoAsset,
    required this.preferenceController,
    required this.isGenerating,
    required this.onUploadCardPressed,
    required this.onStartPressed,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final TextEditingController preferenceController;
  final bool isGenerating;
  final VoidCallback onUploadCardPressed;
  final VoidCallback? onStartPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          stage: VideoSummaryStage.ready,
          highlighted: highlighted,
          videoAsset: videoAsset,
          processingSnapshot: null,
          processingExpanded: false,
          onTap: onUploadCardPressed,
        ),
        const SizedBox(height: 24),
        Text(
          '总结偏好（可选）',
          textAlign: TextAlign.center,
          style: context.appTextStyles.summarySectionTitle,
        ),
        const SizedBox(height: 14),
        PreferenceCard(
          controller: preferenceController,
          hintText: '例如：请先给我按行业、声线和行动建议展开。',
          prominent: true,
        ),
        const SizedBox(height: 24),
        ReadyPrimaryButton(
          label: isGenerating ? '正在生成中...' : '开始生成初稿',
          onPressed: onStartPressed,
        ),
      ],
    );
  }
}

class ReadyPrimaryButton extends StatelessWidget {
  const ReadyPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x261B55D9),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F69E8),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF8AAEF6),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: context.appTextStyles.primaryActionButtonLabel,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}