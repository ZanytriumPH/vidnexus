import '../home/video_summary_presentation_models.dart' show ChatAttachment;
import '../../services/models/global_chat_dto.dart';

enum KnowledgeChatSender { user, system }

/// ReAct agent 进度步骤，由 SSE progress 事件解析而来。
class KnowledgeProgressStep {
  const KnowledgeProgressStep({
    required this.phase,
    required this.message,
    required this.timestamp,
  });

  /// Agent 当前阶段：thinking | searching | retrieved | loading | generating
  final String phase;

  /// 前端展示的可读文案
  final String message;

  /// 本地记录的时间戳（用于计算步骤间相对耗时）
  final DateTime timestamp;
}

class KnowledgeChatMessage {
  const KnowledgeChatMessage({
    required this.sender,
    required this.text,
    this.timestampLabel,
    this.citedSources,
    this.progressSteps,
    this.attachments = const [],
  });

  final KnowledgeChatSender sender;
  final String text;
  final String? timestampLabel;
  final List<CitedSource>? citedSources;
  final List<KnowledgeProgressStep>? progressSteps;

  /// 用户消息附带的图片列表。
  final List<ChatAttachment> attachments;
}

class KnowledgeConversationPreview {
  const KnowledgeConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.dateLabel,
    required this.messages,
  });

  final String id;
  final String title;
  final String preview;
  final String dateLabel;
  final List<KnowledgeChatMessage> messages;
}

class KnowledgeSourceItem {
  const KnowledgeSourceItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kindLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kindLabel;
}

class KnowledgeBaseLibrary {
  const KnowledgeBaseLibrary({
    required this.id,
    required this.title,
    required this.meta,
    required this.description,
    required this.sourceCount,
    required this.sources,
    required this.conversations,
    this.latestQuestion,
  });

  final String id;
  final String title;
  final String meta;
  final String description;
  final int sourceCount;
  final List<KnowledgeSourceItem> sources;
  final List<KnowledgeConversationPreview> conversations;
  final String? latestQuestion;
}
