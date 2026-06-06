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
      expect(snapshot.chunkProgress!.chunkBar.label, '分片分析');
      expect(snapshot.chunkProgress!.chunkBar.total, 5);
      expect(snapshot.chunkProgress!.chunkBar.done, 0);
      expect(snapshot.chunkProgress!.chunkBar.percent, 0);
      expect(snapshot.statusLog, isEmpty);
    });

    test('maps chunk analysis processing data into mobile-facing labels', () {
      const data = VideoSummaryProcessingData(
        progress: 0.38,
        currentMessage: '正在分析分片：3/8 完成',
        chunkProgress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: 8,
          doneCount: 3,
          overallPercent: 38,
        ),
        statusLog: ['开始处理', '正在分析分片'],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '处理中');
      expect(snapshot.progress, 0.38);
      expect(snapshot.etaLabel, contains('分片 3/8 完成'));
      expect(snapshot.chunkProgress, isNotNull);
      expect(snapshot.chunkProgress!.chunkBar.done, 3);
      expect(snapshot.chunkProgress!.chunkBar.total, 8);
      expect(snapshot.chunkProgress!.chunkBar.percent, 38);
      expect(snapshot.statusLog, hasLength(2));
      expect(snapshot.statusLog, contains('开始处理'));
    });

    test('maps finished processing into completion-facing copy', () {
      const data = VideoSummaryProcessingData(
        progress: 1.0,
        currentMessage: '分片分析全部完成：共 8 个分片',
        chunkProgress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.finished,
          totalChunks: 8,
          doneCount: 8,
          overallPercent: 100,
        ),
        statusLog: ['处理完成'],
      );

      final snapshot = mapProcessingDataToSnapshot(data);

      expect(snapshot.statusLabel, '处理完成');
      expect(snapshot.etaLabel, contains('分片 8/8 完成'));
      expect(snapshot.chunkProgress!.chunkBar.percent, 100);
      expect(snapshot.chunkProgress!.chunkBar.done, 8);
      expect(snapshot.chunkProgress!.chunkBar.total, 8);
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
