import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/routing/app_route_arguments.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../services/api/api_client.dart';
import '../../services/video_service.dart';
import '../auth/auth_controller.dart';
import 'application/video_summary_flow_controller.dart';
import 'application/video_summary_session_history_controller.dart';
import 'application/video_summary_settings_controller.dart';
import 'application/video_summary_text_editing_controller.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';
import 'widgets/home_shell_widgets.dart';
import 'widgets/session_settings_sheet.dart';
import 'widgets/video_summary_content_widgets.dart';
import 'widgets/video_summary_drawer_shared.dart';
import 'widgets/video_summary_drawer_widgets.dart';
import 'widgets/video_summary_final_chat_widgets.dart';
import 'widgets/video_player_page.dart';

/// 首页现在主要承担页面壳和装配职责，复杂状态迁移已下沉到 application 层。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(videoSummaryFlowControllerProvider);
    final sessionHistory = ref.watch(videoSummarySessionHistoryProvider);
    final textEditing = ref.watch(videoSummaryTextEditingControllerProvider);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final useBoundedStageLayout =
        flowState.stage == VideoSummaryStage.ready ||
        flowState.stage == VideoSummaryStage.finalChat;

    // 监听认证状态变化：当用户登出时，立即使会话历史与流程控制器失效，
    // 确保下一个账号登录后不会看到上一个账号的残留缓存数据。
    ref.listen(authControllerProvider, (prev, next) {
      if (prev?.isLoggedIn == true && !next.isLoggedIn) {
        ref.invalidate(videoSummarySessionHistoryProvider);
        ref.invalidate(videoSummaryFlowControllerProvider);
      }
    });

    ref.listen(videoSummaryFlowControllerProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(videoSummaryFlowControllerProvider.notifier).clearError();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final scaffold = _scaffoldKey.currentState;
        if (scaffold != null && scaffold.isDrawerOpen) {
          SystemNavigator.pop();
        } else {
          scaffold?.openDrawer();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: true,
      drawer: VideoSummaryHistoryDrawer(
        sessions: sessionHistory.sessions
            .where(
              (session) =>
                  // "session-current" 是控制器 build() 创建的占位条目，
                  // 仅用于内部状态管理，永远不在侧边栏中显示。
                  session.id != 'session-current',
            )
            .map(
              (session) => VideoSummaryDrawerSessionItem(
                id: session.id,
                title: session.title,
                durationLabel: session.durationLabel,
                detail: session.detail,
                isActive: !_isCurrentSessionEmpty(flowState) &&
                    session.id == sessionHistory.activeSessionId,
              ),
            )
            .toList(),
        isLoadingHistory: sessionHistory.isLoadingHistory,
        errorMessage: sessionHistory.errorMessage,
        onRetryHistory: () {
          ref
              .read(videoSummarySessionHistoryProvider.notifier)
              .retryLoadHistory();
        },
        onNewSessionPressed: _createNewSessionFromDrawer,
        onSessionSelected: _restoreSessionFromDrawer,
        onSettingsPressed: _openSettingsFromDrawer,
        onSearchPressed: _openSearchFromDrawer,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, keyboardVisible ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeaderRow(
                  currentSection: AppNavSection.videoSummary,
                  onSectionSelected: (section) =>
                      _handleSectionSelection(context, section),
                  onMenuPressed: _openDrawer,
                  onNewSessionPressed: _createNewSession,
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: useBoundedStageLayout
                      ? _buildWorkspace(flowState, textEditing)
                      : SingleChildScrollView(
                          child: _buildWorkspace(flowState, textEditing),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _handleSectionSelection(BuildContext context, AppNavSection section) {
    switch (section) {
      case AppNavSection.videoSummary:
        return;
      case AppNavSection.knowledgeBase:
        AppNavigator.goToKnowledgeBaseHome(context);
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) > 350 &&
        !(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      _openDrawer();
    }
  }

  /// 当前会话是否为空（无任务、无上传、处于 ready 阶段）。
  /// 用于侧边栏过滤：空会话不在历史列表中显示。
  bool _isCurrentSessionEmpty(VideoSummaryFlowState flowState) {
    return flowState.taskId == null &&
        flowState.stage == VideoSummaryStage.ready &&
        !flowState.uploadHighlighted;
  }

  // 新建会话：重置流程状态和文本状态。
  // 空会话已在 _isCurrentSessionEmpty 中判断，避免重复重置。
  // 若当前会话已完成视频上传，先将其持久化到历史列表再重置。
  void _createNewSession() {
    final flowState = ref.read(videoSummaryFlowControllerProvider);
    final isAlreadyEmpty = _isCurrentSessionEmpty(flowState);
    if (isAlreadyEmpty) return;

    final flowController = ref.read(
      videoSummaryFlowControllerProvider.notifier,
    );
    final sessionHistoryController = ref.read(
      videoSummarySessionHistoryProvider.notifier,
    );
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    textEditing.runWithoutSync(() {
      // 仅需持久化"仅有视频上传、尚未创建后端任务"的会话。
      // 已有后端任务的会话由 listTaskHistory 提供侧边栏历史记录，
      // 无需额外创建冗余的本地条目。
      if (flowState.uploadHighlighted && flowState.taskId == null) {
        sessionHistoryController.persistUploadSession(
          textEditing.captureSnapshot(),
        );
      }
      textEditing.clearForNewSession();
      flowController.reset();
    });
  }

  void _createNewSessionFromDrawer() {
    AppNavigator.popCurrent(context);
    _createNewSession();
  }

  Future<void> _openSearchFromDrawer() async {
    final sessionHistory = ref.read(videoSummarySessionHistoryProvider);
    final sessions = sessionHistory.sessions
        .where((session) => session.id != 'session-current')
        .map(
          (session) => VideoSummaryDrawerSessionItem(
            id: session.id,
            title: session.title,
            durationLabel: session.durationLabel,
            detail: session.detail,
            isActive: session.id == sessionHistory.activeSessionId,
          ),
        )
        .toList();

    final shouldRestoreDrawer = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    if (shouldRestoreDrawer) {
      AppNavigator.popCurrent(context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final selectedSessionId = await AppNavigator.openVideoSummarySearch(
      context,
      arguments: VideoSummarySearchRouteArguments(sessions: sessions),
    );

    if (!mounted) return;

    if (selectedSessionId != null) {
      _restoreSessionFromDrawer(selectedSessionId);
      return;
    }

    if (shouldRestoreDrawer) {
      _openDrawer();
    }
  }

  void _restoreSessionFromDrawer(String sessionId) {
    final session = ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .getSessionById(sessionId);
    if (session == null) {
      return;
    }

    // 从抽屉直接选会话时需要先关闭抽屉；从搜索页回调过来时抽屉已关闭，但 pop 一个已关闭的 navigator 是安全的
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      AppNavigator.popCurrent(context);
    }
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    textEditing.runWithoutSync(() {
      // 恢复顺序很重要：先回填文本，再恢复流程快照，最后切 active session。
      textEditing.applySessionSnapshot(session.snapshot);
      ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .restoreSnapshot(session.snapshot.flowSnapshot);
      ref
          .read(videoSummarySessionHistoryProvider.notifier)
          .activateSession(session.id);
    });
  }

  Future<void> _openSettingsFromDrawer() async {
    final settingsState = ref.read(videoSummarySettingsProvider);
    final settingsController = ref.read(videoSummarySettingsProvider.notifier);
    AppNavigator.popCurrent(context);
    await showSessionSettingsSheet(
      context: context,
      defaultTimestampScoped: settingsState.defaultTimestampScoped,
      defaultProcessingExpanded: settingsState.defaultProcessingExpanded,
      onDefaultTimestampScopedChanged:
          settingsController.setDefaultTimestampScoped,
      onDefaultProcessingExpandedChanged:
          settingsController.setDefaultProcessingExpanded,
    );
  }

  Future<void> _generateFinalSummary() {
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    return ref
        .read(videoSummaryFlowControllerProvider.notifier)
        .generateFinalSummary(
          guidance: textEditing.draftGuidanceText.trim(),
          draftBodyText: textEditing.draftBodyText,
        );
  }

  Future<void> _sendChatMessage() async {
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    final message = textEditing.consumeChatMessage();
    if (message == null) {
      return;
    }

    await ref
        .read(videoSummaryFlowControllerProvider.notifier)
        .sendChatMessage(message);
  }

  Future<void> _openVideoPlayback() async {
    final flowState = ref.read(videoSummaryFlowControllerProvider);
    final videoId = flowState.videoAsset.title;
    if (videoId.isEmpty || videoId == 'vid_default') return;

    // 显示加载中
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final videoService = const VideoService();
      final resp = await videoService.getVideo(videoId);
      final data = resp.data;
      var videoUrl = data?.presignedUrl ?? '';
      final ossKey = data?.ossKey;

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭 loading

      // 本地开发模式 presigned_url 是 file:// 路径，转换为 HTTP 流式端点
      if (videoUrl.startsWith('file://') && ossKey != null && ossKey.isNotEmpty) {
        final baseUrl = ApiClient.instance.options.baseUrl;
        videoUrl = '$baseUrl/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
      }

      if (videoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频地址暂不可用，请稍后重试')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(
            videoUrl: videoUrl,
            title: flowState.videoAsset.fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭 loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取视频播放地址失败: $e')),
      );
    }
  }

  VideoSummaryWorkspace _buildWorkspace(
    VideoSummaryFlowState flowState,
    VideoSummaryTextEditingController textEditing,
  ) {
    // 这里统一把 controller 状态和回调接到各 stage workspace，避免子组件直接读多个 provider。
    return VideoSummaryWorkspace(
      stage: flowState.stage,
      highlighted: flowState.uploadHighlighted,
      videoAsset: flowState.videoAsset,
      processingSnapshot: flowState.processingSnapshot,
      draftResult: flowState.draftResult,
      finalSummaryData: flowState.finalSummaryData,
      chatMessages: flowState.chatMessages,
      readyPreferenceController: textEditing.readyPreferenceController,
      draftGuidanceController: textEditing.draftGuidanceController,
      chatController: textEditing.chatController,
      draftBodyController: textEditing.draftBodyController,
      processingExpanded: flowState.processingExpanded,
      isDraftEditMode: flowState.isDraftEditMode,
      isGenerating: flowState.isGenerating,
      isSendingChat: flowState.isSendingChat,
      isTimestampScoped: flowState.isTimestampScoped,
      selectedTimestampLabel: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .selectedTimestampLabel,
      totalDurationSeconds: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .videoDurationInSeconds,
      selectedTimestampStartSeconds: flowState.selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: flowState.selectedTimestampEndSeconds,
      onUploadCardPressed: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .pickAndUploadVideo,
      onProcessingCardPressed: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .toggleProcessingExpanded,
      onDraftEditModeChanged: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .setDraftEditMode,
      onStartPressed: flowState.isGenerating
          ? null
          : () {
              final preference = ref
                  .read(videoSummaryTextEditingControllerProvider)
                  .readyPreferenceText;
              ref
                  .read(videoSummaryFlowControllerProvider.notifier)
                  .startDraftGeneration(
                    userInitialPreference:
                        preference.isNotEmpty ? preference : null,
                  );
            },
      onGenerateFinalPressed: flowState.isGenerating
          ? null
          : _generateFinalSummary,
      onSendChatPressed: flowState.isSendingChat ? null : _sendChatMessage,
      onTimestampScopeChanged: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .setTimestampScope,
      onTimestampRangeChanged: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .setTimestampRange,
      isUploading: flowState.isUploading,
      uploadProgress: flowState.uploadProgress,
      onVideoPlayback: _openVideoPlayback,
      onRefreshPressed: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .refreshProcessingStatus,
      onAddToKbPressed: () {
        final repo = ref.read(videoSummaryRepositoryProvider);
        final videoId = repo.videoId;
        if (videoId.isEmpty || videoId == 'vid_default') return;
        showAddToKnowledgeBaseSheet(
          context: context,
          ref: ref,
          videoId: videoId,
        );
      },
    );
  }
}
