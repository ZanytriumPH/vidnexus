import '../domain/video_summary_domain_models.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_presentation_models.dart';

ProcessingSnapshot buildInitialProcessingSnapshot() {
  return const ProcessingSnapshot(
    progress: 0,
    statusLabel: '处理中',
    etaLabel: '正在连接处理事件流并初始化第一阶段。',
    steps: [
      ProcessingStep(
        label: '素材预处理',
        detail: '正在准备视频文件、音轨和关键帧处理任务。',
        progress: 0,
      ),
      ProcessingStep(
        label: '分片并行分析',
        detail: '等待工作流启动后下发分片任务。',
        progress: 0,
      ),
      ProcessingStep(
        label: '融合输出与待审稿',
        detail: '等待首批分片结果回流后进入融合。',
        progress: 0,
      ),
    ],
  );
}

/// 把稳定的 processing 数据翻译成当前 UI 需要的展示结构和文案。
ProcessingSnapshot mapProcessingDataToSnapshot(VideoSummaryProcessingData data) {
  return ProcessingSnapshot(
    progress: data.progress,
    statusLabel: _statusLabelForProcessing(data),
    etaLabel: _etaLabelForProcessing(data),
    steps: data.steps.map((step) => mapProcessingStepToUiStep(step, data)).toList(),
  );
}

String _statusLabelForProcessing(VideoSummaryProcessingData data) {
  if (data.currentStage == VideoSummaryProcessingStage.waitingHumanReview) {
    return '待进入初稿';
  }

  return data.progress >= 1 ? '处理完成' : '处理中';
}

String _etaLabelForProcessing(VideoSummaryProcessingData data) {
  final chunkProgress = data.chunkProgress;
  if (chunkProgress == null) {
    return data.currentMessage;
  }

  final progressLine =
      '音频 ${chunkProgress.audioDone}/${chunkProgress.totalChunks} · '
      '视觉 ${chunkProgress.visionDone}/${chunkProgress.totalChunks} · '
      '融合 ${chunkProgress.synthesisDone}/${chunkProgress.totalChunks}';

  return '${data.currentMessage} 当前分片进度：$progressLine。';
}

ProcessingStep mapProcessingStepToUiStep(
  VideoSummaryProcessingStepData step,
  VideoSummaryProcessingData data,
) {
  return switch (step.phase) {
    VideoSummaryProcessingPhase.preprocessing => ProcessingStep(
      label: '素材预处理',
      detail: _preprocessingDetail(step, data),
      progress: step.progress,
    ),
    VideoSummaryProcessingPhase.analysis => ProcessingStep(
      label: '分片并行分析',
      detail: _analysisDetail(step, data),
      progress: step.progress,
    ),
    VideoSummaryProcessingPhase.synthesis => ProcessingStep(
      label: '融合输出与待审稿',
      detail: _synthesisDetail(step, data),
      progress: step.progress,
    ),
  };
}

String _preprocessingDetail(
  VideoSummaryProcessingStepData step,
  VideoSummaryProcessingData data,
) {
  if (step.progress >= 100) {
    return '${step.completedUnits}/${step.totalUnits} 项素材准备已完成，转录文本和关键帧已就绪。';
  }

  return switch (data.currentStage) {
    VideoSummaryProcessingStage.acquiringVideo => '正在获取并保存视频文件，准备进入本地预处理。',
    VideoSummaryProcessingStage.extractingAudio => '正在从视频流中分离音轨，检查后续转录输入。',
    VideoSummaryProcessingStage.extractingFrames => '正在抽取关键帧，准备建立视觉证据索引。',
    VideoSummaryProcessingStage.transcribingAudio => '正在调用 Whisper 生成带时间戳的转录文本。',
    _ => data.currentMessage,
  };
}

String _analysisDetail(
  VideoSummaryProcessingStepData step,
  VideoSummaryProcessingData data,
) {
  final chunkProgress = data.chunkProgress;
  if (chunkProgress == null) {
    return data.currentMessage;
  }

  if (step.progress >= 100) {
    return '共 ${chunkProgress.totalChunks} 个分片的音频与视觉分析已完成并回传。';
  }

  return switch (data.currentStage) {
    VideoSummaryProcessingStage.bootingWorkflow => 'LangGraph 已启动，正在装配 thread、状态机和并发模式。',
    VideoSummaryProcessingStage.planningChunks => '正在以时间线锚点规划分片，准备建立并发任务。',
    VideoSummaryProcessingStage.dispatchingChunks => '正在下发分片任务，等待音频与视觉 worker 回传。',
    VideoSummaryProcessingStage.analyzingAudioChunks => '音频分片已完成 ${chunkProgress.audioDone}/${chunkProgress.totalChunks}，视觉分支继续并行。',
    VideoSummaryProcessingStage.analyzingVisionChunks => '视觉分片已完成 ${chunkProgress.visionDone}/${chunkProgress.totalChunks}，正在与音频证据对齐。',
    _ => data.currentMessage,
  };
}

String _synthesisDetail(
  VideoSummaryProcessingStepData step,
  VideoSummaryProcessingData data,
) {
  final chunkProgress = data.chunkProgress;
  if (data.currentStage == VideoSummaryProcessingStage.waitingHumanReview) {
    return '聚合稿已整理完成，准备进入待审阅初稿阶段。';
  }

  if (step.progress >= 100) {
    return '分片融合、聚合和待审稿封装已完成。';
  }

  if (chunkProgress == null) {
    return data.currentMessage;
  }

  return switch (data.currentStage) {
    VideoSummaryProcessingStage.synthesizingChunks => '融合分片已完成 ${chunkProgress.synthesisDone}/${chunkProgress.totalChunks}，正在写入中间摘要。',
    VideoSummaryProcessingStage.aggregatingChunks => '全部分片已回流，正在按时间线整合为统一证据底稿。',
    _ => data.currentMessage,
  };
}

/// draft 数据本身只包含段落，页面展示需要的交互提示在 widget 层处理。
DraftResult mapDraftDataToResult(VideoSummaryDraftData data) {
  return DraftResult(
    paragraphs: data.paragraphs,
    suggestionHint: '例如：请先给我按行业、声线和行动建议展开，重点扩充已结构化结论。',
  );
}

/// 最终稿需要额外组合标题、时间片段标签和 chip 数据，这些都属于展示层。
FinalSummaryData mapFinalResultDataToSummary(VideoSummaryFinalResultData data) {
  return FinalSummaryData(
    summaryTitle: '最终稿',
    summaryBody: data.body,
    timestampChips: data.references
        .map(
          (reference) => TimestampChipData(
            label: formatVideoSummaryTimestampRange(
              reference.startSeconds,
              reference.endSeconds,
            ),
            note: reference.topic,
          ),
        )
        .toList(),
    messages: const [],
  );
}

/// 追问回复会被翻译成统一的聊天消息结构，便于页面复用同一套渲染逻辑。
ChatMessage mapChatReplyDataToMessage(VideoSummaryChatReplyData data) {
  return ChatMessage(
    sender: SummaryChatSender.system,
    text: data.text,
    timestampLabel: data.reference == null
        ? null
        : formatVideoSummaryTimestampRange(
            data.reference!.startSeconds,
            data.reference!.endSeconds,
          ),
  );
}