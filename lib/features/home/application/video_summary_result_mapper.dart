import '../domain/video_summary_domain_models.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_presentation_models.dart';

ProcessingSnapshot mapProcessingDataToSnapshot(VideoSummaryProcessingData data) {
  return ProcessingSnapshot(
    progress: data.progress,
    statusLabel: data.progress >= 1 ? '处理完成' : '处理中',
    headline: '正在生成结构化初稿',
    etaLabel: data.progress >= 1
        ? '全部处理步骤已完成，准备进入草稿整理。'
        : '当前主步骤：融合语音、关键词和版面信息，准备输出第一版结构梳理。',
    badges: data.steps.map(mapProcessingStepToBadge).toList(),
    steps: data.steps.map(mapProcessingStepToUiStep).toList(),
  );
}

ProcessingBadge mapProcessingStepToBadge(VideoSummaryProcessingStepData step) {
  final phaseLabel = switch (step.phase) {
    VideoSummaryProcessingPhase.transcription => '语音转写',
    VideoSummaryProcessingPhase.alignment => '多轮融合',
    VideoSummaryProcessingPhase.summary => '总结卡片可视化',
  };

  final suffix = step.progress >= 100
      ? '已完成'
      : step.progress > 0
      ? '进行中'
      : '处理中';

  return ProcessingBadge(
    label: '$phaseLabel $suffix',
    active: step.progress > 0 && step.progress < 100,
  );
}

ProcessingStep mapProcessingStepToUiStep(VideoSummaryProcessingStepData step) {
  return switch (step.phase) {
    VideoSummaryProcessingPhase.transcription => ProcessingStep(
      label: '语音转写与切片',
      detail: step.progress >= 100
          ? '${step.completedUnits} 秒文本已完成校准。'
          : '正在抽取片段并比对字幕断点。',
      progress: step.progress,
    ),
    VideoSummaryProcessingPhase.alignment => ProcessingStep(
      label: '关键词归因与对齐',
      detail: step.progress >= 100
          ? '${step.totalUnits} 处关键点已归入片段，质检线已完成。'
          : '${step.totalUnits} 处关键点正在归入片段，质检线继续进行中。',
      progress: step.progress,
    ),
    VideoSummaryProcessingPhase.summary => ProcessingStep(
      label: '章节整合与摘要初稿',
      detail: step.progress >= 100
          ? '章节总括与首版摘要已整理完毕。'
          : '正在组织段间跳转语句与第一版总括。',
      progress: step.progress,
    ),
  };
}

DraftResult mapDraftDataToResult(VideoSummaryDraftData data) {
  return DraftResult(
    overview: '初稿已生成，处理详情已自动折叠',
    paragraphs: data.paragraphs,
    suggestionHint: '例如：请先给我按行业、声线和行动建议展开，重点扩充已结构化结论。',
  );
}

FinalSummaryData mapFinalResultDataToSummary(VideoSummaryFinalResultData data) {
  final primaryReference = data.references.firstOrNull;
  return FinalSummaryData(
    summaryTitle: '最终稿',
    summaryBody: data.body,
    summaryTimestampLabel: primaryReference == null
        ? '暂无时间片段'
        : '汇总片段 ${formatVideoSummaryTimestampRange(primaryReference.startSeconds, primaryReference.endSeconds)}',
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