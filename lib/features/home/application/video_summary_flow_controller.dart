import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../services/models/video_qa_dto.dart' show AttachmentInfo;
import '../../../services/service_providers.dart';
import '../../../services/upload_service.dart';
import '../../../services/models/common_dto.dart';
import '../../../services/websocket/ws_models.dart';
import '../../../services/websocket/ws_provider.dart';
import 'video_summary_result_mapper.dart';
import '../domain/video_summary_domain_models.dart';
import '../domain/simulated_progress_estimator.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import '../video_summary_repository.dart';
import 'video_summary_session_history_controller.dart';
import 'video_summary_settings_controller.dart';

final videoSummaryFlowControllerProvider =
    NotifierProvider<VideoSummaryFlowController, VideoSummaryFlowState>(
      VideoSummaryFlowController.new,
    );

/// 主流程状态：页面只关心“当前展示什么”，具体状态切换由 controller 驱动。
class VideoSummaryFlowState {
  const VideoSummaryFlowState({
    this.taskId,
    required this.videoAsset,
    required this.uploadHighlighted,
    required this.processingExpanded,
    required this.isDraftEditMode,
    required this.isGenerating,
    required this.isSendingChat,
    required this.isTimestampScoped,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.stage,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
    required this.isUploading,
    required this.uploadProgress,
    required this.finalDraftProgressLogs,
    this.errorMessage,
  });

  final String? taskId;
  final VideoAssetInfo videoAsset;
  final bool uploadHighlighted;
  final bool processingExpanded;
  final bool isDraftEditMode;
  final bool isGenerating;
  final bool isSendingChat;
  final bool isTimestampScoped;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final VideoSummaryStage stage;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
  final bool isUploading;
  final double uploadProgress;
  final List<String> finalDraftProgressLogs;
  final String? errorMessage;

  factory VideoSummaryFlowState.initial({
    required VideoAssetInfo videoAsset,
    String? taskId,
  }) {
    return VideoSummaryFlowState(
      taskId: taskId,
      videoAsset: videoAsset,
      uploadHighlighted: false,
      processingExpanded: true,
      isDraftEditMode: false,
      isGenerating: false,
      isSendingChat: false,
      isTimestampScoped: false,
      selectedTimestampStartSeconds: 0,
      selectedTimestampEndSeconds:
          VideoSummaryFlowController.minimumTimestampRangeSeconds,
      stage: VideoSummaryStage.ready,
      processingSnapshot: null,
      draftResult: null,
      finalSummaryData: null,
      chatMessages: const [],
      isUploading: false,
      uploadProgress: 0.0,
      finalDraftProgressLogs: const [],
      errorMessage: null,
    );
  }

  // 用 sentinel 区分“保持原值”和“显式置空”，否则 copyWith 无法安全处理 nullable 字段。
  static const _unset = Object();

  VideoSummaryFlowState copyWith({
    Object? taskId = _unset,
    VideoAssetInfo? videoAsset,
    bool? uploadHighlighted,
    bool? processingExpanded,
    bool? isDraftEditMode,
    bool? isGenerating,
    bool? isSendingChat,
    bool? isTimestampScoped,
    int? selectedTimestampStartSeconds,
    int? selectedTimestampEndSeconds,
    VideoSummaryStage? stage,
    Object? processingSnapshot = _unset,
    Object? draftResult = _unset,
    Object? finalSummaryData = _unset,
    List<ChatMessage>? chatMessages,
    bool? isUploading,
    double? uploadProgress,
    List<String>? finalDraftProgressLogs,
    Object? errorMessage = _unset,
    bool clearError = false,
  }) {
    return VideoSummaryFlowState(
      taskId: taskId == _unset ? this.taskId : taskId as String?,
      videoAsset: videoAsset ?? this.videoAsset,
      uploadHighlighted: uploadHighlighted ?? this.uploadHighlighted,
      processingExpanded: processingExpanded ?? this.processingExpanded,
      isDraftEditMode: isDraftEditMode ?? this.isDraftEditMode,
      isGenerating: isGenerating ?? this.isGenerating,
      isSendingChat: isSendingChat ?? this.isSendingChat,
      isTimestampScoped: isTimestampScoped ?? this.isTimestampScoped,
      selectedTimestampStartSeconds:
          selectedTimestampStartSeconds ?? this.selectedTimestampStartSeconds,
      selectedTimestampEndSeconds:
          selectedTimestampEndSeconds ?? this.selectedTimestampEndSeconds,
      stage: stage ?? this.stage,
      processingSnapshot: processingSnapshot == _unset
          ? this.processingSnapshot
          : processingSnapshot as ProcessingSnapshot?,
      draftResult: draftResult == _unset
          ? this.draftResult
          : draftResult as DraftResult?,
      finalSummaryData: finalSummaryData == _unset
          ? this.finalSummaryData
          : finalSummaryData as FinalSummaryData?,
      chatMessages: chatMessages ?? this.chatMessages,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      finalDraftProgressLogs:
          finalDraftProgressLogs ?? this.finalDraftProgressLogs,
      errorMessage: clearError
          ? null
          : (errorMessage == _unset
                ? this.errorMessage
                : errorMessage as String?),
    );
  }
}

/// 用于 session 恢复的轻量快照，和实时 state 分开，避免把运行时控制字段直接序列化思维化。
class VideoSummaryFlowSnapshot {
  const VideoSummaryFlowSnapshot({
    this.taskId,
    this.videoAsset,
    this.kbid,
    required this.stage,
    required this.uploadHighlighted,
    required this.processingExpanded,
    required this.isTimestampScoped,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.isDraftEditMode,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
    this.isUploading = false,
    this.uploadProgress = 0.0,
  });

  final String? taskId;
  final VideoAssetInfo? videoAsset;
  final String? kbid;
  final VideoSummaryStage stage;
  final bool uploadHighlighted;
  final bool processingExpanded;
  final bool isTimestampScoped;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final bool isDraftEditMode;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
  final bool isUploading;
  final double uploadProgress;
}

/// 视频总结主状态机，负责把 ready -> processing -> draft -> finalChat 串起来。
class VideoSummaryFlowController extends Notifier<VideoSummaryFlowState> {
  static const int minimumTimestampRangeSeconds = 10;

  VideoSummaryRepository get _repository =>
      ref.read(videoSummaryRepositoryProvider);

  /// 当前活跃会话的唯一标识。每次 reset() / restoreSnapshot() 都会重新生成。
  /// 异步生成流程用捕获的局部变量与此比对，防止旧结果污染新会话的状态。
  Object _activeSessionKey = Object();

  /// 处理中阶段的轮询定时器，用于会话恢复后等待后台任务完成。
  Timer? _processingPollTimer;

  /// draft 阶段的轮询定时器，用于等待终稿生成完成（Phase 2）。
  Timer? _draftPollTimer;

  /// 最终稿生成期间的 WS 进度日志订阅。
  StreamSubscription<WSEventEnvelope>? _finalDraftProgressSub;

  /// 虚假模拟进度估算器，用于在后端真实进度到达前驱动主进度条。
  final SimulatedProgressEstimator _simProgressEstimator =
      SimulatedProgressEstimator();

  /// 模拟进度的定时 tick 定时器。
  Timer? _simProgressTimer;

  @override
  VideoSummaryFlowState build() {
    final videoAsset = _repository.getVideoAsset();
    final initialState = VideoSummaryFlowState.initial(
      videoAsset: videoAsset,
      taskId: _repository.activeTaskId,
    );
    final defaultRange = _buildDefaultTimestampRange(videoAsset.durationLabel);
    return initialState.copyWith(
      selectedTimestampStartSeconds: defaultRange.startSeconds,
      selectedTimestampEndSeconds: defaultRange.endSeconds,
    );
  }

  int get videoDurationInSeconds => parseVideoSummaryDurationLabel(
    label: state.videoAsset.durationLabel,
    minimumSeconds: minimumTimestampRangeSeconds,
  );

  String get selectedTimestampLabel => formatVideoSummaryTimestampRange(
    state.selectedTimestampStartSeconds,
    state.selectedTimestampEndSeconds,
  );

