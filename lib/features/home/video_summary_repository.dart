import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/service_providers.dart';
import '../../services/websocket/ws_provider.dart';
import '../auth/auth_controller.dart';
import 'domain/video_summary_domain_models.dart';
import 'http_video_summary_repository.dart';
import 'video_summary_models.dart';

/// 默认视频 ID（后续由上传/选择视频时动态设置）。
const String defaultVideoId = 'vid_default';

/// 当前视频 ID，独立于 repository provider，避免 defaultKbidProvider 解析时
/// repository 重建导致 videoId 被重置为 [defaultVideoId]。
final currentVideoIdProvider = StateProvider<String>((ref) => defaultVideoId);

/// 获取当前用户的默认知识库 ID（不存在则自动创建）。
final defaultKbidProvider = FutureProvider<String>((ref) async {
  // 监听 authControllerProvider 的变化。当 authState 变化时，这个 FutureProvider 会自动重新计算并重新获取数据
  ref.watch(authControllerProvider);

  final kbService = ref.watch(knowledgeBaseServiceProvider);
  final resp = await kbService.listKBs();
  final kbs = resp.data;
  if (kbs.isNotEmpty) {
    return kbs.first.kbid;
  }
  // 没有知识库则自动创建默认知识库
  final createResp = await kbService.createKB(name: '默认知识库');
  if (createResp.data == null) {
    throw Exception('Failed to create default knowledge base');
  }
  return createResp.data!.kbid;
});

final videoSummaryRepositoryProvider = Provider<VideoSummaryRepository>((ref) {
  // 保持 wsEventProvider 处于活动状态（自动处理连接/断开生命周期）
  ref.listen(wsEventProvider, (prev, next) {});

  // 监听异步 kbid，加载期间使用占位值，完成后 Provider 会自动重建
  final kbidAsync = ref.watch(defaultKbidProvider);
  final kbid = kbidAsync.valueOrNull ?? '';

  // 从独立 provider 读取 videoId，不受 repository 重建影响
  final videoId = ref.watch(currentVideoIdProvider);

  return HttpVideoSummaryRepository(
    taskService: ref.watch(taskServiceProvider),
    videoQAService: ref.watch(videoQAServiceProvider),
    wsClient: ref.watch(wsClientProvider),
    kbid: kbid,
    videoId: videoId,
  );
});

/// repository 只暴露稳定数据 contract，不直接返回 UI 展示模型。
///
/// 未来真实接口接入时，推荐继续保留这个 contract，内部改为事件流驱动：
/// SSE / WebSocket / 轮询事件源 -> repository 适配器 -> raw data -> mapper -> UI。
abstract class VideoSummaryRepository {
  const VideoSummaryRepository();

  VideoAssetInfo getVideoAsset();

  /// 获取当前用户的历史任务列表，用于左侧边栏展示。
  Future<List<VideoSummaryTaskInfo>> listTaskHistory({
    int page = 1,
    int pageSize = 50,
  });

  Stream<VideoSummaryProcessingData> startDraftGeneration({
    String? userInitialPreference,
  });

  Future<VideoSummaryDraftData> fetchDraftResult();

  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  });

  Stream<VideoSummaryChatReplyData> sendSummaryChatMessage(
    String message, {
    required String timestamp,
    int? windowSeconds,
  });

  /// 查询单个任务的状态，用于会话恢复时判断后台任务是否已完成。
  Future<VideoSummaryTaskInfo?> getTaskStatus(String taskId);

  /// 恢复对已有任务的 WebSocket 进度监听（不创建新任务）。
  /// 用于 Phase 1 切回时重新接收实时 WS 进度推送。
  Stream<VideoSummaryProcessingData> resumeTaskProgress(String taskId);

  /// 恢复对已有任务的终稿生成监听（不重新调用 approveAndFinalize）。
  /// 用于 Phase 2 切回时重新等待 WS completed 事件。
  Future<VideoSummaryFinalResultData> resumeFinalGeneration(String taskId);

  void updateVideoId(String newId);
  void updateKbid(String newId);
  void updateTaskId(String? newId);

  /// 当前知识库 ID。
  String get kbid;

  /// 当前视频 ID。
  String get videoId;

  /// 当前任务 ID。
  String? get activeTaskId;
}
