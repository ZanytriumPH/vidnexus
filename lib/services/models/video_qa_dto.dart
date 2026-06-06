/// Video QA 域请求/响应 DTO，与后端 schemas 对齐。
library;

/// 附件结构（对应 AttachmentInfo）。
class AttachmentInfo {
  const AttachmentInfo({
    required this.name,
    required this.ossKey,
    required this.mimeType,
    required this.sizeBytes,
    this.presignedUrl,
  });

  final String name;
  final String ossKey;
  final String mimeType;
  final int sizeBytes;
  final String? presignedUrl;

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) {
    return AttachmentInfo(
      name: json['name'] as String? ?? '',
      ossKey: json['oss_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      presignedUrl: json['presigned_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'oss_key': ossKey,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      };
}

/// POST /api/v1/tasks/{task_id}/qa 请求体。
class VideoQACreateRequest {
  const VideoQACreateRequest({
    required this.taskId,
    this.startTime,
    this.endTime,
    required this.questionContent,
    this.attachments = const [],
  });

  final String taskId;
  final String? startTime;
  final String? endTime;
  final String questionContent;
  final List<AttachmentInfo> attachments;

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        'question_content': questionContent,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

/// PATCH /api/v1/tasks/{task_id}/qa/{qa_id} 请求体。
class VideoQAUpdateRequest {
  const VideoQAUpdateRequest({required this.regenerate});

  final bool regenerate;

  Map<String, dynamic> toJson() => {'regenerate': regenerate};
}

/// VideoQARecord 响应 data 对象。
class VideoQARecordResponseData {
  const VideoQARecordResponseData({
    required this.qaId,
    required this.taskId,
    this.startTime,
    this.endTime,
    required this.questionContent,
    this.answerContent,
    this.attachments = const [],
    this.citedSources = const [],
    this.questionTime,
  });

  final String qaId;
  final String taskId;
  final String? startTime;
  final String? endTime;
  final String questionContent;
  final String? answerContent;
  final List<AttachmentInfo> attachments;
  final List<Map<String, dynamic>> citedSources;
  final String? questionTime;

  factory VideoQARecordResponseData.fromJson(Map<String, dynamic> json) {
    return VideoQARecordResponseData(
      qaId: json['qa_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      questionContent: json['question_content'] as String? ?? '',
      answerContent: json['answer_content'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map(
                (e) => AttachmentInfo.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      citedSources: (json['cited_sources'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      questionTime: json['question_time'] as String?,
    );
  }
}

/// DELETE QA 响应 data。
class QADeleteResponseData {
  const QADeleteResponseData({required this.qaId});

  final String qaId;

  factory QADeleteResponseData.fromJson(Map<String, dynamic> json) {
    return QADeleteResponseData(qaId: json['qa_id'] as String? ?? '');
  }
}