  void reset() {
    // 切换会话标识，使所有正在执行的旧异步生成流程的守卫失效
    _activeSessionKey = Object();
    _cancelAllPolling();
    _simProgressEstimator.reset();

    _repository.updateTaskId(null);
    _repository.updateVideoId(defaultVideoId);
    ref.read(currentVideoIdProvider.notifier).state = defaultVideoId;
    ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .activateSession('session-current');
    final settings = ref.read(videoSummarySettingsProvider);
    final defaultRange = _buildDefaultTimestampRange(
      state.videoAsset.durationLabel,
    );
    state = state.copyWith(
      taskId: null,
      videoAsset: VideoAssetInfo(
        title: defaultVideoId,
        durationLabel: '0m 00s',
        sourceLabel: state.videoAsset.sourceLabel,
        fileName: '',
      ),
      uploadHighlighted: false,
      processingExpanded: settings.defaultProcessingExpanded,
      isDraftEditMode: false,
      isGenerating: false,
      isSendingChat: false,
      isUploading: false,
      uploadProgress: 0.0,
      isTimestampScoped: settings.defaultTimestampScoped,
      selectedTimestampStartSeconds: defaultRange.startSeconds,
      selectedTimestampEndSeconds: defaultRange.endSeconds,
      stage: VideoSummaryStage.ready,
      processingSnapshot: null,
      draftResult: null,
      finalSummaryData: null,
      chatMessages: const [],
      errorMessage: null,
    );
  }

  /// 清除错误提示（SnackBar 弹出后由 UI 调用）。
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 用户手动刷新处理进度状态。
  /// 根据当前阶段查询后端任务状态，重新同步前端展示。
  void refreshProcessingStatus() {
    final taskId = state.taskId;
    if (taskId == null || taskId.isEmpty) return;

    if (state.stage == VideoSummaryStage.processing) {
      _recoverProcessingFromBackend(taskId);
    } else if (state.stage == VideoSummaryStage.draft) {
      _recoverDraftFromBackend(taskId);
    }
  }

  Future<String?> pickAndUploadVideo() async {
    if (state.isUploading || state.isGenerating) {
      return null;
    }

    final owningSessionKey = _activeSessionKey;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);

      if (result == null || result.files.single.path == null) {
        return null;
      }

      // 文件选择器是模态弹窗，期间用户可能通过其他方式切换了会话
      if (_activeSessionKey != owningSessionKey) return null;

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final fileSize = result.files.single.size;

      final uploadService = ref.read(uploadServiceProvider);

      // 1. 初始化 TUS 上传（不再调用 createVideo 预注册，video_id 由 Celery
      //    async_finalize_upload 统一创建，前端上传期间用 upload_id 追踪）。
      final initResp = await uploadService.initUpload(
        fileName: fileName,
        totalSize: fileSize,
      );
      if (_activeSessionKey != owningSessionKey) return null;

      final uploadId = initResp.uploadId;
      if (uploadId.isEmpty) {
        throw Exception('Failed to initialize upload: empty upload_id');
      }

      debugPrint(
        '[FlowCtrl] pickAndUploadVideo START — uploadId=$uploadId'
        ' fileName=$fileName stateTaskId=${state.taskId}',
      );

      // 避免 handleFlowStateChanged → syncActiveSession 污染上一次上传的条目
      ref
          .read(videoSummarySessionHistoryProvider.notifier)
          .activateSession('session-current');

      state = state.copyWith(
        taskId: null, // 清除残留 taskId，避免条目以 taskId 而非 temp-upload 为主键
        isUploading: true,
        uploadProgress: 0.0,
        videoAsset: VideoAssetInfo(
          title: '', // 尚无 video_id，Celery 完成后由 _applyCeleryReadyState 填入
          durationLabel: '0m 00s',
          sourceLabel: state.videoAsset.sourceLabel,
          fileName: fileName,
          kbName: state.videoAsset.kbName,
        ),
      );

      ref
          .read(videoSummarySessionHistoryProvider.notifier)
          .addTempUploadSession(
            VideoSummarySessionSnapshot(
              flowSnapshot: captureSnapshot(),
              readyPreferenceText: '',
              draftGuidanceText: '',
              draftBodyText: '',
            ),
            uploadId: uploadId,
          );

      // 2. 分片上传 (每片 10 MiB)
      final file = File(filePath);
      final raf = await file.open(mode: FileMode.read);
      int offset = 0;

      try {
        while (offset < fileSize) {
          final lengthToRead = (fileSize - offset) < UploadService.chunkSize
              ? (fileSize - offset)
              : UploadService.chunkSize;
          final bytes = await raf.read(lengthToRead);
          await uploadService.uploadChunk(
            uploadId: uploadId,
            offset: offset,
            bytes: Uint8List.fromList(bytes),
          );
          offset += lengthToRead;
          final progress = offset / fileSize;

          // 分片上传期间会话切换：更新当前活跃会话状态或后台会话状态
          if (_activeSessionKey == owningSessionKey) {
            state = state.copyWith(uploadProgress: progress);
            ref
                .read(videoSummarySessionHistoryProvider.notifier)
                .syncActiveSession(
                  VideoSummarySessionSnapshot(
                    flowSnapshot: captureSnapshot(),
                    readyPreferenceText: '',
                    draftGuidanceText: '',
                    draftBodyText: '',
                  ),
                );
          } else {
            _updateBackgroundTempSession(
              uploadId: uploadId,
              isUploading: true,
              uploadProgress: progress,
            );
          }
        }
      } finally {
        await raf.close();
      }

      // 3. TUS 上传已完成，但 Celery async_finalize_upload 仍在后台异步处理。
      //    保持 uploading 状态并轮询 upload 状态，直到后端处理完毕再标记为"上传完成"。
      if (_activeSessionKey == owningSessionKey) {
        state = state.copyWith(isUploading: true, uploadProgress: 1.0);
      } else {
        _updateBackgroundTempSession(
          uploadId: uploadId,
          isUploading: true,
          uploadProgress: 1.0,
        );
      }

      // 轮询 GET /api/v1/uploads/{uploadId}，等待 async_finalize_upload 完成。
      // 返回 Celery 创建的 canonical video_id（去重时是已有视频的 ID）。
      final resolvedVideoId = await _waitForCeleryProcessing(
        uploadId,
        owningSessionKey,
        fileName,
      );

      // Celery 完成后同步更新 state、repository 和 provider 中的 videoId
      _repository.updateVideoId(resolvedVideoId);
      ref.read(currentVideoIdProvider.notifier).state = resolvedVideoId;

      // 4. 上传完成：以完成态快照更新侧边栏。
      final completedSnapshot = VideoSummarySessionSnapshot(
        flowSnapshot: captureSnapshot(),
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: '',
      );

      if (_activeSessionKey == owningSessionKey) {
        ref
            .read(videoSummarySessionHistoryProvider.notifier)
            .addTempUploadSession(completedSnapshot, uploadId: uploadId);
      } else {
        _updateBackgroundTempSession(
          uploadId: uploadId,
          isUploading: false,
          uploadProgress: 0.0,
          stage: VideoSummaryStage.ready,
        );
      }

