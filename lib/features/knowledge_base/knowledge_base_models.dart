import '../../services/models/global_chat_dto.dart';

enum KnowledgeChatSender { user, system }

class KnowledgeChatMessage {
  const KnowledgeChatMessage({
    required this.sender,
    required this.text,
    this.timestampLabel,
    this.citedSources,
  });

  final KnowledgeChatSender sender;
  final String text;
  final String? timestampLabel;
  final List<CitedSource>? citedSources;
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
