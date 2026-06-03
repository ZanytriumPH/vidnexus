import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';
import 'package:vidnexus/services/websocket/ws_models.dart';

void main() {
  // ──── WSEventEnvelope 解析 ────

  group('WSEventEnvelope parsing', () {
    test('parses progress event', () {
      final json = {
        'event_id': 'evt_001',
        'schema_version': '1.0',
        'event_type': 'progress',
        'trace_id': 'trc_001',
        'produced_at': '2026-05-23T10:00:00+00:00',
        'tenant_id': 'default',
        'user_id': 'usr_001',
        'scope': 'video_summary_task',
        'scope_id': 'task_001',
        'sequence': 42,
        'stage': 'rag_retrieval',
        'substage': 'chunk_processing',
        'status': 'RUNNING',
        'progress': 45,
        'message': '正在分析分片：9/20 完成',
        'payload': {
          'total_chunks': 20,
          'done_count': 9,
          'overall_percent': 45,
          'stage': 'running',
        },
        'source': {
          'service': 'progress_publish_service',
          'instance_id': 'worker-01',
        },
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventId, 'evt_001');
      expect(event.eventType, WSEventType.progress);
      expect(event.scope, WSScope.videoSummaryTask);
      expect(event.scopeId, 'task_001');
      expect(event.sequence, 42);
      expect(event.stage, WSStage.ragRetrieval);
      expect(event.status, 'RUNNING');
      expect(event.progress, 45);
      expect(event.message, '正在分析分片：9/20 完成');
      expect(event.payload['total_chunks'], 20);
      expect(event.payload['done_count'], 9);
      expect(event.payload['overall_percent'], 45);
      expect(event.payload['stage'], 'running');
      expect(event.userId, 'usr_001');
    });

    test('parses completed event', () {
      final json = {
        'event_id': 'evt_002',
        'event_type': 'completed',
        'scope': 'video_summary_task',
        'scope_id': 'task_001',
        'sequence': 100,
        'status': 'COMPLETED',
        'progress': 100,
        'message': 'Task completed',
        'payload': {'final_summary': 'done'},
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventType, WSEventType.completed);
      expect(event.progress, 100);
      expect(event.payload['final_summary'], 'done');
    });

    test('parses error event', () {
      final json = {
        'event_id': 'evt_003',
        'event_type': 'error',
        'scope': 'video_summary_task',
        'scope_id': 'task_001',
        'sequence': 10,
        'status': 'FAILED',
        'message': 'Transcription service unavailable',
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventType, WSEventType.error);
      expect(event.status, 'FAILED');
      expect(event.message, 'Transcription service unavailable');
    });

    test('parses status_update event', () {
      final json = {
        'event_id': 'evt_004',
        'event_type': 'status_update',
        'scope': 'video_resource',
        'scope_id': 'vid_001',
        'sequence': 5,
        'status': 'TRANSCRIBING',
        'message': 'Transcribing audio...',
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventType, WSEventType.statusUpdate);
      expect(event.scope, WSScope.videoResource);
    });

    test('parses reconnect_ack event', () {
      final json = {
        'event_id': 'evt_005',
        'event_type': 'reconnect_ack',
        'scope': 'video_summary_task',
        'scope_id': 'task_001',
        'sequence': 88,
        'status': 'RECONNECTED',
        'payload': {'last_sequence': 88},
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventType, WSEventType.reconnectAck);
      expect(event.payload['last_sequence'], 88);
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'event_id': 'evt_006',
        'event_type': 'progress',
        'scope': 'video_summary_task',
        'scope_id': 'task_001',
        'sequence': 1,
      };

      final event = WSEventEnvelope.fromJson(json);

      expect(event.eventType, WSEventType.progress);
      expect(event.progress, isNull);
      expect(event.message, isNull);
      expect(event.stage, isNull);
      expect(event.payload, isEmpty);
    });
  });

  // ──── 枚举解析 ────

  group('Enum parsing', () {
    test('parses all WSEventType values', () {
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e1',
          'event_type': 'progress',
          'scope': 'video_summary_task',
          'scope_id': 's1',
          'sequence': 1,
        }).eventType,
        WSEventType.progress,
      );
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e2',
          'event_type': 'completed',
          'scope': 'video_summary_task',
          'scope_id': 's2',
          'sequence': 2,
        }).eventType,
        WSEventType.completed,
      );
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e3',
          'event_type': 'error',
          'scope': 'video_summary_task',
          'scope_id': 's3',
          'sequence': 3,
        }).eventType,
        WSEventType.error,
      );
    });

    test('parses all WSScope values', () {
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e1',
          'event_type': 'progress',
          'scope': 'video_resource',
          'scope_id': 's1',
          'sequence': 1,
        }).scope,
        WSScope.videoResource,
      );
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e2',
          'event_type': 'progress',
          'scope': 'global_chat',
          'scope_id': 's2',
          'sequence': 2,
        }).scope,
        WSScope.globalChat,
      );
    });

    test('parses all WSStage values', () {
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e1',
          'event_type': 'progress',
          'scope': 'video_summary_task',
          'scope_id': 's1',
          'sequence': 1,
          'stage': 'extraction',
        }).stage,
        WSStage.extraction,
      );
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e2',
          'event_type': 'progress',
          'scope': 'video_summary_task',
          'scope_id': 's2',
          'sequence': 2,
          'stage': 'llm_reasoning',
        }).stage,
        WSStage.llmReasoning,
      );
      expect(
        WSEventEnvelope.fromJson({
          'event_id': 'e3',
          'event_type': 'progress',
          'scope': 'video_summary_task',
          'scope_id': 's3',
          'sequence': 3,
          'stage': 'synthesis',
        }).stage,
        WSStage.synthesis,
      );
    });

    test('unknown values fallback to defaults', () {
      final event = WSEventEnvelope.fromJson({
        'event_id': 'e1',
        'event_type': 'unknown_type',
        'scope': 'unknown_scope',
        'scope_id': 's1',
        'sequence': 1,
        'stage': 'unknown_stage',
      });

      expect(event.eventType, WSEventType.statusUpdate);
      expect(event.scope, WSScope.videoSummaryTask);
      expect(event.stage, WSStage.extraction);
    });
  });

  // ──── VideoSummaryChunkProgressData.fromPayload ────

  group('VideoSummaryChunkProgressData.fromPayload', () {
    test('parses payload with chunk progress data', () {
      final data = VideoSummaryChunkProgressData.fromPayload({
        'total_chunks': 10,
        'done_count': 4,
        'overall_percent': 40,
        'stage': 'running',
      });
      expect(data.totalChunks, 10);
      expect(data.doneCount, 4);
      expect(data.overallPercent, 40);
      expect(data.stage, VideoSummaryChunkProgressStage.running);
    });

    test('parses finished stage', () {
      final data = VideoSummaryChunkProgressData.fromPayload({
        'total_chunks': 8,
        'done_count': 8,
        'overall_percent': 100,
        'stage': 'finished',
      });
      expect(data.stage, VideoSummaryChunkProgressStage.finished);
      expect(data.doneCount, 8);
      expect(data.overallPercent, 100);
    });

    test('handles empty payload gracefully', () {
      final data = VideoSummaryChunkProgressData.fromPayload({});
      expect(data.totalChunks, 5); // fallback
      expect(data.doneCount, 0);
      expect(data.overallPercent, 0);
      expect(data.stage, VideoSummaryChunkProgressStage.running);
    });

    test('handles null payload gracefully', () {
      final data = VideoSummaryChunkProgressData.fromPayload(null);
      expect(data.totalChunks, 5);
      expect(data.doneCount, 0);
      expect(data.overallPercent, 0);
    });

    test('falls back to specified totalChunks when payload missing them', () {
      final data = VideoSummaryChunkProgressData.fromPayload(
        {'done_count': 2},
        fallbackTotalChunks: 12,
      );
      expect(data.totalChunks, 12);
      expect(data.doneCount, 2);
    });
  });
}
