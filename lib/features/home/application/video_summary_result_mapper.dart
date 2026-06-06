import '../domain/video_summary_domain_models.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_presentation_models.dart';


ProcessingSnapshot buildInitialProcessingSnapshot() {
  return ProcessingSnapshot(
    progress: 0,
    statusLabel: '处理中',
    etaLabel: '正在连接处理事件流并初始化第一阶段。',
    // 立即显示 3 轨进度条（全零初始态），不等后端第一条 [[PROGRESS]]
    chunkProgress: const ChunkProgressSnapshot(
      chunkBar: ChunkProgressBar(
        label: '分片分析',
        icon: '📦',
        done: 0,
        total: 5,
        percent: 0,
      ),
      statusLog: [],
    ),
    statusLog: [],
  );
}

/// 把稳定的 processing 数据翻译成当前 UI 需要的展示结构和文案。
ProcessingSnapshot mapProcessingDataToSnapshot(VideoSummaryProcessingData data) {
  final chunkData = data.chunkProgress;

  return ProcessingSnapshot(
    progress: data.progress,
    statusLabel: data.progress >= 1 ? '处理完成' : '处理中',
    etaLabel: _buildEtaLabel(data),
    chunkProgress: chunkData != null
        ? ChunkProgressSnapshot(
            chunkBar: ChunkProgressBar(
              label: '分片分析',
              icon: '📦',
              done: chunkData.doneCount,
              total: chunkData.totalChunks,
              percent: chunkData.overallPercent,
            ),
            statusLog: data.statusLog,
          )
        : null,
    statusLog: data.statusLog,
  );
}

/// 对标 Streamlit 的 eta 标签：简短显示各轨完成数。
String _buildEtaLabel(VideoSummaryProcessingData data) {
  final cp = data.chunkProgress;
  if (cp == null) {
    return data.currentMessage.isNotEmpty
        ? data.currentMessage
        : '正在准备处理内容。';
  }

  return '分片 ${cp.doneCount}/${cp.totalChunks} 完成';
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
    summaryTitle: '视频总结',
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
