import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/routing/app_route_arguments.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../services/api/api_client.dart';
import '../../services/service_providers.dart';
import '../../services/video_service.dart';
import '../auth/auth_controller.dart';
import 'application/video_summary_flow_controller.dart';
import 'application/video_summary_result_mapper.dart';
import 'application/video_summary_session_history_controller.dart';
import 'application/video_summary_settings_controller.dart';
import 'application/video_summary_text_editing_controller.dart';
import 'video_summary_models.dart';
import 'video_summary_presentation_models.dart';
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
  const HomeScreen({super.key, this.videoId, this.taskId});

  /// 可选：从知识库来源页跳转时携带的视频 ID，
  /// 首页会自动查找对应任务并恢复该视频的最终稿会话。
  final String? videoId;

  /// 可选：从知识库 cited_resources 点击时携带的任务 ID，
  /// 首页会直接按 taskId 获取任务详情并恢复，无需 listTasks 全量匹配。
  final String? taskId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final taskId = widget.taskId;
    final videoId = widget.videoId;
    debugPrint('[HomeScreen] initState — taskId=$taskId, videoId=$videoId');
    if (taskId != null && taskId.isNotEmpty) {
      Future.microtask(() => _restoreVideoSession(taskId, isTaskId: true));
    } else if (videoId != null && videoId.isNotEmpty) {
      Future.microtask(() => _restoreVideoSession(videoId));
    }
  }

  Future<void> _restoreVideoSession(String id, {bool isTaskId = false}) async {
    debugPrint(
      '[HomeScreen] _restoreVideoSession — id=$id, isTaskId=$isTaskId',
    );
    final taskService = ref.read(taskServiceProvider);
    try {
      late final String taskId;
      late final String videoId;
      late final String workflowState;
      late final String kbid;
      late final String? kbName;
      late final String? draftSummary;
      late final String? finalSummary;
      late final String? title;
      late final String? userInitialPreference;

      if (isTaskId) {
        // 优先路径：通过 taskId 直接获取任务详情（来自 cited_resources 点击）
        debugPrint('[HomeScreen] getTask API starting — taskId=$id');
        final resp = await taskService.getTask(id);
        final dto = resp.data;
        if (dto == null) {
          debugPrint(
            '[HomeScreen] getTask returned null data — taskId=$id, aborting',
          );
          return;
        }
        debugPrint(
          '[HomeScreen] getTask success — workflowState=${dto.workflowState}, kbid=${dto.kbid}',
        );
        taskId = dto.taskId;
        videoId = dto.videoId;
        workflowState = dto.workflowState;
        kbid = dto.kbid;
        kbName = dto.kbName;
        draftSummary = dto.draftSummary;
        finalSummary = dto.finalSummary;
        title = dto.title;
        userInitialPreference = dto.userInitialPreference;
      } else {
        // 兼容旧路径：listTasks + 按 videoId 匹配
        final resp = await taskService.listTasks();
        final match = resp.data.where((t) => t.videoId == id).toList();
        if (match.isEmpty) {
          debugPrint(
            '[HomeScreen] listTasks matched no task for videoId=$id, aborting',
          );
          return;
        }

        final task = match.first;
        taskId = task.taskId;
        videoId = task.videoId;
        workflowState = task.workflowState;
        kbid = task.kbid;
        kbName = task.kbName;
        draftSummary = task.draftSummary;
        finalSummary = task.finalSummary;
        title = task.title;
        userInitialPreference = task.userInitialPreference;
      }

      final stage = switch (workflowState) {
        'COMPLETED' => VideoSummaryStage.finalChat,
        'WAITING_USER_APPROVAL' => VideoSummaryStage.draft,
        'DRAFT_GENERATING' ||
        'FINAL_GENERATING' => VideoSummaryStage.processing,
        _ => VideoSummaryStage.ready,
      };

      final draftParagraphs = draftSummary != null
          ? draftSummary!
                .split(RegExp(r'\n\s*\n'))
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList()
          : <String>[];

      final snapshot = VideoSummaryFlowSnapshot(
        taskId: taskId,
        videoAsset: VideoAssetInfo(
          title: videoId,
          durationLabel: '0m 00s',
          sourceLabel: kbid,
          fileName: title ?? videoId,
          kbName: kbName,
        ),
        kbid: kbid,
        stage: stage,
        uploadHighlighted: true,
        processingExpanded: stage == VideoSummaryStage.processing,
        isTimestampScoped: false,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds:
            VideoSummaryFlowController.minimumTimestampRangeSeconds,
        isDraftEditMode: false,
        processingSnapshot: stage == VideoSummaryStage.processing
            ? buildInitialProcessingSnapshot()
            : null,
        draftResult:
            (stage == VideoSummaryStage.draft ||
                stage == VideoSummaryStage.finalChat)
            ? DraftResult(paragraphs: draftParagraphs, suggestionHint: '')
            : null,
        finalSummaryData: stage == VideoSummaryStage.finalChat
            ? FinalSummaryData(
                summaryTitle: '视频总结',
                summaryBody: finalSummary ?? '',
                timestampChips: const [],
                messages: const [],
              )
            : null,
        chatMessages: const [],
        isUploading: false,
        uploadProgress: 0.0,
      );

      debugPrint(
        '[HomeScreen] restoreSnapshot — stage=$stage, taskId=$taskId, kbid=$kbid',
      );
      if (!mounted) return;
      final flowCtrl = ref.read(videoSummaryFlowControllerProvider.notifier);
      flowCtrl.restoreSnapshot(snapshot);
      debugPrint('[HomeScreen] restoreSnapshot completed');

      final historyCtrl = ref.read(videoSummarySessionHistoryProvider.notifier);
      historyCtrl.addTempUploadSession(
        VideoSummarySessionSnapshot(
          flowSnapshot: snapshot,
          readyPreferenceText: userInitialPreference ?? '',
          draftGuidanceText: '',
          draftBodyText: draftSummary ?? '',
        ),
      );
    } catch (e) {
      debugPrint('[HomeScreen] _restoreVideoSession failed: $e');
      // 查找失败则停留在首页默认状态
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(videoSummaryFlowControllerProvider);
    final sessionHistory = ref.watch(videoSummarySessionHistoryProvider);
    final textEditing = ref.watch(videoSummaryTextEditingControllerProvider);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final useBoundedStageLayout =
        flowState.stage == VideoSummaryStage.ready ||
        flowState.stage == VideoSummaryStage.finalChat;

    // 监听认证状态变化：当用户登出或新用户登入时，立即使会话历史
    // 与流程控制器失效，确保账号之间的缓存数据完全隔离。
    ref.listen(authControllerProvider, (prev, next) {
      final prevLoggedIn = prev?.isLoggedIn == true;
      final nextLoggedIn = next.isLoggedIn;
      final userChanged = prev?.currentUser?.userId != next.currentUser?.userId;

      if ((prevLoggedIn && !nextLoggedIn) || // 注销
          (!prevLoggedIn && nextLoggedIn) || // 登录
          (prevLoggedIn && nextLoggedIn && userChanged)) {
        // 切换账号
        ref.invalidate(videoSummarySessionHistoryProvider);
        ref.invalidate(videoSummaryFlowControllerProvider);
      }
    });

    ref.listen(videoSummaryFlowControllerProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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
                  isActive:
                      !_isCurrentSessionEmpty(flowState) &&
                      session.id == sessionHistory.activeSessionId,
                  kbName:
                      session.snapshot.flowSnapshot.videoAsset?.kbName,
                  kbid:
                      session.snapshot.flowSnapshot.videoAsset?.sourceLabel,
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
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                keyboardVisible ? 8 : 12,
              ),
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
        (flowState.videoAsset.title == 'vid_default' ||
            flowState.videoAsset.title.isEmpty);
  }

  /// 侧边栏条目标题：若已完成最终稿则提取 markdown # 标题，否则显示原始会话标题。
  String _drawerTitle(VideoSummarySessionHistoryEntry session) {
    final body = session.snapshot.flowSnapshot.finalSummaryData?.summaryBody;
    if (body != null && body.isNotEmpty) {
      final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
      if (match != null) {
        final title = match.group(1)?.trim();
        if (title != null && title.isNotEmpty) return title;
      }
    }
    return session.title;
  }

  /// 该会话是否已生成最终稿（可从 markdown 提取标题）。
  bool _hasFinalDraftTitle(VideoSummarySessionHistoryEntry session) {
    final body = session.snapshot.flowSnapshot.finalSummaryData?.summaryBody;
    if (body == null || body.isEmpty) return false;
    return RegExp(r'^#\s+.+$', multiLine: true).hasMatch(body);
  }

  // 新建会话：重置流程状态和文本状态。
  // 空会话已在 _isCurrentSessionEmpty 中判断，避免重复重置。
  // 若当前会话已完成视频上传但尚未创建后端任务，先将其保存为内存临时会话再重置。
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
      // 仅上传了视频、尚未创建后端任务的会话需要以临时会话保存到内存中，
      // 确保用户切换或新建会话后仍可从侧边栏恢复。已有后端任务的会话由
      // listTaskHistory 提供侧边栏历史记录，无需额外创建。
      if (flowState.videoAsset.title != 'vid_default' &&
          flowState.videoAsset.title.isNotEmpty &&
          flowState.taskId == null) {
        sessionHistoryController.addTempUploadSession(
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
          (session) {
            final hasFinal = _hasFinalDraftTitle(session);
            return VideoSummaryDrawerSessionItem(
            id: session.id,
            title: _drawerTitle(session),
            durationLabel: hasFinal ? '' : session.durationLabel,
            detail: session.detail,
            isActive: session.id == sessionHistory.activeSessionId,
            kbName: session.snapshot.flowSnapshot.videoAsset?.kbName,
            kbid: session.snapshot.flowSnapshot.videoAsset?.sourceLabel,
          ),
        )
        .toList();

    final shouldRestoreDrawer =
        _scaffoldKey.currentState?.isDrawerOpen ?? false;
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
      // 恢复顺序很重要：先切 active session，再恢复文本和流程快照。
      ref
          .read(videoSummarySessionHistoryProvider.notifier)
          .activateSession(session.id);
      textEditing.applySessionSnapshot(session.snapshot);
      ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .restoreSnapshot(session.snapshot.flowSnapshot);
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

  Future<void> _handleUploadCardPressed() async {
    debugPrint('[HomeScreen] _handleUploadCardPressed START');
    final videoId = await ref
        .read(videoSummaryFlowControllerProvider.notifier)
        .pickAndUploadVideo();
    debugPrint('[HomeScreen] _handleUploadCardPressed DONE — videoId=$videoId mounted=$mounted');
    if (videoId != null && mounted) {
      AppNavigator.openVideoDetail(context, videoId: videoId);
    }
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
      if (videoUrl.startsWith('file://') &&
          ossKey != null &&
          ossKey.isNotEmpty) {
        final baseUrl = ApiClient.instance.options.baseUrl;
        videoUrl =
            '$baseUrl/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
      }

      if (videoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('视频地址暂不可用，请稍后重试')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取视频播放地址失败: $e')));
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
      onUploadCardPressed: () {
        _handleUploadCardPressed();
      },
      onProcessingCardPressed: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .toggleProcessingExpanded,
      onDraftEditModeChanged: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .setDraftEditMode,
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
      finalDraftProgressMessage: flowState.finalDraftProgressLogs.isNotEmpty
          ? flowState.finalDraftProgressLogs.first
          : null,
      onVideoPlayback: _openVideoPlayback,
      onRefreshPressed: ref
          .read(videoSummaryFlowControllerProvider.notifier)
          .refreshProcessingStatus,
      onCloneToKbPressed: () {
        final repo = ref.read(videoSummaryRepositoryProvider);
        final videoId = repo.videoId;
        if (videoId.isEmpty || videoId == 'vid_default') return;
        final flowState = ref.read(videoSummaryFlowControllerProvider);
        final taskId = flowState.taskId;
        if (taskId == null || taskId.isEmpty) return;
        showAddToKnowledgeBaseSheet(
          context: context,
          ref: ref,
          videoId: videoId,
          taskId: taskId,
        );
      },
    );
  }
}
