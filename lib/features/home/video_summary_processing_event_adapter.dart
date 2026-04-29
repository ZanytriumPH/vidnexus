import 'domain/video_summary_domain_models.dart';
import 'video_summary_processing_event_source.dart';

class VideoSummaryProcessingEventAdapter {
  const VideoSummaryProcessingEventAdapter();

  Stream<VideoSummaryProcessingData> bind(
    Stream<VideoSummaryProcessingBackendEvent> events,
  ) async* {
    final state = _ProcessingAggregationState.initial();

    await for (final event in events) {
      state.apply(event);
      yield state.snapshot();
    }
  }
}

class _ProcessingAggregationState {
  _ProcessingAggregationState._({
    required this.currentStage,
    required this.currentMessage,
    required this.chunkProgress,
  });

  factory _ProcessingAggregationState.initial() {
    return _ProcessingAggregationState._(
      currentStage: VideoSummaryProcessingStage.acquiringVideo,
      currentMessage: '正在等待处理事件。',
      chunkProgress: null,
    );
  }

  VideoSummaryProcessingStage currentStage;
  String currentMessage;
  VideoSummaryChunkProgressData? chunkProgress;

  void apply(VideoSummaryProcessingBackendEvent event) {
    switch (event) {
      case VideoSummaryProcessingStatusEvent():
        currentStage = event.stage;
        currentMessage = event.message;
      case VideoSummaryProcessingChunkProgressEvent():
        chunkProgress = event.progress;
      case VideoSummaryProcessingReviewReadyEvent():
        currentStage = VideoSummaryProcessingStage.waitingHumanReview;
        currentMessage = event.message;
        final progress = chunkProgress;
        if (progress != null) {
          chunkProgress = VideoSummaryChunkProgressData(
            stage: VideoSummaryChunkProgressStage.finished,
            totalChunks: progress.totalChunks,
            audioDone: progress.audioDone,
            visionDone: progress.visionDone,
            synthesisDone: progress.synthesisDone,
            overallDone: progress.overallDone,
            overallTotal: progress.overallTotal,
            overallPercent: progress.overallPercent,
          );
        }
    }
  }

  VideoSummaryProcessingData snapshot() {
    final preprocessCompleted = _preprocessCompletedFor(currentStage);
    final analysisBaselineProgress = _analysisBaselineFor(currentStage);
    final synthesisBaselineProgress = _synthesisBaselineFor(currentStage);

    final totalChunks = chunkProgress?.totalChunks ?? 0;
    final analysisCompleted = (chunkProgress?.audioDone ?? 0) +
        (chunkProgress?.visionDone ?? 0);
    final analysisTotal = totalChunks * 2;
    final analysisProgress = analysisTotal == 0
        ? analysisBaselineProgress
        : _max(
            analysisBaselineProgress,
            ((analysisCompleted / analysisTotal) * 100).round(),
          );

    final synthesisExtraCompleted = _synthesisExtraCompletedFor(currentStage);
    final synthesisCompleted = (chunkProgress?.synthesisDone ?? 0) +
        synthesisExtraCompleted;
    final synthesisTotal = totalChunks == 0 ? 0 : totalChunks + 2;
    final synthesisProgress = synthesisTotal == 0
        ? synthesisBaselineProgress
        : _max(
            synthesisBaselineProgress,
            ((synthesisCompleted / synthesisTotal) * 100).round(),
          );

    final overallProgress =
        (preprocessCompleted / 4 * 0.35) +
        (analysisProgress / 100 * 0.4) +
        (synthesisProgress / 100 * 0.25);

    return VideoSummaryProcessingData(
      progress: overallProgress.clamp(0, 1),
      currentStage: currentStage,
      currentMessage: currentMessage,
      chunkProgress: chunkProgress,
      steps: [
        VideoSummaryProcessingStepData(
          phase: VideoSummaryProcessingPhase.preprocessing,
          progress: ((preprocessCompleted / 4) * 100).round().clamp(0, 100),
          completedUnits: preprocessCompleted,
          totalUnits: 4,
        ),
        VideoSummaryProcessingStepData(
          phase: VideoSummaryProcessingPhase.analysis,
          progress: analysisProgress.clamp(0, 100),
          completedUnits: analysisCompleted,
          totalUnits: analysisTotal,
        ),
        VideoSummaryProcessingStepData(
          phase: VideoSummaryProcessingPhase.synthesis,
          progress: synthesisProgress.clamp(0, 100),
          completedUnits: synthesisCompleted,
          totalUnits: synthesisTotal,
        ),
      ],
    );
  }

  int _preprocessCompletedFor(VideoSummaryProcessingStage stage) {
    return switch (stage) {
      VideoSummaryProcessingStage.acquiringVideo => 0,
      VideoSummaryProcessingStage.extractingAudio => 1,
      VideoSummaryProcessingStage.extractingFrames => 2,
      VideoSummaryProcessingStage.transcribingAudio => 3,
      _ => 4,
    };
  }

  int _analysisBaselineFor(VideoSummaryProcessingStage stage) {
    return switch (stage) {
      VideoSummaryProcessingStage.bootingWorkflow => 8,
      VideoSummaryProcessingStage.planningChunks => 16,
      VideoSummaryProcessingStage.dispatchingChunks => 24,
      VideoSummaryProcessingStage.analyzingAudioChunks ||
      VideoSummaryProcessingStage.analyzingVisionChunks => 30,
      VideoSummaryProcessingStage.synthesizingChunks ||
      VideoSummaryProcessingStage.aggregatingChunks ||
      VideoSummaryProcessingStage.waitingHumanReview => 100,
      _ => 0,
    };
  }

  int _synthesisBaselineFor(VideoSummaryProcessingStage stage) {
    return switch (stage) {
      VideoSummaryProcessingStage.synthesizingChunks => 12,
      VideoSummaryProcessingStage.aggregatingChunks => 90,
      VideoSummaryProcessingStage.waitingHumanReview => 100,
      _ => 0,
    };
  }

  int _synthesisExtraCompletedFor(VideoSummaryProcessingStage stage) {
    return switch (stage) {
      VideoSummaryProcessingStage.aggregatingChunks => 1,
      VideoSummaryProcessingStage.waitingHumanReview => 2,
      _ => 0,
    };
  }

  int _max(int left, int right) => left > right ? left : right;
}