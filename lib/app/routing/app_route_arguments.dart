import '../../features/knowledge_base/knowledge_base_models.dart';

class KnowledgeBaseSessionRouteArguments {
  const KnowledgeBaseSessionRouteArguments({required this.library});

  final KnowledgeBaseLibrary library;
}

class KnowledgeBaseChatRouteArguments {
  const KnowledgeBaseChatRouteArguments({
    required this.library,
    required this.initialConversation,
  });

  final KnowledgeBaseLibrary library;
  final KnowledgeConversationPreview initialConversation;
}

class KnowledgeBaseSourcesRouteArguments {
  const KnowledgeBaseSourcesRouteArguments({required this.library});

  final KnowledgeBaseLibrary library;
}