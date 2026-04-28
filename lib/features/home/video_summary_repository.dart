import 'video_summary_models.dart';

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
