import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/features/home/application/video_summary_result_mapper.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';

void main() {
  group('video summary processing mapper', () {
    test('buildInitialProcessingSnapshot returns a safe processing placeholder', () {
      final snapshot = buildInitialProcessingSnapshot();

      expect(snapshot.progress, 0);
      expect(snapshot.statusLabel, '处理中');
      expect(snapshot.etaLabel, contains('正在连接处理事件流'));
      expect(snapshot.chunkProgress, isNotNull);
      expect(snapshot.chunkProgress!.audioBar.label, '音频分片');
      expect(snapshot.chunkProgress!.audioBar.total, 5);
      expect(snapshot.chunkProgress!.audioBar.done, 0);
      expect(snapshot.chunkProgress!.visionBar.total, 5);
      expect(snapshot.chunkProgress!.synthesisBar.total, 5);
      expect(snapshot.chunkProgress!.overallBar.total, 10);
      expect(snapshot.statusLog, isEmpty);
    });

    test('maps chunk analysis processing data into mobile-facing labels', () {
      const data = VideoSummaryProcessingData(
        progress: 0.58,
        currentMessage: '视觉 worker 正在补齐画面...',
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
        statusLog: ['开始处理', '音频分片完成'],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '处理中');
      expect(snapshot.progress, 0.58);
      expect(snapshot.etaLabel, contains('音频 5/8 · 视觉 3/8 · 融合 1/8'));
      expect(snapshot.chunkProgress, isNotNull);
      expect(snapshot.chunkProgress!.audioBar.done, 5);
      expect(snapshot.chunkProgress!.audioBar.total, 8);
      expect(snapshot.chunkProgress!.visionBar.done, 3);
      expect(snapshot.chunkProgress!.synthesisBar.done, 1);
      expect(snapshot.chunkProgress!.overallBar.done, 9);
      expect(snapshot.chunkProgress!.overallBar.percent, 38);
      expect(snapshot.statusLog, hasLength(2));
      expect(snapshot.statusLog, contains('开始处理'));
    });

    test('maps finished processing into completion-facing copy', () {
      const data = VideoSummaryProcessingData(
        progress: 1.0,
        currentMessage: '待审稿',
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
        statusLog: ['处理完成'],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '处理完成');
      expect(snapshot.etaLabel, contains('音频 8/8 · 视觉 8/8 · 融合 8/8'));
      expect(snapshot.chunkProgress!.audioBar.percent, 100);
      expect(snapshot.chunkProgress!.visionBar.percent, 100);
      expect(snapshot.chunkProgress!.synthesisBar.percent, 100);
      expect(snapshot.chunkProgress!.overallBar.percent, 100);
      expect(snapshot.chunkProgress!.audioBar.done, 8);
      expect(snapshot.chunkProgress!.visionBar.done, 8);
      expect(snapshot.chunkProgress!.synthesisBar.done, 8);
    });

    test('maps processing data without chunkProgress gracefully', () {
      const data = VideoSummaryProcessingData(
        progress: 0.3,
        currentMessage: '正在启动分析引擎...',
        statusLog: [],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.progress, 0.3);
      expect(snapshot.statusLabel, '处理中');
      // When chunkProgress is null, etaLabel falls back to currentMessage.
      expect(snapshot.etaLabel, '正在启动分析引擎...');
      expect(snapshot.chunkProgress, isNull);
    });

    test('maps processing data without chunkProgress and empty message', () {
      const data = VideoSummaryProcessingData(
        progress: 0.0,
        currentMessage: '',
        statusLog: [],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.etaLabel, '正在准备处理内容。');
      expect(snapshot.chunkProgress, isNull);
    });
  });
}
