/// Video Summary Task 域请求/响应 DTO，与后端 schemas 对齐。
library;

/// POST /api/v1/tasks 请求体。
class TaskCreateRequest {
  const TaskCreateRequest({
    required this.kbid,
    required this.videoId,
    this.userInitialPreference,
  });

  final String kbid;
  final String videoId;
  final String? userInitialPreference;

  Map<String, dynamic> toJson() => {
        'kbid': kbid,
        'video_id': videoId,
        if (userInitialPreference != null)
          'user_initial_preference': userInitialPreference,
      };
}

/// PATCH /api/v1/tasks/{task_id} 请求体（用户可写字段）。
class TaskUpdateRequest {
  const TaskUpdateRequest({
    this.draftSummary,
    this.userGuidance,
    this.title,
  });

  final String? draftSummary;
  final String? userGuidance;
  final String? title;

  Map<String, dynamic> toJson() => {
        if (draftSummary != null) 'draft_summary': draftSummary,
        if (userGuidance != null) 'user_guidance': userGuidance,
        if (title != null) 'title': title,
      };
}

/// VideoSummaryTask 响应 data 对象。
class VideoSummaryTaskResponseData {
  const VideoSummaryTaskResponseData({
    required this.taskId,
    required this.kbid,
    required this.videoId,
    required this.workflowState,
    this.userInitialPreference,
    this.draftSummary,
    this.userGuidance,
    this.finalSummary,
    this.title,
    this.summaryVectorIds,
    this.createdAt,
    this.updatedAt,
  });

  final String taskId;
  final String kbid;
  final String videoId;
  final String workflowState;
  final String? userInitialPreference;
  final String? draftSummary;
  final String? userGuidance;
  final String? finalSummary;
  final String? title;
  final List<String>? summaryVectorIds;
  final String? createdAt;
  final String? updatedAt;

  factory VideoSummaryTaskResponseData.fromJson(Map<String, dynamic> json) {
    return VideoSummaryTaskResponseData(
      taskId: json['task_id'] as String? ?? '',
      kbid: json['kbid'] as String? ?? '',
      videoId: json['video_id'] as String? ?? '',
      workflowState: json['workflow_state'] as String? ?? '',
      userInitialPreference: json['user_initial_preference'] as String?,
      draftSummary: json['draft_summary'] as String?,
      userGuidance: json['user_guidance'] as String?,
      finalSummary: json['final_summary'] as String?,
      title: json['title'] as String?,
      summaryVectorIds: (json['summary_vector_ids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// DELETE /api/v1/tasks/{task_id} 响应 data。
class TaskDeleteResponseData {
  const TaskDeleteResponseData({required this.taskId});

  final String taskId;

  factory TaskDeleteResponseData.fromJson(Map<String, dynamic> json) {
    return TaskDeleteResponseData(taskId: json['task_id'] as String? ?? '');
  }
}

// ──── new.md 新增 Workflow DTO ────

/// POST /api/v1/tasks/{task_id}/start-analysis 响应 data。
class StartAnalysisResponseData {
  const StartAnalysisResponseData({
    required this.taskId,
    this.celeryTaskId,
    this.threadId,
    this.workflowState,
    this.acceptedAt,
    this.message,
  });

  final String taskId;
  final String? celeryTaskId;
  final String? threadId;
  final String? workflowState;
  final String? acceptedAt;
  final String? message;

  factory StartAnalysisResponseData.fromJson(Map<String, dynamic> json) {
    return StartAnalysisResponseData(
      taskId: json['task_id'] as String? ?? '',
      celeryTaskId: json['celery_task_id'] as String?,
      threadId: json['thread_id'] as String?,
      workflowState: json['workflow_state'] as String?,
      acceptedAt: json['accepted_at'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// POST /api/v1/tasks/{task_id}/approve-and-finalize 请求体。
class ApproveAndFinalizeRequest {
  const ApproveAndFinalizeRequest({
    this.editedAggregatedChunkInsights,
    this.humanGuidance,
  });

  final String? editedAggregatedChunkInsights;
  final String? humanGuidance;

  Map<String, dynamic> toJson() => {
        if (editedAggregatedChunkInsights != null)
          'edited_aggregated_chunk_insights': editedAggregatedChunkInsights,
        if (humanGuidance != null) 'human_guidance': humanGuidance,
      };
}

/// POST /api/v1/tasks/{task_id}/approve-and-finalize 响应 data。
class ApproveAndFinalizeResponseData {
  const ApproveAndFinalizeResponseData({
    required this.taskId,
    this.celeryTaskId,
    this.threadId,
    this.workflowState,
    this.acceptedAt,
    this.message,
  });

  final String taskId;
  final String? celeryTaskId;
  final String? threadId;
  final String? workflowState;
  final String? acceptedAt;
  final String? message;

  factory ApproveAndFinalizeResponseData.fromJson(Map<String, dynamic> json) {
    return ApproveAndFinalizeResponseData(
      taskId: json['task_id'] as String? ?? '',
      celeryTaskId: json['celery_task_id'] as String?,
      threadId: json['thread_id'] as String?,
      workflowState: json['workflow_state'] as String?,
      acceptedAt: json['accepted_at'] as String?,
      message: json['message'] as String?,
    );
  }
}
