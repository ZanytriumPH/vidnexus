/// 这些模型专门服务 UI 展示，通常由 application 层 mapper 产出。
enum SummaryChatSender { system, user }

class ProcessingBadge {
  const ProcessingBadge({required this.label, required this.active});

  final String label;
  final bool active;
}

class ProcessingStep {
  const ProcessingStep({
    required this.label,
    required this.detail,
    required this.progress,
  });

  final String label;
  final String detail;
  final int progress;
}

class ProcessingSnapshot {
  const ProcessingSnapshot({
    required this.progress,
    required this.statusLabel,
    required this.headline,
    required this.etaLabel,
    required this.badges,
    required this.steps,
  });

  final double progress;
  final String statusLabel;
  final String headline;
  final String etaLabel;
  final List<ProcessingBadge> badges;
  final List<ProcessingStep> steps;
}

class DraftResult {
  const DraftResult({
    required this.overview,
    required this.paragraphs,
    required this.suggestionHint,
  });

  final String overview;
  final List<String> paragraphs;
  final String suggestionHint;
}

class TimestampChipData {
  const TimestampChipData({required this.label, required this.note});

  final String label;
  final String note;
}

class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    this.timestampLabel,
  });

  final SummaryChatSender sender;
  final String text;
  final String? timestampLabel;
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