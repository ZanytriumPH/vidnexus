import '../video_summary_models.dart';

/// 这里只放 repository 可稳定返回的业务结果数据，不放界面展示结构。
enum VideoSummaryProcessingPhase { transcription, alignment, summary }

class VideoSummaryProcessingStepData {
  const VideoSummaryProcessingStepData({
    required this.phase,
    required this.progress,
    required this.completedUnits,
    required this.totalUnits,
  });

  final VideoSummaryProcessingPhase phase;
  final int progress;
  final int completedUnits;
  final int totalUnits;
}

class VideoSummaryProcessingData {
  const VideoSummaryProcessingData({
    required this.progress,
    required this.steps,
  });

  final double progress;
  final List<VideoSummaryProcessingStepData> steps;
}

class VideoSummaryDraftData {
  const VideoSummaryDraftData({required this.paragraphs});

  final List<String> paragraphs;
}

class VideoSummaryReferenceRange {
  const VideoSummaryReferenceRange({
    required this.startSeconds,
    required this.endSeconds,
    required this.topic,
  });

  final int startSeconds;
  final int endSeconds;
  final String topic;

  TimestampRangeSelection toRangeSelection() {
    return TimestampRangeSelection(
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
  }
}

class VideoSummaryFinalResultData {
  const VideoSummaryFinalResultData({
    required this.body,
    required this.references,
  });

  final String body;
  final List<VideoSummaryReferenceRange> references;
}

class VideoSummaryChatReplyData {
  const VideoSummaryChatReplyData({required this.text, this.reference});

  final String text;
  final VideoSummaryReferenceRange? reference;
}