/// WebSocket 事件模型，与后端 /ws/progress 协议对齐（new.md 新增）。
library;

/// WebSocket 事件类型。
enum WSEventType {
  progress,
  completed,
  error,
  statusUpdate,
  reconnectAck,
}

/// 事件作用域。
enum WSScope {
  videoResource,
  videoSummaryTask,
  videoQa,
  globalChat,
}

/// 处理阶段。
enum WSStage {
  extraction,
  transcribing,
  extractingKeyframes,
  ragRetrieval,
  llmReasoning,
  synthesis,
  cleanup,
}

/// WS 事件统一信封（对应 WSEventEnvelope）。
class WSEventEnvelope {
  const WSEventEnvelope({
    required this.eventId,
    required this.eventType,
    required this.scope,
    required this.scopeId,
    required this.sequence,
    this.stage,
    this.substage,
    this.status,
    this.progress,
    this.message,
    this.payload = const {},
    this.traceId,
    this.producedAt,
    this.userId,
  });

  final String eventId;
  final WSEventType eventType;
  final WSScope scope;
  final String scopeId;
  final int sequence;
  final WSStage? stage;
  final String? substage;
  final String? status;
  final int? progress;
  final String? message;
  final Map<String, dynamic> payload;
  final String? traceId;
  final String? producedAt;
  final String? userId;

  factory WSEventEnvelope.fromJson(Map<String, dynamic> json) =>
      WSEventEnvelope(
        eventId: json['event_id'] as String? ?? '',
        eventType: _parseEventType(json['event_type'] as String? ?? ''),
        scope: _parseScope(json['scope'] as String? ?? ''),
        scopeId: json['scope_id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        stage: json['stage'] != null
            ? _parseStage(json['stage'] as String)
            : null,
        substage: json['substage'] as String?,
        status: json['status'] as String?,
        progress: json['progress'] as int?,
        message: json['message'] as String?,
        payload: _toStrMap(json['payload']),
        traceId: json['trace_id'] as String?,
        producedAt: json['produced_at'] as String?,
        userId: json['user_id'] as String?,
      );

  static WSEventType _parseEventType(String s) => switch (s) {
        'progress' => WSEventType.progress,
        'completed' => WSEventType.completed,
        'error' => WSEventType.error,
        'status_update' => WSEventType.statusUpdate,
        'reconnect_ack' => WSEventType.reconnectAck,
        _ => WSEventType.statusUpdate,
      };

  static WSScope _parseScope(String s) => switch (s) {
        'video_resource' => WSScope.videoResource,
        'video_summary_task' => WSScope.videoSummaryTask,
        'video_qa' => WSScope.videoQa,
        'global_chat' => WSScope.globalChat,
        _ => WSScope.videoSummaryTask,
      };

  static WSStage _parseStage(String s) => switch (s) {
        'extraction' => WSStage.extraction,
        'transcribing' => WSStage.transcribing,
        'extracting_keyframes' => WSStage.extractingKeyframes,
        'rag_retrieval' => WSStage.ragRetrieval,
        'llm_reasoning' => WSStage.llmReasoning,
        'synthesis' => WSStage.synthesis,
        'cleanup' => WSStage.cleanup,
        _ => WSStage.extraction,
      };

  static Map<String, dynamic> _toStrMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }
}
