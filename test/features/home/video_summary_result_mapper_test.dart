import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/features/home/application/video_summary_result_mapper.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';

void main() {
  group('video summary processing mapper', () {
    test('buildInitialProcessingSnapshot returns a safe processing placeholder', () {
      final snapshot = buildInitialProcessingSnapshot();

      expect(snapshot.progress, 0);
      expect(snapshot.statusLabel, '处理中');
      expect(snapshot.headline, '正在准备处理任务');
      expect(snapshot.badges, hasLength(3));
      expect(snapshot.steps, hasLength(3));
      expect(snapshot.badges.first.active, isTrue);
    });

    test('maps chunk analysis processing data into mobile-facing labels', () {
      const data = VideoSummaryProcessingData(
        progress: 0.58,
        currentStage: VideoSummaryProcessingStage.analyzingVisionChunks,
        currentMessage: '视觉 worker 正在补齐画面证据和关键帧检索结果。',
        chunkProgress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: 8,
          audioDone: 5,
          visionDone: 3,
          synthesisDone: 1,
          overallDone: 9,
          overallTotal: 24,
          overallPercent: 38,
        ),
        steps: [
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.preprocessing,
            progress: 100,
            completedUnits: 4,
            totalUnits: 4,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.analysis,
            progress: 61,
            completedUnits: 8,
            totalUnits: 16,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.synthesis,
            progress: 28,
            completedUnits: 1,
            totalUnits: 10,
          ),
        ],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '处理中');
      expect(snapshot.headline, '正在并行分析分片证据');
      expect(snapshot.etaLabel, contains('音频 5/8 · 视觉 3/8 · 融合 1/8'));
      expect(snapshot.badges[0].label, '素材预处理 已完成');
      expect(snapshot.badges[1].active, isTrue);
      expect(snapshot.steps[1].detail, contains('视觉分片已完成 3/8'));
    });

    test('maps waitingHumanReview into completion-facing copy', () {
      const data = VideoSummaryProcessingData(
        progress: 1,
        currentStage: VideoSummaryProcessingStage.waitingHumanReview,
        currentMessage: '待审稿已封装完成。',
        chunkProgress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.finished,
          totalChunks: 8,
          audioDone: 8,
          visionDone: 8,
          synthesisDone: 8,
          overallDone: 24,
          overallTotal: 24,
          overallPercent: 100,
        ),
        steps: [
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.preprocessing,
            progress: 100,
            completedUnits: 4,
            totalUnits: 4,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.analysis,
            progress: 100,
            completedUnits: 16,
            totalUnits: 16,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.synthesis,
            progress: 100,
            completedUnits: 10,
            totalUnits: 10,
          ),
        ],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '待进入初稿');
      expect(snapshot.headline, '正在汇总分片并整理待审初稿');
      expect(snapshot.steps[2].detail, '聚合稿已整理完成，准备进入待审阅初稿阶段。');
    });
  });
}