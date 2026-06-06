/// Global Chat / Global QA 域请求/响应 DTO，与后端 schemas 对齐。
library;

import 'video_qa_dto.dart';

/// 引用结构（对应 CitedSource）。
class CitedSource {
  const CitedSource({
    this.videoId,
    this.taskId,
    this.videoName,
    this.timeRange,
    this.quote,
    this.score,
  });

  final String? videoId;
  final String? taskId;
  final String? videoName;
  final String? timeRange;
  final String? quote;
  final double? score;

  factory CitedSource.fromJson(Map<String, dynamic> json) {
    return CitedSource(
      videoId: json['video_id'] as String?,
      taskId: json['task_id'] as String?,
      videoName: json['video_name'] as String?,
      timeRange: json['time_range'] as String?,
      quote: json['quote'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (videoId != null) 'video_id': videoId,
        if (taskId != null) 'task_id': taskId,
        if (videoName != null) 'video_name': videoName,
        if (timeRange != null) 'time_range': timeRange,
        if (quote != null) 'quote': quote,
        if (score != null) 'score': score,
      };
}

/// POST /api/v1/kbs/{kbid}/chats 请求体。
class GlobalChatCreateRequest {
  const GlobalChatCreateRequest({
    required this.kbid,
    this.chatTitle,
  });

  final String kbid;
  final String? chatTitle;

  Map<String, dynamic> toJson() => {
        'kbid': kbid,
        if (chatTitle != null) 'chat_title': chatTitle,
      };
}

/// PATCH /api/v1/kbs/{kbid}/chats/{chat_id} 请求体。
class GlobalChatUpdateRequest {
  const GlobalChatUpdateRequest({required this.chatTitle});

  final String chatTitle;

  Map<String, dynamic> toJson() => {'chat_title': chatTitle};
}

/// GlobalChatSession 响应 data 对象。
class GlobalChatSessionResponseData {
  const GlobalChatSessionResponseData({
    required this.chatId,
    required this.kbid,
    required this.chatTitle,
    this.createdAt,
  });

  final String chatId;
  final String kbid;
  final String chatTitle;
  final String? createdAt;

  factory GlobalChatSessionResponseData.fromJson(Map<String, dynamic> json) {
    return GlobalChatSessionResponseData(
      chatId: json['chat_id'] as String? ?? '',
      kbid: json['kbid'] as String? ?? '',
      chatTitle: json['chat_title'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}

/// DELETE chat 响应 data。
class GlobalChatDeleteResponseData {
  const GlobalChatDeleteResponseData({required this.chatId});

  final String chatId;

  factory GlobalChatDeleteResponseData.fromJson(Map<String, dynamic> json) {
    return GlobalChatDeleteResponseData(
      chatId: json['chat_id'] as String? ?? '',
    );
  }
}

/// POST /api/v1/kbs/{kbid}/chats/{chat_id}/qa 请求体。
class GlobalQACreateRequest {
  const GlobalQACreateRequest({
    required this.questionContent,
    this.attachments = const [],
  });

  final String questionContent;
  final List<AttachmentInfo> attachments;

  Map<String, dynamic> toJson() => {
        'question_content': questionContent,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

/// PATCH /api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id} 请求体。
class GlobalQAUpdateRequest {
  const GlobalQAUpdateRequest({required this.regenerate});

  final bool regenerate;

  Map<String, dynamic> toJson() => {'regenerate': regenerate};
}

/// GlobalQARecord 响应 data 对象。
class GlobalQARecordResponseData {
  const GlobalQARecordResponseData({
    required this.qaId,
    required this.chatId,
    required this.questionContent,
    this.answerContent,
    this.attachments = const [],
    this.citedSources = const [],
    this.questionTime,
  });

  final String qaId;
  final String chatId;
  final String questionContent;
  final String? answerContent;
  final List<AttachmentInfo> attachments;
  final List<CitedSource> citedSources;
  final String? questionTime;

  factory GlobalQARecordResponseData.fromJson(Map<String, dynamic> json) {
    return GlobalQARecordResponseData(
      qaId: json['qa_id'] as String? ?? '',
      chatId: json['chat_id'] as String? ?? '',
      questionContent: json['question_content'] as String? ?? '',
      answerContent: json['answer_content'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map(
                (e) => AttachmentInfo.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      citedSources: (json['cited_sources'] as List<dynamic>?)
              ?.map(
                (e) => CitedSource.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      questionTime: json['question_time'] as String?,
    );
  }
}
