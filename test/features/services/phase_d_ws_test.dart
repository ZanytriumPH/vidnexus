import 'package:flutter_test/flutter_test.dart';
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
        'message': 'Chunk processing: 9/20',
        'payload': {},
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
      expect(event.message, 'Chunk processing: 9/20');
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
}
