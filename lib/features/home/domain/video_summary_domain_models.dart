import '../video_summary_models.dart';

/// 这里只放 repository 可稳定返回的业务结果数据，不放界面展示结构。

enum VideoSummaryChunkProgressStage { running, finished }

class VideoSummaryChunkProgressData {
  const VideoSummaryChunkProgressData({
    required this.stage,
    required this.totalChunks,
    required this.doneCount,
    required this.overallPercent,
  });

  final VideoSummaryChunkProgressStage stage;
  final int totalChunks;
  final int doneCount;
  final int overallPercent;

  /// 从 WS 下发的 payload 直接构造（新后端单轨 honest 数据）。
  ///
  /// 后端 WebSocket payload 下发：
  /// - total_chunks: 总分片数
  /// - done_count: 已完成分片数
  /// - overall_percent: 完成百分比 0-100
  /// - stage: "running" | "finished"
  factory VideoSummaryChunkProgressData.fromPayload(
    Map<String, dynamic>? payload, {
    int fallbackTotalChunks = 5,
  }) {
    if (payload == null || payload.isEmpty) {
      return VideoSummaryChunkProgressData(
        stage: VideoSummaryChunkProgressStage.running,
        totalChunks: fallbackTotalChunks,
        doneCount: 0,
        overallPercent: 0,
      );
    }
    final totalChunks =
        (payload['total_chunks'] as int?) ?? fallbackTotalChunks;
    final doneCount = (payload['done_count'] as int?) ?? 0;
    final overallPercent = (payload['overall_percent'] as int?) ??
        (totalChunks > 0 ? ((doneCount / totalChunks) * 100).round() : 0);
    final stageStr = payload['stage'] as String?;
    return VideoSummaryChunkProgressData(
      stage: stageStr == 'finished'
          ? VideoSummaryChunkProgressStage.finished
          : VideoSummaryChunkProgressStage.running,
      totalChunks: totalChunks,
      doneCount: doneCount,
      overallPercent: overallPercent,
    );
  }
}

class VideoSummaryProcessingData {
  const VideoSummaryProcessingData({
    required this.progress,
    required this.currentMessage,
    this.chunkProgress,
    this.statusLog = const [],
  });

  /// 整体进度 0.0–1.0，驱动 HeroCard 总体进度条。
  final double progress;

  /// 当前后端状态消息，用于 eta 标签展示。
  final String currentMessage;

  /// 单轨分片进度，用于 StreamlitProgressCard。
  final VideoSummaryChunkProgressData? chunkProgress;

  /// 最近 N 条后端状态消息，用于分片面板底部的滚动日志。
  final List<String> statusLog;
}

class VideoSummaryDraftData {
  const VideoSummaryDraftData({required this.paragraphs});

  final List<String> paragraphs;
}

class VideoSummaryReferenceRange {
  const VideoSummaryReferenceRange({
    required this.startSeconds,
    required this.endSeconds,
    required this.topic,
  });

  final int startSeconds;
  final int endSeconds;
  final String topic;

  TimestampRangeSelection toRangeSelection() {
    return TimestampRangeSelection(
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
  }
}

class VideoSummaryFinalResultData {
  const VideoSummaryFinalResultData({
    required this.body,
    required this.references,
  });

  final String body;
  final List<VideoSummaryReferenceRange> references;
}

class VideoSummaryChatReplyData {
  const VideoSummaryChatReplyData({
    required this.text,
    this.reference,
    this.citedSources,
  });

  final String text;
  final VideoSummaryReferenceRange? reference;
  final List<Map<String, dynamic>>? citedSources;
}

// ──── Phase 3: 后端任务状态映射 ────

/// 对齐后端 API 的 workflow_state 字段。
enum WorkflowState {
  draftGenerating,
  waitingUserApproval,
  finalGenerating,
  completed,
  failed;

  /// 从 API 返回的 snake_case 字符串解析。
  factory WorkflowState.fromApi(String value) {
    return switch (value) {
      'DRAFT_GENERATING' => WorkflowState.draftGenerating,
      'WAITING_USER_APPROVAL' => WorkflowState.waitingUserApproval,
      'FINAL_GENERATING' => WorkflowState.finalGenerating,
      'COMPLETED' => WorkflowState.completed,
      'FAILED' => WorkflowState.failed,
      _ => WorkflowState.failed,
    };
  }

  /// 是否为终态（轮询应停止）。
  bool get isTerminal =>
      this == WorkflowState.waitingUserApproval ||
      this == WorkflowState.completed ||
      this == WorkflowState.failed;

  /// 中文状态标签。
  String get label {
    return switch (this) {
      WorkflowState.draftGenerating => '生成初稿中',
      WorkflowState.waitingUserApproval => '等待用户审批',
      WorkflowState.finalGenerating => '生成终稿中',
      WorkflowState.completed => '已完成',
      WorkflowState.failed => '处理失败',
    };
  }
}

/// 聚合 Task 的身份与状态信息，供 Repository → Mapper 传递。
class VideoSummaryTaskInfo {
  const VideoSummaryTaskInfo({
    required this.taskId,
    required this.videoId,
    required this.kbid,
    required this.workflowState,
    this.draftSummary,
    this.finalSummary,
    this.title,
    this.fileName,
    this.userInitialPreference,
  });

  final String taskId;
  final String videoId;
  final String kbid;
  final WorkflowState workflowState;
  final String? draftSummary;
  final String? finalSummary;
  final String? title;
  final String? fileName;
  final String? userInitialPreference;
}

/// 任务处理失败异常（workflow_state = FAILED）。
class TaskFailedException implements Exception {
  const TaskFailedException(this.taskId);

  final String taskId;

  @override
  String toString() => 'Task $taskId failed on server';
}