      // 返回 videoId 供调用方决定是否跳转到视频详情页。
      // 仅当发起上传的会话仍是当前活跃会话时才返回有效 ID，
      // 避免在上传期间用户切换会话后被意外跳转。
      return (_activeSessionKey == owningSessionKey) ? resolvedVideoId : null;
    } catch (e) {
      // 错误展示给发起上传的会话（活跃或后台）
      if (_activeSessionKey == owningSessionKey) {
        state = state.copyWith(isUploading: false, uploadProgress: 0.0);
      }
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  void _updateBackgroundTempSession({
    required String uploadId,
    required bool isUploading,
    required double uploadProgress,
    VideoAssetInfo? videoAsset,
    bool? uploadHighlighted,
    VideoSummaryStage? stage,
  }) {
    final historyNotifier = ref.read(
      videoSummarySessionHistoryProvider.notifier,
    );
    final existingEntry =
        historyNotifier.getSessionById('temp-upload-$uploadId');
    if (existingEntry != null) {
      final oldSnapshot = existingEntry.snapshot;
      final updatedFlowSnapshot = VideoSummaryFlowSnapshot(
        taskId: oldSnapshot.flowSnapshot.taskId,
        videoAsset: videoAsset ?? oldSnapshot.flowSnapshot.videoAsset,
        stage: stage ?? oldSnapshot.flowSnapshot.stage,
        uploadHighlighted:
            uploadHighlighted ?? oldSnapshot.flowSnapshot.uploadHighlighted,
        processingExpanded: oldSnapshot.flowSnapshot.processingExpanded,
        isTimestampScoped: oldSnapshot.flowSnapshot.isTimestampScoped,
        selectedTimestampStartSeconds:
            oldSnapshot.flowSnapshot.selectedTimestampStartSeconds,
        selectedTimestampEndSeconds:
            oldSnapshot.flowSnapshot.selectedTimestampEndSeconds,
        isDraftEditMode: oldSnapshot.flowSnapshot.isDraftEditMode,
        processingSnapshot: oldSnapshot.flowSnapshot.processingSnapshot,
        draftResult: oldSnapshot.flowSnapshot.draftResult,
        finalSummaryData: oldSnapshot.flowSnapshot.finalSummaryData,
        chatMessages: oldSnapshot.flowSnapshot.chatMessages,
        isUploading: isUploading,
        uploadProgress: uploadProgress,
      );
      historyNotifier.updateSessionSnapshot(
        'temp-upload-$uploadId',
        VideoSummarySessionSnapshot(
          flowSnapshot: updatedFlowSnapshot,
          readyPreferenceText: oldSnapshot.readyPreferenceText,
          draftGuidanceText: oldSnapshot.draftGuidanceText,
          draftBodyText: oldSnapshot.draftBodyText,
        ),
      );
    }
  }

  Future<void> _ensureKbidResolved() async {
    // 如果 kbid 已经是有效值（非空且非占位符），无需等待
    if (_repository.kbid.isNotEmpty && _repository.kbid != 'kb_default') {
      return;
    }
    try {
      // 等待 defaultKbidProvider 解析完成
      final kbid = await ref.read(defaultKbidProvider.future);
      _repository.updateKbid(kbid);
    } catch (e) {
      // 如果之前网络超时导致 Riverpod 缓存了 Error 状态，在此处进行重置并重试
      debugPrint(
        '[FlowCtrl] defaultKbidProvider resolved with error: $e, invalidating and retrying...',
      );
      ref.invalidate(defaultKbidProvider);
      final kbid = await ref.read(defaultKbidProvider.future);
      _repository.updateKbid(kbid);
    }
  }

  /// 将后端返回的视频时长（秒）同步到本地 videoAsset 和默认时间区间。
  void _updateVideoDuration(int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) return;

    final newLabel = _formatDurationLabel(durationSeconds);
    final currentAsset = state.videoAsset;

    // 仅当当前标签仍是占位值时才更新（避免覆盖用户从历史会话恢复的有效值）
    if (currentAsset.durationLabel == '0m 00s' ||
        currentAsset.durationLabel == '--:--') {
      final updatedAsset = VideoAssetInfo(
        title: currentAsset.title,
        durationLabel: newLabel,
        sourceLabel: currentAsset.sourceLabel,
        fileName: currentAsset.fileName,
        kbName: currentAsset.kbName,
      );
      final defaultRange = _buildDefaultTimestampRange(newLabel);
      state = state.copyWith(
        videoAsset: updatedAsset,
        selectedTimestampStartSeconds: defaultRange.startSeconds,
        selectedTimestampEndSeconds: defaultRange.endSeconds,
        uploadHighlighted: true,
      );
      if (kDebugMode) {
        debugPrint('[FlowCtrl] 视频时长已更新 — $durationSeconds 秒 ($newLabel)');
      }
    }
  }

  /// 把秒数格式化为 durationLabel（例："12m 30s"，"1h 05m 30s"）。
  static String _formatDurationLabel(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  /// TUS 上传完成后，通过 WebSocket + HTTP 轮询双通道监听后端 Celery
  /// async_finalize_upload 处理完毕事件。
  ///
  /// - WebSocket：监听 scope=video_resource 的 completed 事件（实时通知）
  /// - HTTP 轮询：每 2 秒调用 GET /api/v1/uploads/{uploadId} 检查 finalize 状态
  /// - 最长等待 5 分钟，任一通道收到就绪信号即标记上传完成
  ///
  /// 轮询 GET /api/v1/uploads/{uploadId}，等待 Celery async_finalize_upload
  /// 创建 VideoResource 并返回 canonical video_id。
  ///
  /// 返回最终解析的 video_id：
  /// - 正常上传 → Celery 创建的 video_id
  /// - 去重上传 → 返回已有视频的 ID（后端 async_finalize_upload 写入 upload 记录）
  Future<String> _waitForCeleryProcessing(
    String uploadId,
    Object owningSessionKey,
    String fileName,
  ) async {
    const maxAttempts = 150; // 5 分钟 @ 2s 间隔
    const pollInterval = Duration(seconds: 2);

    final uploadService = ref.read(uploadServiceProvider);

    // HTTP 轮询 upload 状态（唯一通道；上传期间无 video_id 故 WS 不可用）
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 先等待间隔，再检查（让后端有时间处理）
      await Future.delayed(pollInterval);

      try {
        final data = await uploadService.getStatus(uploadId);

        final state = data.state;
        if (state == null) continue; // Celery 尚未完成，继续轮询

        switch (state) {
          case 'done':
            // 正常上传完成。优先使用 upload 记录中的 video_id（后端
            // async_finalize_upload 写入，是唯一的 canonical ID）。
            final resolvedId = data.videoId;
            if (resolvedId == null || resolvedId.isEmpty) {
              throw Exception(
                'async_finalize_upload completed but no video_id'
                ' — uploadId=$uploadId',
              );
            }
            await _applyCeleryReadyState(
              videoId: resolvedId,
              uploadId: uploadId,
              owningSessionKey: owningSessionKey,
              fileName: fileName,
              durationSeconds: 0,
              channel: 'HTTP polling',
              attempt: attempt + 1,
            );
            return resolvedId;

          case 'dedup_reused':
            // 去重复用已有视频
            final resolvedId = data.videoId;
            if (resolvedId == null || resolvedId.isEmpty) {
              throw Exception(
                'async_finalize_upload dedup_reused but no video_id'
                ' — uploadId=$uploadId',
              );
            }
            if (kDebugMode) {
              debugPrint(
                '[FlowCtrl] 检测到去重上传'
                ' → 复用 videoId=$resolvedId',
              );
            }
            await _applyCeleryReadyState(
              videoId: resolvedId,
              uploadId: uploadId,
              owningSessionKey: owningSessionKey,
              fileName: fileName,
              durationSeconds: 0,
              channel: 'HTTP polling (dedup)',
              attempt: attempt + 1,
            );
            return resolvedId;

          case 'rejected':
            throw Exception('文件格式不支持，请检查文件后重试');

          case 'failed':
            throw Exception(
              'async_finalize_upload failed — uploadId=$uploadId',
            );

          default:
            // 非终态（created / uploading / uploading_complete / finalizing）
            // 或未知状态，继续轮询
        }
      } catch (e) {
        // 单次轮询失败不中断，继续重试
        debugPrint('[FlowCtrl] Celery 轮询失败 (第 ${attempt + 1} 次): $e');
      }
    }

    // 超时
    throw Exception(
      '文件处理超时，请稍后在视频列表中查看或重试'
      ' — uploadId=$uploadId',
    );
  }

  /// 将 Celery 就绪状态应用到当前 state 或后台临时会话。
  Future<void> _applyCeleryReadyState({
    required String videoId,
    required String uploadId,
    required Object owningSessionKey,
    required String fileName,
    required int durationSeconds,
    required String channel,
    int? attempt,
    String? transcribeStatus,
    String? frameExtractionStatus,
    String? extractCompletedAt,
  }) async {
    final hasDuration = durationSeconds > 0;
    final durationLabel = hasDuration
        ? _formatDurationLabel(durationSeconds)
        : '0m 00s';

    if (_activeSessionKey == owningSessionKey) {
      debugPrint(
        '[FlowCtrl] _applyCeleryReadyState — videoId=$videoId'
        ' isUploading→false channel=$channel'
        ' taskId=${state.taskId}',
      );
      state = state.copyWith(
        isUploading: false,
        uploadHighlighted: true,
        videoAsset: VideoAssetInfo(
          title: videoId,
          durationLabel: durationLabel,
          sourceLabel: state.videoAsset.sourceLabel,
          fileName: fileName,
          kbName: state.videoAsset.kbName,
        ),
      );
    } else {
      _updateBackgroundTempSession(
        uploadId: uploadId,
        isUploading: false,
        uploadProgress: 0.0,
        videoAsset: VideoAssetInfo(
          title: videoId,
          durationLabel: durationLabel,
          sourceLabel: _repository.kbid,
          fileName: fileName,
          kbName: state.videoAsset.kbName,
        ),
        uploadHighlighted: true,
      );
    }

    if (kDebugMode) {
      final extra = attempt != null ? ' (第 $attempt 次轮询)' : '';
      debugPrint(
        '[FlowCtrl] Celery 处理完成 — videoId=$videoId'
        ' channel=$channel$extra'
        ' duration=${durationSeconds}s'
        ' transcribe=$transcribeStatus'
        ' frameExtraction=$frameExtractionStatus'
        ' extractCompletedAt=$extractCompletedAt',
      );
    }
  }

  void toggleProcessingExpanded() {
    if (state.stage != VideoSummaryStage.processing) {
      return;
    }

    state = state.copyWith(processingExpanded: !state.processingExpanded);
  }

  void setDraftEditMode(bool value) {
    state = state.copyWith(isDraftEditMode: value);
  }

  void setTimestampScope(bool value) {
    state = state.copyWith(isTimestampScoped: value);
  }

  void setTimestampRange(TimestampRangeSelection range) {
    state = state.copyWith(
      selectedTimestampStartSeconds: range.startSeconds,
      selectedTimestampEndSeconds: range.endSeconds,
    );
  }

  /// 从视频详情页发起新任务。
  /// 设置视频信息和 KB，然后启动任务创建 + 进度监控流程。
  Future<void> startTaskFromVideo({
    required String videoId,
    required String kbid,
    String? userInitialPreference,
    String? fileName,
  }) async {
    if (state.isGenerating) return;

    // 设置 repository 的 videoId 和 kbid
    _repository.updateVideoId(videoId);
    _repository.updateKbid(kbid);
    ref.read(currentVideoIdProvider.notifier).state = videoId;

    // 更新 state 的视频资产信息
    state = state.copyWith(
      videoAsset: VideoAssetInfo(
        title: videoId,
        durationLabel: '0m 00s',
        sourceLabel: kbid,
        fileName: fileName ?? videoId,
      ),
      uploadHighlighted: true,
    );

    // 调用统一的生成流程
    await _runDraftGeneration(
      kbid: kbid,
      userInitialPreference: userInitialPreference,
    );
  }

  Future<void> startDraftGeneration({String? userInitialPreference}) async {
    if (state.isGenerating) return;

    // 确保 kbid 已解析（保留兼容：从主页 UI 触发时）
    await _ensureKbidResolved();
    final kbid = _repository.kbid;

    await _runDraftGeneration(
      kbid: kbid,
      userInitialPreference: userInitialPreference,
    );
  }

  /// 核心任务创建 + WebSocket 进度监控流程。
  Future<void> _runDraftGeneration({
    required String kbid,
    String? userInitialPreference,
  }) async {
    final settings = ref.read(videoSummarySettingsProvider);

    // 重置模拟进度估算器
    _simProgressEstimator.reset();
    _cancelSimProgressTimer();

    // 每次重新生成草稿，都要清掉后续阶段结果，并立即切换为 processing 阶段以提供用户反馈
    state = state.copyWith(
      isGenerating: true,
      stage: VideoSummaryStage.processing,
      processingExpanded: settings.defaultProcessingExpanded,
      processingSnapshot: buildInitialProcessingSnapshot(),
      draftResult: null,
      finalSummaryData: null,
      chatMessages: const [],
    );

    // 启动模拟进度定时器：在后端真实事件到达前，缓慢推进进度条
    _simProgressTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) {
        _simProgressEstimator.tick();
        final current = state.processingSnapshot;
        if (current != null && _simProgressEstimator.currentPercent / 100.0 > current.progress) {
          state = state.copyWith(
            processingSnapshot: ProcessingSnapshot(
              progress: _simProgressEstimator.currentPercent / 100.0,
              statusLabel: current.statusLabel,
              etaLabel: current.etaLabel,
              chunkProgress: current.chunkProgress,
              statusLog: current.statusLog,
            ),
          );
        }
      },
    );

    // 捕获当前会话标识，后续所有异步回调都以此校验所有权。
    // 使用局部变量 + Object 引用比对，reset()/restoreSnapshot() 会创建新 Object，
    // 使旧异步流程的引用自动失效，不受 state.taskId 可能为 null 的影响。
    final owningSessionKey = _activeSessionKey;

    try {
      await for (final processingData in _repository.startDraftGeneration(
        kbid: kbid,
        userInitialPreference:
            (userInitialPreference != null && userInitialPreference.isNotEmpty)
            ? userInitialPreference
            : null,
      )) {
        // 若在 SSE 流期间发生了会话切换，则停止消费后续事件
        if (_activeSessionKey != owningSessionKey) {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] SSE 流中止 — 会话已切换');
          }
          return;
        }

        // 首帧到达时 task 已创建完毕，同步 taskId + kbName 到 state，
        // 确保后续 captureSnapshot() 能拿到正确的 taskId 且 HeroCard 能显示 kbName 标签
        if (state.taskId == null && _repository.activeTaskId != null) {
          final repoKbName = _repository.kbName;
          state = state.copyWith(
            taskId: _repository.activeTaskId,
            videoAsset: repoKbName != null
                ? VideoAssetInfo(
                    title: state.videoAsset.title,
                    durationLabel: state.videoAsset.durationLabel,
                    sourceLabel: state.videoAsset.sourceLabel,
                    fileName: state.videoAsset.fileName,
                    kbName: repoKbName,
                  )
                : state.videoAsset,
          );
          // 同步更新侧边栏条目（syncActiveSession 仅在上传时调用，此时补充更新 kbName）
          if (repoKbName != null) {
            ref.read(videoSummarySessionHistoryProvider.notifier)
                .syncActiveSession(
                  VideoSummarySessionSnapshot(
                    flowSnapshot: captureSnapshot(),
                    readyPreferenceText: '',
                    draftGuidanceText: '',
                    draftBodyText: '',
                  ),
                );
          }
        }

        // 使用模拟进度驱动主进度条
        final realPercent = (processingData.progress * 100).round();
        final isCompleted = processingData.progress >= 1.0;
        final simulatedPercent = _simProgressEstimator.feedRealProgress(
          realPercent,
          isCompleted: isCompleted,
        );

        final snapshot = mapProcessingDataToSnapshot(processingData);
        // 用模拟进度覆盖真实进度，驱动 HeroCard 主进度条
        final overriddenSnapshot = ProcessingSnapshot(
          progress: simulatedPercent / 100.0,
          statusLabel: snapshot.statusLabel,
          etaLabel: _buildSimulatedEtaLabel(processingData, simulatedPercent),
          chunkProgress: snapshot.chunkProgress,
          statusLog: snapshot.statusLog,
        );

        state = state.copyWith(processingSnapshot: overriddenSnapshot);
      }

      // 若在 await for 期间发生了会话切换，不再继续
      if (_activeSessionKey != owningSessionKey) {
        if (kDebugMode) {
          debugPrint('[FlowCtrl] 跳过草稿获取 — 会话已切换');
        }
        return;
      }

      // repository 返回的是 raw draft data，进入页面前统一转换成 presentation model。
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());

      // 再次校验：获取草稿期间可能发生会话切换
      if (_activeSessionKey != owningSessionKey) {
        if (kDebugMode) {
          debugPrint('[FlowCtrl] 跳过草稿更新 — 会话已切换');
        }
        return;
      }

      state = state.copyWith(
        draftResult: draft,
        stage: VideoSummaryStage.draft,
        processingExpanded: false,
        isDraftEditMode: false,
      );
    } catch (e) {
      // 只有当前会话未改变时才展示错误
      if (_activeSessionKey != owningSessionKey) {
        if (kDebugMode) {
          debugPrint('[FlowCtrl] 跳过错误展示 — 会话已切换');
        }
        return;
      }
      debugPrint('[FlowCtrl] Start draft generation failed: $e');
      final String errorMsg;
      if (e is TaskConflictException) {
        errorMsg = e.message ?? '该知识库已存在同视频的任务，请前往视频详情页管理';
      } else if (e is DioException) {
        errorMsg = ApiError.fromDioException(e).userMessage;
      } else {
        errorMsg = '生成草稿失败，请稍后重试';
      }
      state = state.copyWith(
        stage: VideoSummaryStage.ready,
        errorMessage: errorMsg,
      );
    } finally {
      _cancelSimProgressTimer();
      // 仅当本此生成未被取消时才重置标志位
      if (_activeSessionKey == owningSessionKey) {
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  Future<void> generateFinalSummary({
    required String guidance,
    required String draftBodyText,
  }) async {
    final draft = state.draftResult;
    if (state.isGenerating || draft == null) {
      return;
    }

    // 最终稿生成基于”当前可编辑文本框中的内容”，而不是仅基于最初草稿结果。
    final editedParagraphs = draftBodyText
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final effectiveDraft = DraftResult(
      paragraphs: editedParagraphs.isEmpty
          ? draft.paragraphs
          : editedParagraphs,
      suggestionHint: draft.suggestionHint,
    );

    final owningSessionKey = _activeSessionKey;

    // ★ 立即进入 finalChat 阶段，HeroCard 标题变为”最终稿生成中...”
    state = state.copyWith(
      stage: VideoSummaryStage.finalChat,
      isGenerating: true,
      finalDraftProgressLogs: [],
      draftResult: effectiveDraft,
      finalSummaryData: null,
      chatMessages: const [],
    );

    try {
      _listenFinalDraftProgress();

      final summary = await _repository.generateFinalSummary(
        guidance: guidance,
        draftParagraphs: effectiveDraft.paragraphs,
      );

      // 异步等待期间可能发生会话切换
      if (_activeSessionKey != owningSessionKey) return null;

      final summaryData = mapFinalResultDataToSummary(summary);
      // 进入 finalChat 时，会用总结中的首个时间片段给时间旅行功能提供默认范围。
      final seededRange = _buildRangeFromSummary(summaryData);
      state = state.copyWith(
        isGenerating: false,
        finalSummaryData: summaryData,
        chatMessages: List<ChatMessage>.from(summaryData.messages),
        selectedTimestampStartSeconds: seededRange.startSeconds,
        selectedTimestampEndSeconds: seededRange.endSeconds,
      );
    } finally {
      if (_activeSessionKey == owningSessionKey) {
        _cancelFinalDraftProgress();
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  String _formatHHMMSS(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> sendChatMessage(String rawMessage, {List<AttachmentInfo> attachments = const []}) async {
    final message = rawMessage.trim();
    if (state.isSendingChat || (message.isEmpty && attachments.isEmpty)) {
      return;
    }

    final owningSessionKey = _activeSessionKey;

    // 时间旅行模式开启时，把当前时间范围一起附着到用户消息上，便于 UI 回显上下文。
    final timestampLabel = state.isTimestampScoped
        ? formatVideoSummaryTimestampRange(
            state.selectedTimestampStartSeconds,
            state.selectedTimestampEndSeconds,
          )
        : null;

    final userMessage = ChatMessage(
      sender: SummaryChatSender.user,
      text: message,
      timestampLabel: timestampLabel,
      attachments: attachments
          .map((a) => ChatAttachment(
                name: a.name,
                ossKey: a.ossKey,
                mimeType: a.mimeType,
                presignedUrl: a.presignedUrl,
              ))
          .toList(),
    );

    // 追加一条空系统回复，用于 SSE 流式追加
    final systemMessage = ChatMessage(
      sender: SummaryChatSender.system,
      text: '',
      timestampLabel: timestampLabel,
    );

    state = state.copyWith(
      isSendingChat: true,
      chatMessages: [...state.chatMessages, userMessage, systemMessage],
    );

    final timestamp = _formatHHMMSS(state.selectedTimestampStartSeconds);
    final windowSeconds = state.isTimestampScoped
        ? (state.selectedTimestampEndSeconds -
              state.selectedTimestampStartSeconds)
        : null;

    try {
      final sseStream = _repository.sendSummaryChatMessage(
        message,
        timestamp: timestamp,
        windowSeconds: windowSeconds,
        attachments: attachments,
      );

      await for (final reply in sseStream) {
        // 若在 SSE 流期间发生了会话切换，则停止消费
        if (_activeSessionKey != owningSessionKey) {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] 聊天 SSE 流中止 — 会话已切换');
          }
          return;
        }

        // 将后端 cited_sources（原始 Map 列表）映射为 UI 模型
        List<ChatMessageCitation>? citations;
        if (reply.citedSources != null && reply.citedSources!.isNotEmpty) {
          citations = reply.citedSources!
              .map(
                (m) => ChatMessageCitation(
                  quote: (m['quote'] as String?) ?? '',
                  videoId: m['video_id'] as String?,
                  timeRange: m['time_range'] as String?,
                ),
              )
              .toList();
        }

        final currentMessages = List<ChatMessage>.from(state.chatMessages);
        if (currentMessages.isNotEmpty) {
          final lastMsg = currentMessages.last;
          currentMessages[currentMessages.length - 1] = ChatMessage(
            sender: lastMsg.sender,
            text: reply.text,
            timestampLabel: lastMsg.timestampLabel,
            citations: citations,
          );
          state = state.copyWith(chatMessages: currentMessages);
        }
      }
    } catch (e) {
      // 错误只展示给发起消息的会话
      if (_activeSessionKey != owningSessionKey) return null;
      debugPrint('[FlowController] SSE QA failed: $e');
      final currentMessages = List<ChatMessage>.from(state.chatMessages);
      if (currentMessages.isNotEmpty) {
        final lastMsg = currentMessages.last;
        currentMessages[currentMessages.length - 1] = ChatMessage(
          sender: lastMsg.sender,
          text: '错误：$e',
          timestampLabel: lastMsg.timestampLabel,
        );
        state = state.copyWith(chatMessages: currentMessages);
      }
    } finally {
      if (_activeSessionKey == owningSessionKey) {
        state = state.copyWith(isSendingChat: false);
      }
    }
  }

  VideoSummaryFlowSnapshot captureSnapshot() {
    return VideoSummaryFlowSnapshot(
      taskId: state.taskId,
      videoAsset: state.videoAsset,
      kbid: _repository.kbid.isNotEmpty ? _repository.kbid : null,
      stage: state.stage,
      uploadHighlighted: state.uploadHighlighted,
      processingExpanded: state.processingExpanded,
      isTimestampScoped: state.isTimestampScoped,
      selectedTimestampStartSeconds: state.selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: state.selectedTimestampEndSeconds,
      isDraftEditMode: state.isDraftEditMode,
      processingSnapshot: state.processingSnapshot,
      draftResult: state.draftResult,
      finalSummaryData: state.finalSummaryData,
      chatMessages: List<ChatMessage>.from(state.chatMessages),
      isUploading: state.isUploading,
      uploadProgress: state.uploadProgress,
    );
  }

  void restoreSnapshot(VideoSummaryFlowSnapshot snapshot) {
    // 切换会话标识，使所有正在执行的旧异步生成流程的守卫失效
    _activeSessionKey = Object();
    _cancelAllPolling();

    final videoAsset = snapshot.videoAsset ?? state.videoAsset;
    state = state.copyWith(
      taskId: snapshot.taskId,
      videoAsset: videoAsset,
      stage: snapshot.stage,
      uploadHighlighted: snapshot.uploadHighlighted,
      processingExpanded: snapshot.processingExpanded,
      isGenerating: false,
      isSendingChat: false,
      isTimestampScoped: snapshot.isTimestampScoped,
      selectedTimestampStartSeconds: snapshot.selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: snapshot.selectedTimestampEndSeconds,
      isDraftEditMode: snapshot.isDraftEditMode,
      processingSnapshot: snapshot.processingSnapshot,
      draftResult: snapshot.draftResult,
      finalSummaryData: snapshot.finalSummaryData,
      chatMessages: List<ChatMessage>.from(snapshot.chatMessages),
      isUploading: snapshot.isUploading,
      uploadProgress: snapshot.uploadProgress,
    );

    // 同步 repository 和 provider 的 videoId（从快照的 videoAsset.title 中获取）
    if (videoAsset.title.isNotEmpty && videoAsset.title != 'vid_default') {
      _repository.updateVideoId(videoAsset.title);
      ref.read(currentVideoIdProvider.notifier).state = videoAsset.title;
    }

    // 同步 repository 的 taskId，否则后续追问会报 "No active task"
    if (snapshot.taskId != null && snapshot.taskId!.isNotEmpty) {
      _repository.updateTaskId(snapshot.taskId);
    } else {
      _repository.updateTaskId(null);
    }

    // 同步 repository 的 kbid，确保后续操作（如追问）能拿到正确的知识库
    if (snapshot.kbid != null && snapshot.kbid!.isNotEmpty) {
      _repository.updateKbid(snapshot.kbid!);
    }

    // 旧快照的 durationLabel 可能是占位值，异步从后端刷新真实时长
    if (state.videoAsset.durationLabel == '0m 00s' ||
        state.videoAsset.durationLabel == '--:--') {
      _refreshVideoDurationFromBackend();
    }

    // 历史会话的 chatMessages 未持久化到快照，从后端 QA 记录异步回填。
    // 同时处理 finalChat 子状态恢复：若 finalSummaryData 为空，说明切走时正
    // 在生成终稿，需查询后端确认任务是否仍在 finalGenerating 并恢复监听。
    if (snapshot.stage == VideoSummaryStage.finalChat &&
        snapshot.taskId != null &&
        snapshot.taskId!.isNotEmpty) {
      if (snapshot.finalSummaryData != null) {
        // 正常 finalChat：回填 Q&A 聊天记录
        _refreshChatMessagesFromBackend(snapshot.taskId!);
      } else {
        // 切走时正在生成终稿 → 查询后端状态并恢复
        _recoverFinalChatFromBackend(snapshot.taskId!);
      }
    }

    // 恢复 processing 阶段的会话时，查询后端确认任务的实际进度。
    if (snapshot.stage == VideoSummaryStage.processing &&
        snapshot.taskId != null &&
        snapshot.taskId!.isNotEmpty) {
      _recoverProcessingFromBackend(snapshot.taskId!);
    }

    // 恢复 draft 阶段的会话时，查询后端是否已进入终稿生成或已完成。
    // 防止用户在终稿生成期间切走，回来时卡在草稿页。
    if (snapshot.stage == VideoSummaryStage.draft &&
        snapshot.taskId != null &&
        snapshot.taskId!.isNotEmpty) {
      _recoverDraftFromBackend(snapshot.taskId!);
    }
  }

  /// 从后端获取视频真实时长并更新本地状态（用于快照恢复场景）。
  Future<void> _refreshVideoDurationFromBackend() async {
    // 捕获当前 videoId，防止异步返回时已切换到其他会话
    final capturedVideoId = _repository.videoId;
    try {
      final videoService = ref.read(videoServiceProvider);
      final resp = await videoService.getVideo(_repository.videoId);
      final data = resp.data;
      if (data == null) return;

      // 若在异步等待期间发生了会话切换，放弃本次结果
      if (_repository.videoId != capturedVideoId) return;

      // 优先使用后端返回的 duration 字段
      int? effectiveDuration = data.duration;

      // Fallback：后端 duration 可能为 0，从 keyframes 的最大时间戳推算
      if ((effectiveDuration == null || effectiveDuration <= 0) &&
          data.keyframes != null &&
          data.keyframes!.isNotEmpty) {
        for (final kf in data.keyframes!) {
          final parts = (kf.time ?? '').split(':');
          if (parts.length >= 2) {
            final min = int.tryParse(parts[0]) ?? 0;
            final sec = int.tryParse(parts[1]) ?? 0;
            final total = min * 60 + sec;
            if (total > (effectiveDuration ?? 0)) {
              effectiveDuration = total;
            }
          }
        }
        // 加上一些余量（最后一个关键帧之后可能还有内容）
        if (effectiveDuration != null && effectiveDuration > 0) {
          effectiveDuration = effectiveDuration + 5;
        }
      }

      if (effectiveDuration != null && effectiveDuration > 0) {
        _updateVideoDuration(effectiveDuration);
      }
    } catch (_) {
      // 静默失败，用户仍可使用占位时长
    }
  }

  /// 从后端拉取该任务的 Q&A 记录，回填到 chatMessages 中。
  /// 用于历史会话恢复：快照中的 chatMessages 为空（后端未持久化），
  /// 但 Q&A 记录已存入 video_qa_records 表，可据此重建对话列表。
  Future<void> _refreshChatMessagesFromBackend(String taskId) async {
    try {
      final qaService = ref.read(videoQAServiceProvider);
      final resp = await qaService.listQAs(
        taskId,
        params: PageParams(page: 1, pageSize: 100),
      );
      final qas = resp.data;
      if (qas.isEmpty) return;

      final messages = <ChatMessage>[];
      for (final qa in qas) {
        // 构建时间标签：当 startTime == endTime 时说明用户未开启时间区间，
        // 此时不生成标签（与 sendChatMessage 中 isTimestampScoped=false 行为一致）
        String? timestampLabel;
        final st = qa.startTime;
        final et = qa.endTime;
        if (st != null &&
            st.isNotEmpty &&
            et != null &&
            et.isNotEmpty &&
            st != et) {
          timestampLabel = '$st - $et';
        }

        // 用户问题
        if (qa.questionContent.isNotEmpty) {
          messages.add(
            ChatMessage(
              sender: SummaryChatSender.user,
              text: qa.questionContent,
              timestampLabel: timestampLabel,
            ),
          );
        }

        // 系统回答
        if (qa.answerContent != null && qa.answerContent!.isNotEmpty) {
          // 将后端 cited_sources（原始 Map 列表）映射为 UI 模型
          List<ChatMessageCitation>? citations;
          if (qa.citedSources.isNotEmpty) {
            citations = qa.citedSources
                .map(
                  (m) => ChatMessageCitation(
                    quote: (m['quote'] as String?) ?? '',
                    videoId: m['video_id'] as String?,
                    timeRange: m['time_range'] as String?,
                  ),
                )
                .toList();
          }

          messages.add(
            ChatMessage(
              sender: SummaryChatSender.system,
              text: qa.answerContent!,
              timestampLabel: timestampLabel,
              citations: citations,
            ),
          );
        }
      }

      if (messages.isNotEmpty && state.taskId == taskId) {
        state = state.copyWith(chatMessages: messages);
        if (kDebugMode) {
          debugPrint(
            '[FlowCtrl] 从后端回填了 ${messages.length} 条 Q&A 聊天记录 — taskId=$taskId',
          );
        }
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 回填聊天记录失败: $e');
    }
  }

  /// 订阅 WS progress/statusUpdate 事件，用于最终稿生成期间的进度展示。
  void _listenFinalDraftProgress() {
    _cancelFinalDraftProgress();

    final taskId = state.taskId;
    if (taskId == null) return;

    final wsClient = ref.read(wsClientProvider);
    final wsStream = wsClient.eventStream.where(
      (env) =>
          env.scope == WSScope.videoSummaryTask &&
          env.scopeId == taskId &&
          (env.eventType == WSEventType.progress ||
              env.eventType == WSEventType.statusUpdate),
    );

    Timer? debounce;
    _finalDraftProgressSub = wsStream.listen((env) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), () {
        final message = env.message;
        if (message != null && message.isNotEmpty) {
          state = state.copyWith(
            finalDraftProgressLogs: [
              message,
              ...state.finalDraftProgressLogs.take(19),
            ],
          );
        }
      });
    });
  }

  /// 取消最终稿生成期间的 WS 进度日志订阅。
  void _cancelFinalDraftProgress() {
    _finalDraftProgressSub?.cancel();
    _finalDraftProgressSub = null;
  }

  /// 取消处理中阶段的轮询定时器。
  void _cancelProcessingPoll() {
    _processingPollTimer?.cancel();
    _processingPollTimer = null;
  }

  /// 取消 draft 阶段的状态轮询定时器。
  void _cancelDraftStatusPoll() {
    _draftPollTimer?.cancel();
    _draftPollTimer = null;
  }

  /// 取消模拟进度定时器。
  void _cancelSimProgressTimer() {
    _simProgressTimer?.cancel();
    _simProgressTimer = null;
  }

  /// 取消所有轮询定时器（processing + draft）和 WS 进度订阅。
  void _cancelAllPolling() {
    _cancelProcessingPoll();
    _cancelDraftStatusPoll();
    _cancelFinalDraftProgress();
    _cancelSimProgressTimer();
  }

  /// 恢复 processing 阶段的会话时，查询后端确认任务的实际进度。
  ///
  /// 场景：用户在 SSE 生成期间切走，任务在后台完成/失败，切回来时快照
  /// 仍为 processing — 若不做后端检查就会卡在进度页。
  Future<void> _recoverProcessingFromBackend(String taskId) async {
    final owningSessionKey = _activeSessionKey;
    try {
      final taskInfo = await _repository.getTaskStatus(taskId);
      if (taskInfo == null) {
        debugPrint('[FlowCtrl] 恢复处理中会话失败 — taskId=$taskId 不存在');
        return;
      }

      // 再次校验：恢复期间用户可能又切走了
      if (_activeSessionKey != owningSessionKey) return null;

      if (kDebugMode) {
        debugPrint(
          '[FlowCtrl] 恢复处理中会话 — taskId=$taskId'
          ' workflowState=${taskInfo.workflowState.name}',
        );
      }

      switch (taskInfo.workflowState) {
        case WorkflowState.waitingUserApproval:
          // 草稿已生成完毕，直接获取并跳转
          await _transitionToDraftFromBackend(taskId, owningSessionKey);
          break;

        case WorkflowState.completed:
          // 已最终完成：先取草稿，再构建终稿数据跳转到 finalChat
          await _transitionToDraftFromBackend(taskId, owningSessionKey);
          break;

        case WorkflowState.failed:
          if (_activeSessionKey != owningSessionKey) return null;
          state = state.copyWith(
            stage: VideoSummaryStage.ready,
            errorMessage: '视频处理失败，请重试',
          );
          break;

        case WorkflowState.draftGenerating:
          // Phase 1 仍在运行，重新订阅 WS 实时进度
          _resumeDraftGeneration(taskId, owningSessionKey);
          break;

        case WorkflowState.finalGenerating:
          // Phase 1 已完成、Phase 2 正在进行。
          // 先取草稿跳转到 draft，再建立 Phase 2 的 WS 监听。
          await _transitionToDraftFromBackend(taskId, owningSessionKey);
          if (_activeSessionKey != owningSessionKey) return null;
          _recoverDraftFromBackend(taskId);
          break;
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 恢复处理中会话异常 — taskId=$taskId: $e');
    }
  }

  /// 恢复 draft 阶段的会话时，查询后端确认终稿生成的实际进度。
  Future<void> _recoverDraftFromBackend(String taskId) async {
    final owningSessionKey = _activeSessionKey;
    try {
      final taskInfo = await _repository.getTaskStatus(taskId);
      if (taskInfo == null || _activeSessionKey != owningSessionKey) return;

      if (kDebugMode) {
        debugPrint(
          '[FlowCtrl] 恢复草稿阶段会话 — taskId=$taskId'
          ' workflowState=${taskInfo.workflowState.name}',
        );
      }

      switch (taskInfo.workflowState) {
        case WorkflowState.completed:
          // 终稿已生成完毕，直接获取并跳转到 finalChat
          await _transitionToFinalChatFromBackend(taskId, owningSessionKey);
          break;

        case WorkflowState.finalGenerating:
          // 终稿生成仍在运行，重新订阅 WS 等待完成
          _resumeFinalGeneration(taskId, owningSessionKey);
          break;

        case WorkflowState.waitingUserApproval:
          // 仍在等待用户审批，正常停留在 draft 页面即可
          break;

        case WorkflowState.failed:
          if (_activeSessionKey != owningSessionKey) return null;
          state = state.copyWith(errorMessage: '终稿生成失败，请重试');
          break;

        case WorkflowState.draftGenerating:
          // 理论上 draft 阶段不应该出现此状态，但做防御处理
          _recoverProcessingFromBackend(taskId);
          break;
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 恢复草稿阶段会话异常 — taskId=$taskId: $e');
    }
  }

  /// 恢复 finalChat 阶段会话时，查询后端确认终稿生成的实际进度。
  ///
  /// 场景：用户在终稿生成中（finalChat + isGenerating=true）切走，
  /// 快照中 finalSummaryData 为空。切回来时需判断任务是已完成还是仍在生成中。
  Future<void> _recoverFinalChatFromBackend(String taskId) async {
    final owningSessionKey = _activeSessionKey;
    try {
      final taskInfo = await _repository.getTaskStatus(taskId);
      if (taskInfo == null || _activeSessionKey != owningSessionKey) return;

      if (kDebugMode) {
        debugPrint(
          '[FlowCtrl] 恢复 finalChat 阶段会话 — taskId=$taskId'
          ' workflowState=${taskInfo.workflowState.name}',
        );
      }

      switch (taskInfo.workflowState) {
        case WorkflowState.completed:
          // 终稿已生成完毕，直接获取并填充数据
          await _transitionToFinalChatFromBackend(taskId, owningSessionKey);
          break;

        case WorkflowState.finalGenerating:
          // 终稿生成仍在运行，恢复生成中状态并重新订阅 WS
          if (_activeSessionKey != owningSessionKey) return null;
          _resumeFinalGeneration(taskId, owningSessionKey);
          break;

        case WorkflowState.failed:
          if (_activeSessionKey != owningSessionKey) return null;
          state = state.copyWith(errorMessage: '终稿生成失败，请重试');
          break;

        case WorkflowState.waitingUserApproval:
        case WorkflowState.draftGenerating:
          // 理论上级不该出现此状态（finalChat 阶段应已完成 Phase 1），
          // 做防御处理：回退到 draft 恢复流程
          if (_activeSessionKey != owningSessionKey) return null;
          state = state.copyWith(
            stage: VideoSummaryStage.draft,
            isGenerating: false,
          );
          _recoverDraftFromBackend(taskId);
          break;
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 恢复 finalChat 阶段会话异常 — taskId=$taskId: $e');
    }
  }

  /// 重新订阅 WS 等待终稿生成完成（Phase 2）。
  /// 不调用 approveAndFinalize，仅等待已有任务的 WS completed 事件。
  /// 同时启动并行轮询，作为 WS 静默失效的兜底。
  Future<void> _resumeFinalGeneration(
    String taskId,
    Object owningSessionKey,
  ) async {
    if (kDebugMode) {
      debugPrint('[FlowCtrl] 开始恢复终稿生成 WS 监听 — taskId=$taskId');
    }

    // ★ 立即进入 finalChat 阶段 + 生成中状态
    state = state.copyWith(
      stage: VideoSummaryStage.finalChat,
      isGenerating: true,
      finalDraftProgressLogs: [],
      finalSummaryData: null,
      chatMessages: const [],
    );

    // 开始 WS 进度日志监听
    _listenFinalDraftProgress();

    // 立即启动并行轮询，作为 WS 静默失效的兜底
    _startDraftStatusPoll(taskId, owningSessionKey);

    try {
      // resumeFinalGeneration 内部已处理"已完成"的短路情况
      final summary = await _repository.resumeFinalGeneration(taskId);

      _cancelDraftStatusPoll();
      if (_activeSessionKey != owningSessionKey) return null;

      final summaryData = mapFinalResultDataToSummary(summary);
      final seededRange = _buildRangeFromSummary(summaryData);
      state = state.copyWith(
        isGenerating: false,
        finalSummaryData: summaryData,
        chatMessages: List<ChatMessage>.from(summaryData.messages),
        selectedTimestampStartSeconds: seededRange.startSeconds,
        selectedTimestampEndSeconds: seededRange.endSeconds,
      );

      if (kDebugMode) {
        debugPrint('[FlowCtrl] 恢复的终稿生成已完成 — taskId=$taskId');
      }
    } catch (e) {
      if (_activeSessionKey != owningSessionKey) {
        _cancelDraftStatusPoll();
        return;
      }
      debugPrint('[FlowCtrl] 恢复终稿生成失败，轮询兜底中 — taskId=$taskId: $e');
      // 轮询已在运行，无需额外操作
    } finally {
      if (_activeSessionKey == owningSessionKey) {
        _cancelFinalDraftProgress();
      }
    }
  }

  /// 从后端获取终稿结果并跳转到 finalChat 阶段。
  Future<void> _transitionToFinalChatFromBackend(
    String taskId,
    Object owningSessionKey,
  ) async {
    try {
      _repository.updateTaskId(taskId);

      // 先获取草稿信息
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());
      if (_activeSessionKey != owningSessionKey) return null;

      // 通过 getTask 获取终稿数据
      final taskInfo = await _repository.getTaskStatus(taskId);
      if (taskInfo == null || _activeSessionKey != owningSessionKey) return;

      final finalBody = taskInfo.finalSummary ?? taskInfo.draftSummary ?? '';
      final summaryData = FinalSummaryData(
        summaryTitle: '视频总结',
        summaryBody: finalBody,
        timestampChips: const [],
        messages: const [],
      );

      final seededRange = _buildRangeFromSummary(summaryData);
      state = state.copyWith(
        draftResult: draft,
        finalSummaryData: summaryData,
        chatMessages: List<ChatMessage>.from(summaryData.messages),
        stage: VideoSummaryStage.finalChat,
        isGenerating: false,
        selectedTimestampStartSeconds: seededRange.startSeconds,
        selectedTimestampEndSeconds: seededRange.endSeconds,
      );

      if (kDebugMode) {
        debugPrint('[FlowCtrl] 后台终稿已完成，已跳转到 finalChat — taskId=$taskId');
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 获取后台终稿失败 — taskId=$taskId: $e');
      if (_activeSessionKey != owningSessionKey) return null;
      state = state.copyWith(errorMessage: '获取终稿失败，请重试');
    }
  }

  /// 从后端获取草稿结果并跳转到 draft 阶段。
  Future<void> _transitionToDraftFromBackend(
    String taskId,
    Object owningSessionKey,
  ) async {
    try {
      // 先确保 repository 的 taskId 指向正确任务
      _repository.updateTaskId(taskId);
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());

      // 校验：获取期间用户可能又切走了
      if (_activeSessionKey != owningSessionKey) return null;

      state = state.copyWith(
        draftResult: draft,
        stage: VideoSummaryStage.draft,
        processingExpanded: false,
        isDraftEditMode: false,
      );

      if (kDebugMode) {
        debugPrint('[FlowCtrl] 后台任务已完成，已跳转到草稿页 — taskId=$taskId');
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 获取后台草稿失败 — taskId=$taskId: $e');
      if (_activeSessionKey != owningSessionKey) return null;
      state = state.copyWith(
        stage: VideoSummaryStage.ready,
        errorMessage: '获取草稿失败，请重试',
      );
    }
  }

  /// 重新订阅 WS 实时进度流（用于切回 processing 阶段会话时恢复监听）。
  /// 同时启动并行轮询，作为 WS 静默失效的兜底。
  Future<void> _resumeDraftGeneration(
    String taskId,
    Object owningSessionKey,
  ) async {
    if (kDebugMode) {
      debugPrint('[FlowCtrl] 开始恢复 WS 监听 — taskId=$taskId');
    }

    // 确保 taskId 已同步到 state，否则后续 captureSnapshot() 拿不到
    if (state.taskId != taskId) {
      state = state.copyWith(taskId: taskId);
    }

    // 立即启动并行轮询，作为 WS 静默失效的兜底（10s 间隔）
    _startProcessingPoll(taskId, owningSessionKey, intervalSeconds: 10);

    try {
      await for (final processingData in _repository.resumeTaskProgress(
        taskId,
      )) {
        if (_activeSessionKey != owningSessionKey) {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] 恢复 WS 流中止 — 会话已切换');
          }
          _cancelProcessingPoll();
          return;
        }
        state = state.copyWith(
          processingSnapshot: mapProcessingDataToSnapshot(processingData),
        );
      }

      // WS 流正常结束（收到 completed），停止轮询
      _cancelProcessingPoll();
      if (_activeSessionKey != owningSessionKey) return null;

      // 如果轮询已经过渡了阶段，跳过重复操作
      if (state.stage != VideoSummaryStage.processing) return;

      _repository.updateTaskId(taskId);
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());

      if (_activeSessionKey != owningSessionKey) return null;

      state = state.copyWith(
        draftResult: draft,
        stage: VideoSummaryStage.draft,
        processingExpanded: false,
        isDraftEditMode: false,
      );

      if (kDebugMode) {
        debugPrint('[FlowCtrl] 恢复的 WS 任务已完成，已跳转到草稿页 — taskId=$taskId');
      }
    } catch (e) {
      if (_activeSessionKey != owningSessionKey) {
        _cancelProcessingPoll();
        return;
      }
      debugPrint('[FlowCtrl] 恢复 WS 监听失败，轮询兜底中 — taskId=$taskId: $e');
      // 轮询已在运行，无需额外操作
    }
  }

  /// 启动轮询，定期检查后端任务状态，直到完成或失败。
  /// 作为 WS 实时监听的兜底方案。
  /// [intervalSeconds] 控制轮询间隔，默认 5 秒；并行运行时建议设为 10 秒。
  void _startProcessingPoll(
    String taskId,
    Object owningSessionKey, {
    int intervalSeconds = 5,
  }) {
    _cancelProcessingPoll();

    void poll() async {
      // 轮询期间会话可能已切换
      if (_activeSessionKey != owningSessionKey) {
        _cancelProcessingPoll();
        return;
      }

      try {
        final taskInfo = await _repository.getTaskStatus(taskId);
        if (taskInfo == null || _activeSessionKey != owningSessionKey) {
          _cancelProcessingPoll();
          return;
        }

        switch (taskInfo.workflowState) {
          case WorkflowState.waitingUserApproval:
          case WorkflowState.completed:
            _cancelProcessingPoll();
            await _transitionToDraftFromBackend(taskId, owningSessionKey);
            break;

          case WorkflowState.failed:
            _cancelProcessingPoll();
            if (_activeSessionKey != owningSessionKey) return null;
            state = state.copyWith(
              stage: VideoSummaryStage.ready,
              errorMessage: '视频处理失败，请重试',
            );
            break;

          case WorkflowState.draftGenerating:
          case WorkflowState.finalGenerating:
            // 仍在运行，继续轮询
            if (_activeSessionKey == owningSessionKey) {
              _processingPollTimer = Timer(
                Duration(seconds: intervalSeconds),
                poll,
              );
            }
            break;
        }
      } catch (e) {
        debugPrint('[FlowCtrl] 轮询任务状态失败 — taskId=$taskId: $e');
        // 出错后仍然继续轮询
        if (_activeSessionKey == owningSessionKey) {
          _processingPollTimer = Timer(
            Duration(seconds: intervalSeconds),
            poll,
          );
        }
      }
    }

    debugPrint('[FlowCtrl] 开始轮询后台任务进度 — taskId=$taskId');
    _processingPollTimer = Timer(Duration(seconds: intervalSeconds), poll);
  }

  /// 轮询 draft 阶段的后端任务状态，用于等待终稿生成完成（Phase 2）。
  /// 作为 `_resumeFinalGeneration` WS 监听的兜底。
  void _startDraftStatusPoll(String taskId, Object owningSessionKey) {
    _cancelDraftStatusPoll();

    void poll() async {
      if (_activeSessionKey != owningSessionKey) {
        _cancelDraftStatusPoll();
        return;
      }

      try {
        final taskInfo = await _repository.getTaskStatus(taskId);
        if (taskInfo == null || _activeSessionKey != owningSessionKey) {
          _cancelDraftStatusPoll();
          return;
        }

        switch (taskInfo.workflowState) {
          case WorkflowState.completed:
            _cancelDraftStatusPoll();
            await _transitionToFinalChatFromBackend(taskId, owningSessionKey);
            break;

          case WorkflowState.failed:
            _cancelDraftStatusPoll();
            if (_activeSessionKey != owningSessionKey) return null;
            state = state.copyWith(errorMessage: '终稿生成失败，请重试');
            break;

          case WorkflowState.draftGenerating:
            // 异常回退：draft 阶段不应该出现 Phase 1 状态，但做防御处理
            _cancelDraftStatusPoll();
            _startProcessingPoll(taskId, owningSessionKey);
            break;

          case WorkflowState.waitingUserApproval:
          case WorkflowState.finalGenerating:
            // 仍在等待或生成中，继续轮询
            if (_activeSessionKey == owningSessionKey) {
              _draftPollTimer = Timer(const Duration(seconds: 10), poll);
            }
            break;
        }
      } catch (e) {
        debugPrint('[FlowCtrl] 终稿状态轮询失败 — taskId=$taskId: $e');
        if (_activeSessionKey == owningSessionKey) {
          _draftPollTimer = Timer(const Duration(seconds: 10), poll);
        }
      }
    }

    debugPrint('[FlowCtrl] 开始终稿状态轮询 — taskId=$taskId');
    _draftPollTimer = Timer(const Duration(seconds: 10), poll);
  }

  /// 构建模拟进度模式下的 eta 标签。
  ///
  /// 在预处理阶段（未收到真实分片事件）显示阶段提示；
  /// 收到分片事件后显示 "分片 X/Y 完成 (模拟 XX%)"。
  String _buildSimulatedEtaLabel(
    VideoSummaryProcessingData data,
    int simulatedPercent,
  ) {
    final cp = data.chunkProgress;
    if (cp == null || !_simProgressEstimator.hasReceivedRealProgress) {
      return data.currentMessage.isNotEmpty
          ? data.currentMessage
          : '正在准备处理内容。';
    }
    return '分片 ${cp.doneCount}/${cp.totalChunks} 完成';
  }

  TimestampRangeSelection _buildDefaultTimestampRange(String durationLabel) {
    final total = parseVideoSummaryDurationLabel(
      label: durationLabel,
      minimumSeconds: minimumTimestampRangeSeconds,
    );
    final defaultLength = total >= 60 ? 60 : total;
    final safeLength = defaultLength >= minimumTimestampRangeSeconds
        ? defaultLength
        : minimumTimestampRangeSeconds;
    final end = safeLength.clamp(minimumTimestampRangeSeconds, total);
    return TimestampRangeSelection(startSeconds: 0, endSeconds: end);
  }

  TimestampRangeSelection _buildRangeFromSummary(FinalSummaryData summary) {
    final seeded = summary.timestampChips.isNotEmpty
        ? tryParseVideoSummaryTimestampRange(
            raw: summary.timestampChips.first.label,
            minimumSeconds: minimumTimestampRangeSeconds,
          )
        : null;
    return _sanitizeTimestampRange(
      seeded ?? _buildDefaultTimestampRange(state.videoAsset.durationLabel),
    );
  }

  // 所有进入 state 的时间范围都要过一次收口，避免 UI 或 demo 数据带来非法区间。
  TimestampRangeSelection _sanitizeTimestampRange(
    TimestampRangeSelection range,
  ) {
    final total = videoDurationInSeconds;
    final maxStart = (total - minimumTimestampRangeSeconds).clamp(0, total);
    final start = range.startSeconds.clamp(0, maxStart);
    final minEnd = (start + minimumTimestampRangeSeconds).clamp(
      minimumTimestampRangeSeconds,
      total,
    );
    final end = range.endSeconds.clamp(minEnd, total);
    return TimestampRangeSelection(startSeconds: start, endSeconds: end);
  }
}
