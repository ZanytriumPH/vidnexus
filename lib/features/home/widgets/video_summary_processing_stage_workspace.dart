import 'package:flutter/material.dart';

import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
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
          onTap: onProcessingCardPressed,
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: processingExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: ProcessingDetailCard(snapshot: processingSnapshot),
          secondChild: const ProcessingCollapsedHintCard(),
        ),
      ],
    );
  }
}