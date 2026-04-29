import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_video_summary_repository.dart';
import 'video_summary_models.dart';

final videoSummaryRepositoryProvider = Provider<VideoSummaryRepository>((ref) {
  return const FakeVideoSummaryRepository();
});

abstract class VideoSummaryRepository {
  const VideoSummaryRepository();

  VideoAssetInfo getVideoAsset();

  Stream<ProcessingSnapshot> startDraftGeneration();

  Future<DraftResult> fetchDraftResult();

  Future<FinalSummaryData> generateFinalSummary({
    required String guidance,
    required DraftResult draft,
  });

  Future<ChatMessage> sendSummaryChatMessage(String message);
}
