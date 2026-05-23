import '../video_summary_models.dart';

/// 这里只放 repository 可稳定返回的业务结果数据，不放界面展示结构。
enum VideoSummaryProcessingPhase { preprocessing, analysis, synthesis }

enum VideoSummaryProcessingStage {
  acquiringVideo,
  extractingAudio,
  extractingFrames,
  transcribingAudio,
  bootingWorkflow,
  planningChunks,
  dispatchingChunks,
  analyzingAudioChunks,
  analyzingVisionChunks,
  synthesizingChunks,
  aggregatingChunks,
  waitingHumanReview,
}

enum VideoSummaryChunkProgressStage { running, finished }

class VideoSummaryChunkProgressData {
  const VideoSummaryChunkProgressData({
    required this.stage,
    required this.totalChunks,
    required this.audioDone,
    required this.visionDone,
    required this.synthesisDone,
    required this.overallDone,
    required this.overallTotal,
    required this.overallPercent,
  });

  final VideoSummaryChunkProgressStage stage;
  final int totalChunks;
  final int audioDone;
  final int visionDone;
  final int synthesisDone;
  final int overallDone;
  final int overallTotal;
  final int overallPercent;
}

class VideoSummaryProcessingStepData {
  const VideoSummaryProcessingStepData({
    required this.phase,
    required this.progress,
    required this.completedUnits,
    required this.totalUnits,
  });

  final VideoSummaryProcessingPhase phase;
  final int progress;
  final int completedUnits;
  final int totalUnits;
}

class VideoSummaryProcessingData {
  const VideoSummaryProcessingData({
    required this.progress,
    required this.currentStage,
    required this.currentMessage,
    required this.steps,
    this.chunkProgress,
  });

  final double progress;
  final VideoSummaryProcessingStage currentStage;
  final String currentMessage;
  final List<VideoSummaryProcessingStepData> steps;
  final VideoSummaryChunkProgressData? chunkProgress;
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
  const VideoSummaryChatReplyData({required this.text, this.reference});

  final String text;
  final VideoSummaryReferenceRange? reference;
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