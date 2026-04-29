import '../video_summary_models.dart';

/// 这里只放 repository 可稳定返回的业务结果数据，不放界面展示结构。
enum VideoSummaryProcessingPhase { preprocessing, analysis, synthesis }

enum VideoSummaryProcessingStage {
  acquiringVideo,
  extractingAudio,
  extractingFrames,
  transcribingAudio,
  bootingWorkflow,
  planningChunks,
  dispatchingChunks,
  analyzingAudioChunks,
  analyzingVisionChunks,
  synthesizingChunks,
  aggregatingChunks,
  waitingHumanReview,
}

enum VideoSummaryChunkProgressStage { running, finished }

class VideoSummaryChunkProgressData {
  const VideoSummaryChunkProgressData({
    required this.stage,
    required this.totalChunks,
    required this.audioDone,
    required this.visionDone,
    required this.synthesisDone,
    required this.overallDone,
    required this.overallTotal,
    required this.overallPercent,
  });

  final VideoSummaryChunkProgressStage stage;
  final int totalChunks;
  final int audioDone;
  final int visionDone;
  final int synthesisDone;
  final int overallDone;
  final int overallTotal;
  final int overallPercent;
}

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
    required this.currentStage,
    required this.currentMessage,
    required this.steps,
    this.chunkProgress,
  });

  final double progress;
  final VideoSummaryProcessingStage currentStage;
  final String currentMessage;
  final List<VideoSummaryProcessingStepData> steps;
  final VideoSummaryChunkProgressData? chunkProgress;
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