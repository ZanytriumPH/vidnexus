import '../video_summary_models.dart';

/// 这里只放 repository 可稳定返回的业务结果数据，不放界面展示结构。

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

  /// 从 WS 下发的 overall_percent 推导 3 轨分片进度。
  ///
  /// 后端 WebSocket 仅下发单一 `progress` 值（即 overall_percent），
  /// 不含 audio_done / vision_done / synthesis_done 分片粒度数据。
  /// 本工厂使用**平滑曲线**从 overall 值反推各轨进度：
  ///
  /// - 音频分片：overall 0%→60% 期间线性增长到 100%
  /// - 视觉分片：overall 20%→80% 期间线性增长到 100%
  /// - 融合分片：overall 50%→95% 期间线性增长到 100%
  ///
  /// [wsProgress] 为 WS 下发的 0-100 整体百分比。
  /// [wsStageLabel] 已废弃——新模型不再依赖阶段判断。
  /// [previous] 为上一次估算结果，用于保证各轨不回退。
  factory VideoSummaryChunkProgressData.estimate({
    required int wsProgress,
    String? wsStageLabel,
    VideoSummaryChunkProgressData? previous,
  }) {
    final totalChunks = previous?.totalChunks ?? 5;
    final fraction = (wsProgress / 100).clamp(0.0, 1.0);

    // ── 平滑曲线：各轨随 overall 推进而增长 ──
    int audioDone;
    if (fraction <= 0.0) {
      audioDone = 0;
    } else if (fraction >= 0.6) {
      audioDone = totalChunks;
    } else {
      audioDone = (fraction / 0.6 * totalChunks).round();
    }

    int visionDone;
    if (fraction <= 0.2) {
      visionDone = 0;
    } else if (fraction >= 0.8) {
      visionDone = totalChunks;
    } else {
      visionDone = ((fraction - 0.2) / 0.6 * totalChunks).round();
    }

    int synthesisDone;
    if (fraction <= 0.5) {
      synthesisDone = 0;
    } else if (fraction >= 0.95) {
      synthesisDone = totalChunks;
    } else {
      synthesisDone = ((fraction - 0.5) / 0.45 * totalChunks).round();
    }

    // ── 夹紧 + 不回退 ──
    audioDone = audioDone.clamp(0, totalChunks);
    visionDone = visionDone.clamp(0, totalChunks);
    synthesisDone = synthesisDone.clamp(0, totalChunks);

    if (previous != null) {
      audioDone = audioDone < previous.audioDone ? previous.audioDone : audioDone;
      visionDone = visionDone < previous.visionDone ? previous.visionDone : visionDone;
      synthesisDone =
          synthesisDone < previous.synthesisDone ? previous.synthesisDone : synthesisDone;
    }

    final overallTotal = totalChunks * 2;
    final overallDone = (audioDone + visionDone).clamp(0, overallTotal);
    final overallPercent = overallTotal > 0
        ? (overallDone / overallTotal * 100).round()
        : 0;

    return VideoSummaryChunkProgressData(
      stage: wsProgress >= 100
          ? VideoSummaryChunkProgressStage.finished
          : VideoSummaryChunkProgressStage.running,
      totalChunks: totalChunks,
      audioDone: audioDone,
      visionDone: visionDone,
      synthesisDone: synthesisDone,
      overallDone: overallDone,
      overallTotal: overallTotal,
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

  /// 3 轨分片进度，用于 StreamlitProgressCard。
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