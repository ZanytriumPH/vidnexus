import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';
import 'package:vidnexus/features/home/video_summary_processing_event_adapter.dart';
import 'package:vidnexus/features/home/video_summary_processing_event_source.dart';

void main() {
  group('video summary processing event adapter', () {
    test('aggregates status and chunk progress events into raw processing data', () async {
      const adapter = VideoSummaryProcessingEventAdapter();

      final stream = adapter.bind(
        Stream<VideoSummaryProcessingBackendEvent>.fromIterable(const [
          VideoSummaryProcessingStatusEvent(
            stage: VideoSummaryProcessingStage.bootingWorkflow,
            message: 'LangGraph 状态机已点火。',
          ),
          VideoSummaryProcessingStatusEvent(
            stage: VideoSummaryProcessingStage.dispatchingChunks,
            message: '分片任务已派发。',
          ),
          VideoSummaryProcessingChunkProgressEvent(
            progress: VideoSummaryChunkProgressData(
              stage: VideoSummaryChunkProgressStage.running,
              totalChunks: 8,
              audioDone: 2,
              visionDone: 1,
              synthesisDone: 0,
              overallDone: 3,
              overallTotal: 24,
              overallPercent: 12,
            ),
          ),
          VideoSummaryProcessingStatusEvent(
            stage: VideoSummaryProcessingStage.analyzingAudioChunks,
            message: '音频 worker 正在回收首批结构化洞察。',
          ),
        ]),
      );

      final snapshots = await stream.toList();
      final last = snapshots.last;

      expect(snapshots, hasLength(4));
      expect(last.currentStage, VideoSummaryProcessingStage.analyzingAudioChunks);
      expect(last.currentMessage, '音频 worker 正在回收首批结构化洞察。');
      expect(last.chunkProgress?.audioDone, 2);
      expect(last.chunkProgress?.visionDone, 1);
      expect(last.steps[0].progress, 100);
      expect(last.steps[1].progress, greaterThan(0));
      expect(last.progress, greaterThan(0));
    });

    test('marks chunk progress finished when review ready event arrives', () async {
      const adapter = VideoSummaryProcessingEventAdapter();

      final stream = adapter.bind(
        Stream<VideoSummaryProcessingBackendEvent>.fromIterable(const [
          VideoSummaryProcessingChunkProgressEvent(
            progress: VideoSummaryChunkProgressData(
              stage: VideoSummaryChunkProgressStage.running,
              totalChunks: 8,
              audioDone: 8,
              visionDone: 8,
              synthesisDone: 8,
              overallDone: 24,
              overallTotal: 24,
              overallPercent: 100,
            ),
          ),
          VideoSummaryProcessingReviewReadyEvent(),
        ]),
      );

      final snapshots = await stream.toList();
      final last = snapshots.last;

      expect(last.currentStage, VideoSummaryProcessingStage.waitingHumanReview);
      expect(last.chunkProgress?.stage, VideoSummaryChunkProgressStage.finished);
      expect(last.steps[2].progress, 100);
      expect(last.progress, 1);
    });
  });
}