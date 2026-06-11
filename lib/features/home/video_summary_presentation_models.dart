/// 这些模型专门服务 UI 展示，通常由 application 层 mapper 产出。
enum SummaryChatSender { system, user }

/// 聊天消息中的图片附件（轻量 UI 模型）。
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.ossKey,
    required this.mimeType,
    this.presignedUrl,
  });

  final String name;
  final String ossKey;
  final String mimeType;

  /// HTTP 可访问的图片地址，用于 Image.network。
  final String? presignedUrl;
}

/// 单轨分片进度条数据。
class ChunkProgressBar {
  const ChunkProgressBar({
    required this.label,
    required this.icon,
    required this.done,
    required this.total,
    required this.percent,
  });

  final String label;
  final String icon;
  final int done;
  final int total;
  final int percent;
}

/// 单轨分片进度快照。
class ChunkProgressSnapshot {
  const ChunkProgressSnapshot({
    required this.chunkBar,
    required this.statusLog,
  });

  final ChunkProgressBar chunkBar;
  final List<String> statusLog;
}

class ProcessingSnapshot {
  const ProcessingSnapshot({
    required this.progress,
    required this.statusLabel,
    required this.etaLabel,
    this.chunkProgress,
    this.statusLog = const [],
  });

  /// 整体进度 0.0–1.0，驱动 HeroCard 总体进度条。
  final double progress;

  /// 状态标签，显示在 HeroCard 的 pill 中。
  final String statusLabel;

  /// 副标题/eta 行，显示在 HeroCard 标题下方。
  final String etaLabel;

  /// 对标 Streamlit 的 4 轨并行分片进度（新 UI 主数据源）。
  final ChunkProgressSnapshot? chunkProgress;

  /// 最近 N 条后端状态消息，用于分片面板底部的滚动日志。
  final List<String> statusLog;
}

class DraftResult {
  const DraftResult({
    required this.paragraphs,
    required this.suggestionHint,
  });

  final List<String> paragraphs;
  final String suggestionHint;
}

class TimestampChipData {
  const TimestampChipData({required this.label, required this.note});

  final String label;
  final String note;
}

class ChatMessageCitation {
  const ChatMessageCitation({
    required this.quote,
    this.videoId,
    this.timeRange,
  });

  final String quote;
  final String? videoId;
  final String? timeRange;
}

class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    this.timestampLabel,
    this.citations,
    this.attachments = const [],
  });

  final SummaryChatSender sender;
  final String text;
  final String? timestampLabel;
  final List<ChatMessageCitation>? citations;

  /// 用户消息附带的图片列表。
  final List<ChatAttachment> attachments;
}

class FinalSummaryData {
  const FinalSummaryData({
    required this.summaryTitle,
    required this.summaryBody,
    required this.timestampChips,
    required this.messages,
  });

  final String summaryTitle;
  final String summaryBody;
  final List<TimestampChipData> timestampChips;
  final List<ChatMessage> messages;
}