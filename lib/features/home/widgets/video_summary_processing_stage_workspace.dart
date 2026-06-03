import 'package:flutter/material.dart';

import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import 'streamlit_progress_card.dart';
import 'video_summary_processing_widgets.dart';

class ProcessingStageWorkspace extends StatelessWidget {
  const ProcessingStageWorkspace({
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.processingExpanded,
    required this.onProcessingCardPressed,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot processingSnapshot;
  final bool processingExpanded;
  final VoidCallback onProcessingCardPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          stage: VideoSummaryStage.processing,
          highlighted: highlighted,
          videoAsset: videoAsset,
          processingSnapshot: processingSnapshot,
          processingExpanded: processingExpanded,
          onTap: null,
        ),
        const SizedBox(height: 12),
        AppCard(
          radius: 18,
          padding: EdgeInsets.zero,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              child: processingExpanded
                  ? StreamlitProgressCard(
                      key: const ValueKey('expanded'),
                      snapshot: processingSnapshot,
                      onTap: onProcessingCardPressed,
                    )
                  : ProcessingCollapsedHintCard(
                      key: const ValueKey('collapsed'),
                      onTap: onProcessingCardPressed,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}