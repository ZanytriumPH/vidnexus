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

class VideoDetailRouteArguments {
  const VideoDetailRouteArguments({required this.videoId});

  final String videoId;
}

class HomeRouteArguments {
  const HomeRouteArguments({this.videoId, this.taskId});

  /// 可选：从知识库来源页跳转时携带的视频 ID，
  /// 首页会自动查找对应任务并恢复该视频的最终稿会话。
  final String? videoId;

  /// 可选：从知识库 cited_resources 点击时携带的任务 ID，
  /// 首页会直接按 taskId 获取任务详情并恢复，无需 listTasks 全量匹配。
  final String? taskId;
}