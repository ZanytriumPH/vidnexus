import '../../features/knowledge_base/knowledge_base_models.dart';
import '../../features/home/widgets/video_summary_drawer_shared.dart';

class VideoSummarySearchRouteArguments {
  const VideoSummarySearchRouteArguments({required this.sessions});

  final List<VideoSummaryDrawerSessionItem> sessions;
}

class KnowledgeBaseSessionRouteArguments {
  const KnowledgeBaseSessionRouteArguments({required this.kbid});

  final String kbid;
}

class KnowledgeBaseChatRouteArguments {
  const KnowledgeBaseChatRouteArguments({
    required this.kbid,
    required this.initialConversation,
  });

  final String kbid;
  final KnowledgeConversationPreview initialConversation;
}

class KnowledgeBaseSourcesRouteArguments {
  const KnowledgeBaseSourcesRouteArguments({required this.kbid});

  final String kbid;
}