import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/video_summary_domain_models.dart';
import 'fake_video_summary_repository.dart';
import 'video_summary_models.dart';

final videoSummaryRepositoryProvider = Provider<VideoSummaryRepository>((ref) {
  return const FakeVideoSummaryRepository();
});

/// repository 只暴露稳定数据 contract，不直接返回 UI 展示模型。
abstract class VideoSummaryRepository {
  const VideoSummaryRepository();

  VideoAssetInfo getVideoAsset();

  Stream<VideoSummaryProcessingData> startDraftGeneration();

  Future<VideoSummaryDraftData> fetchDraftResult();

  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  });

  Future<VideoSummaryChatReplyData> sendSummaryChatMessage(String message);
}
