import 'package:vidnexus/services/models/video_qa_dto.dart';

/// SSE 事件类型枚举（与后端 text/event-stream 对齐）。
enum SSEEventType { start, delta, done, error, progress }

/// 通用 SSE 事件结构。
class SSEEvent {
  const SSEEvent({
    required this.type,
    this.event,
    this.data,
    this.id,
    this.retry,
  });

  /// 事件类型。
  final SSEEventType type;

  /// 原始 event 字段值。
  final String? event;

  /// 解析后的 JSON data（Map 或 String）。
  final dynamic data;

  /// SSE 事件 ID。
  final String? id;

  /// 重连间隔（毫秒）。
  final int? retry;

  /// 尝试将 data 解析为指定类型。
  T? parseData<T>(T Function(Map<String, dynamic>) fromJson) {
    if (data is Map<String, dynamic>) {
      return fromJson(data as Map<String, dynamic>);
    }
    return null;
  }
}

// ──── Time Travel QA SSE 载荷 ────

/// POST /api/v1/tasks/{task_id}/time-travel-qa/stream 请求体。
class TimeTravelQAStreamRequest {
  const TimeTravelQAStreamRequest({
    required this.timestamp,
    required this.questionContent,
    this.attachments = const [],
    this.windowSeconds,
  });

  final String timestamp; // 格式：HH:MM:SS
  final String questionContent; // 也可传 question 别名
  final List<AttachmentInfo> attachments;
  final int? windowSeconds; // 5~300，null=全量 RAG

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'question_content': questionContent,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        if (windowSeconds != null) 'window_seconds': windowSeconds,
      };
}

/// SSE start 事件的 data 载荷（time-travel QA）。
class TimeTravelQAStartData {
  const TimeTravelQAStartData({
    required this.taskId,
    required this.qaId,
    this.timestamp,
  });

  final String taskId;
  final String qaId;
  final String? timestamp;

  factory TimeTravelQAStartData.fromJson(Map<String, dynamic> json) =>
      TimeTravelQAStartData(
        taskId: json['task_id'] as String? ?? '',
        qaId: json['qa_id'] as String? ?? '',
        timestamp: json['timestamp'] as String?,
      );
}

/// SSE delta 事件的 data 载荷。
class SSEDeltaData {
  const SSEDeltaData({
    required this.taskId,
    required this.qaId,
    required this.chunk,
    required this.sequence,
    this.timestamp,
  });

  final String taskId;
  final String qaId;
  final String chunk;
  final int sequence;
  final String? timestamp;

  factory SSEDeltaData.fromJson(Map<String, dynamic> json) => SSEDeltaData(
        taskId: json['task_id'] as String? ?? '',
        qaId: json['qa_id'] as String? ?? '',
        chunk: json['chunk'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        timestamp: json['timestamp'] as String?,
      );
}

/// SSE done 事件的 data 载荷（time-travel QA）。
class TimeTravelQADoneData {
  const TimeTravelQADoneData({
    required this.taskId,
    required this.qaId,
    this.answerContent,
    this.citedSources,
    this.timestamp,
  });

  final String taskId;
  final String qaId;
  final String? answerContent;
  final List<Map<String, dynamic>>? citedSources;
  final String? timestamp;

  factory TimeTravelQADoneData.fromJson(Map<String, dynamic> json) =>
      TimeTravelQADoneData(
        taskId: json['task_id'] as String? ?? '',
        qaId: json['qa_id'] as String? ?? '',
        answerContent: json['answer_content'] as String?,
        citedSources: (json['cited_sources'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        timestamp: json['timestamp'] as String?,
      );
}

// ──── Global QA SSE 载荷 ────

/// SSE start 事件的 data 载荷（global QA）。
class GlobalQAStartData {
  const GlobalQAStartData({
    required this.kbid,
    required this.chatId,
    required this.qaId,
    this.timestamp,
  });

  final String kbid;
  final String chatId;
  final String qaId;
  final String? timestamp;

  factory GlobalQAStartData.fromJson(Map<String, dynamic> json) =>
      GlobalQAStartData(
        kbid: json['kbid'] as String? ?? '',
        chatId: json['chat_id'] as String? ?? '',
        qaId: json['qa_id'] as String? ?? '',
        timestamp: json['timestamp'] as String?,
      );
}

/// SSE done 事件的 data 载荷（global QA，带 cited_sources）。
class GlobalQADoneData {
  const GlobalQADoneData({
    required this.kbid,
    required this.chatId,
    required this.qaId,
    this.answerContent,
    this.citedSources,
    this.timestamp,
  });

  final String kbid;
  final String chatId;
  final String qaId;
  final String? answerContent;
  final List<Map<String, dynamic>>? citedSources;
  final String? timestamp;

  factory GlobalQADoneData.fromJson(Map<String, dynamic> json) =>
      GlobalQADoneData(
        kbid: json['kbid'] as String? ?? '',
        chatId: json['chat_id'] as String? ?? '',
        qaId: json['qa_id'] as String? ?? '',
        answerContent: json['answer_content'] as String?,
        citedSources: (json['cited_sources'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        timestamp: json['timestamp'] as String?,
      );
}

/// SSE progress 事件的 data 载荷（global QA，ReAct agent 进度）。
class GlobalQAProgressData {
  const GlobalQAProgressData({
    required this.phase,
    required this.message,
  });

  /// Agent 当前阶段：thinking | searching | retrieved | loading | generating
  final String phase;

  /// 前端直接展示的可读文案
  final String message;

  factory GlobalQAProgressData.fromJson(Map<String, dynamic> json) =>
      GlobalQAProgressData(
        phase: json['phase'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}
