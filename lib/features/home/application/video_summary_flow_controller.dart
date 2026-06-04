import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../services/service_providers.dart';
import '../../../services/upload_service.dart';
import '../../../services/models/common_dto.dart';
import 'video_summary_result_mapper.dart';
import '../domain/video_summary_domain_models.dart';
import '../domain/video_summary_time_utils.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import '../video_summary_repository.dart';
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
  final String? errorMessage;

  factory VideoSummaryFlowState.initial({required VideoAssetInfo videoAsset, String? taskId}) {
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
      errorMessage: clearError
          ? null
          : (errorMessage == _unset ? this.errorMessage : errorMessage as String?),
    );
  }
}

/// 用于 session 恢复的轻量快照，和实时 state 分开，避免把运行时控制字段直接序列化思维化。
class VideoSummaryFlowSnapshot {
  const VideoSummaryFlowSnapshot({
    this.taskId,
    this.videoAsset,
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
  });

  final String? taskId;
  final VideoAssetInfo? videoAsset;
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
}

/// 视频总结主状态机，负责把 ready -> processing -> draft -> finalChat 串起来。
class VideoSummaryFlowController extends Notifier<VideoSummaryFlowState> {
  static const int minimumTimestampRangeSeconds = 10;

  VideoSummaryRepository get _repository => ref.read(videoSummaryRepositoryProvider);

  /// 当前活跃会话的唯一标识。每次 reset() / restoreSnapshot() 都会重新生成。
  /// 异步生成流程用捕获的局部变量与此比对，防止旧结果污染新会话的状态。
  Object _activeSessionKey = Object();

  /// 处理中阶段的轮询定时器，用于会话恢复后等待后台任务完成。
  Timer? _processingPollTimer;

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

  int get videoDurationInSeconds =>
      parseVideoSummaryDurationLabel(
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
    _cancelProcessingPoll();

    _repository.updateTaskId(null);
    _repository.updateVideoId(defaultVideoId);
    ref.read(currentVideoIdProvider.notifier).state = defaultVideoId;
    final settings = ref.read(videoSummarySettingsProvider);
    final defaultRange = _buildDefaultTimestampRange(state.videoAsset.durationLabel);
    state = state.copyWith(
      taskId: null,
      uploadHighlighted: false,
      processingExpanded: settings.defaultProcessingExpanded,
      isDraftEditMode: false,
      isGenerating: false,
      isSendingChat: false,
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

  Future<void> pickAndUploadVideo() async {
    if (state.isUploading || state.isGenerating) {
      return;
    }

    final owningSessionKey = _activeSessionKey;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      // 文件选择器是模态弹窗，期间用户可能通过其他方式切换了会话
      if (_activeSessionKey != owningSessionKey) return;

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final fileSize = result.files.single.size;

      // 1. 预先注册视频资源记录（必须先于 TUS 上传）。
      //    后端 Celery async_finalize_upload 通过 (owner_id + file_name + oss_key 为空)
      //    查找预注册记录来关联上传文件和视频资源。如果 TUS 上传先完成而 createVideo
      //    尚未调用，Celery 会匹配到旧的同名 stale record 或创建全新记录，导致前后端
      //    videoId 不一致，后续 createTask 时后端返回 422 video_not_ready。
      final createVideoResp = await ref.read(videoServiceProvider).createVideo(
        fileName: fileName,
      );
      if (_activeSessionKey != owningSessionKey) return;

      final newVideoId = createVideoResp.data?.videoId ?? fileName;
      final createdDuration = createVideoResp.data?.duration;

      // 2. 立即同步 videoId 到 repository 和 provider
      _repository.updateVideoId(newVideoId);
      ref.read(currentVideoIdProvider.notifier).state = newVideoId;

      state = state.copyWith(
        isUploading: true,
        uploadProgress: 0.0,
      );

      final uploadService = ref.read(uploadServiceProvider);

      // 3. 初始化 TUS 上传
      final initResp = await uploadService.initUpload(
        fileName: fileName,
        totalSize: fileSize,
      );
      if (_activeSessionKey != owningSessionKey) return;

      final uploadId = initResp.uploadId;
      if (uploadId.isEmpty) {
        throw Exception('Failed to initialize upload: empty upload_id');
      }

      // 4. 分片上传 (每片 10 MiB)
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
          // 分片上传期间会话切换：停止更新进度，但继续完成上传（后端已接收的数据不浪费）
          if (_activeSessionKey == owningSessionKey) {
            state = state.copyWith(
              uploadProgress: offset / fileSize,
            );
          }
        }
      } finally {
        await raf.close();
      }

      // 上传已完成，但会话已切换：不更新当前会话的 state
      if (_activeSessionKey != owningSessionKey) {
        debugPrint('[FlowCtrl] 上传完成但会话已切换，跳过状态更新');
        return;
      }

      // 5. 更新本地状态中的视频资产信息
      final durationLabel = createdDuration != null && createdDuration > 0
          ? _formatDurationLabel(createdDuration)
          : '0m 00s';
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        uploadHighlighted: true,
        videoAsset: VideoAssetInfo(
          title: newVideoId,
          durationLabel: durationLabel,
          sourceLabel: state.videoAsset.sourceLabel,
          fileName: fileName,
        ),
      );
    } catch (e) {
      // 错误只展示给发起上传的会话
      if (_activeSessionKey != owningSessionKey) return;
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
      );
      debugPrint('Upload failed: $e');
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
      debugPrint('[FlowCtrl] defaultKbidProvider resolved with error: $e, invalidating and retrying...');
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
      );
      final defaultRange = _buildDefaultTimestampRange(newLabel);
      state = state.copyWith(
        videoAsset: updatedAsset,
        selectedTimestampStartSeconds: defaultRange.startSeconds,
        selectedTimestampEndSeconds: defaultRange.endSeconds,
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

  Future<void> startDraftGeneration({String? userInitialPreference}) async {
    if (state.isGenerating) {
      return;
    }

    final settings = ref.read(videoSummarySettingsProvider);

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

    // 捕获当前会话标识，后续所有异步回调都以此校验所有权。
    // 使用局部变量 + Object 引用比对，reset()/restoreSnapshot() 会创建新 Object，
    // 使旧异步流程的引用自动失效，不受 state.taskId 可能为 null 的影响。
    final owningSessionKey = _activeSessionKey;

    try {
      // 确保 kbid 已解析（等待 defaultKbidProvider 完成）
      await _ensureKbidResolved();

      await for (final processingData in _repository.startDraftGeneration(
        userInitialPreference: (userInitialPreference != null && userInitialPreference.isNotEmpty)
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

        // 首帧到达时 task 已创建完毕，同步 taskId 到 state，
        // 确保后续 captureSnapshot() 能拿到正确的 taskId
        if (state.taskId == null && _repository.activeTaskId != null) {
          state = state.copyWith(taskId: _repository.activeTaskId);
        }
        state = state.copyWith(
          processingSnapshot: mapProcessingDataToSnapshot(processingData),
        );
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
      final errorMsg = (e is DioException)
          ? ApiError.fromDioException(e).userMessage
          : '生成草稿失败，请稍后重试';
      state = state.copyWith(
        stage: VideoSummaryStage.ready,
        errorMessage: errorMsg,
      );
    } finally {
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
      paragraphs: editedParagraphs.isEmpty ? draft.paragraphs : editedParagraphs,
      suggestionHint: draft.suggestionHint,
    );

    final owningSessionKey = _activeSessionKey;
    state = state.copyWith(isGenerating: true);

    try {
      final summary = await _repository.generateFinalSummary(
        guidance: guidance,
        draftParagraphs: effectiveDraft.paragraphs,
      );
      // 异步等待期间可能发生会话切换
      if (_activeSessionKey != owningSessionKey) return;

      final summaryData = mapFinalResultDataToSummary(summary);
      // 进入 finalChat 时，会用总结中的首个时间片段给时间旅行功能提供默认范围。
      final seededRange = _buildRangeFromSummary(summaryData);
      state = state.copyWith(
        finalSummaryData: summaryData,
        chatMessages: List<ChatMessage>.from(summaryData.messages),
        draftResult: effectiveDraft,
        stage: VideoSummaryStage.finalChat,
        selectedTimestampStartSeconds: seededRange.startSeconds,
        selectedTimestampEndSeconds: seededRange.endSeconds,
      );
    } finally {
      if (_activeSessionKey == owningSessionKey) {
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

  Future<void> sendChatMessage(String rawMessage) async {
    final message = rawMessage.trim();
    if (state.isSendingChat || message.isEmpty) {
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
        ? (state.selectedTimestampEndSeconds - state.selectedTimestampStartSeconds)
        : null;

    try {
      final sseStream = _repository.sendSummaryChatMessage(
        message,
        timestamp: timestamp,
        windowSeconds: windowSeconds,
      );

      await for (final reply in sseStream) {
        // 若在 SSE 流期间发生了会话切换，则停止消费
        if (_activeSessionKey != owningSessionKey) {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] 聊天 SSE 流中止 — 会话已切换');
          }
          return;
        }
        final currentMessages = List<ChatMessage>.from(state.chatMessages);
        if (currentMessages.isNotEmpty) {
          final lastMsg = currentMessages.last;
          currentMessages[currentMessages.length - 1] = ChatMessage(
            sender: lastMsg.sender,
            text: reply.text,
            timestampLabel: lastMsg.timestampLabel,
          );
          state = state.copyWith(chatMessages: currentMessages);
        }
      }
    } catch (e) {
      // 错误只展示给发起消息的会话
      if (_activeSessionKey != owningSessionKey) return;
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
    );
  }

  void restoreSnapshot(VideoSummaryFlowSnapshot snapshot) {
    // 切换会话标识，使所有正在执行的旧异步生成流程的守卫失效
    _activeSessionKey = Object();
    _cancelProcessingPoll();

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
    );

    // 同步 repository 和 provider 的 videoId（从快照的 videoAsset.title 中获取）
    if (videoAsset.title.isNotEmpty &&
        videoAsset.title != 'vid_default') {
      _repository.updateVideoId(videoAsset.title);
      ref.read(currentVideoIdProvider.notifier).state = videoAsset.title;
    }

    // 同步 repository 的 taskId，否则后续追问会报 "No active task"
    if (snapshot.taskId != null && snapshot.taskId!.isNotEmpty) {
      _repository.updateTaskId(snapshot.taskId);
    }

    // 旧快照的 durationLabel 可能是占位值，异步从后端刷新真实时长
    if (state.videoAsset.durationLabel == '0m 00s' ||
        state.videoAsset.durationLabel == '--:--') {
      _refreshVideoDurationFromBackend();
    }

    // 历史会话的 chatMessages 未持久化到快照，从后端 QA 记录异步回填
    if (snapshot.stage == VideoSummaryStage.finalChat &&
        snapshot.taskId != null &&
        snapshot.taskId!.isNotEmpty) {
      _refreshChatMessagesFromBackend(snapshot.taskId!);
    }

    // 恢复 processing 阶段的会话时，查询后端确认任务的实际进度。
    // 防止出现"任务已在后台完成但快照仍停在 processing"的卡死问题。
    if (snapshot.stage == VideoSummaryStage.processing &&
        snapshot.taskId != null &&
        snapshot.taskId!.isNotEmpty) {
      _recoverProcessingFromBackend(snapshot.taskId!);
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
        // 构建时间标签
        String? timestampLabel;
        if (qa.startTime != null && qa.startTime!.isNotEmpty) {
          timestampLabel = qa.startTime!;
          if (qa.endTime != null && qa.endTime!.isNotEmpty) {
            timestampLabel = '$timestampLabel - ${qa.endTime}';
          }
        }

        // 用户问题
        if (qa.questionContent.isNotEmpty) {
          messages.add(ChatMessage(
            sender: SummaryChatSender.user,
            text: qa.questionContent,
            timestampLabel: timestampLabel,
          ));
        }

        // 系统回答
        if (qa.answerContent != null && qa.answerContent!.isNotEmpty) {
          messages.add(ChatMessage(
            sender: SummaryChatSender.system,
            text: qa.answerContent!,
            timestampLabel: timestampLabel,
          ));
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

  /// 取消处理中阶段的轮询定时器。
  void _cancelProcessingPoll() {
    _processingPollTimer?.cancel();
    _processingPollTimer = null;
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
      if (_activeSessionKey != owningSessionKey) return;

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
          if (_activeSessionKey != owningSessionKey) return;
          state = state.copyWith(
            stage: VideoSummaryStage.ready,
            errorMessage: '视频处理失败，请重试',
          );
          break;

        case WorkflowState.draftGenerating:
        case WorkflowState.finalGenerating:
          // 任务仍在后端运行，重新订阅 WS 实时进度
          _resumeDraftGeneration(taskId, owningSessionKey);
          break;
      }
    } catch (e) {
      debugPrint('[FlowCtrl] 恢复处理中会话异常 — taskId=$taskId: $e');
    }
  }

  /// 从后端获取草稿结果并跳转到 draft 阶段。
  Future<void> _transitionToDraftFromBackend(String taskId, Object owningSessionKey) async {
    try {
      // 先确保 repository 的 taskId 指向正确任务
      _repository.updateTaskId(taskId);
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());

      // 校验：获取期间用户可能又切走了
      if (_activeSessionKey != owningSessionKey) return;

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
      if (_activeSessionKey != owningSessionKey) return;
      state = state.copyWith(
        stage: VideoSummaryStage.ready,
        errorMessage: '获取草稿失败，请重试',
      );
    }
  }

  /// 重新订阅 WS 实时进度流（用于切回 processing 阶段会话时恢复监听）。
  Future<void> _resumeDraftGeneration(String taskId, Object owningSessionKey) async {
    if (kDebugMode) {
      debugPrint('[FlowCtrl] 开始恢复 WS 监听 — taskId=$taskId');
    }

    // 确保 taskId 已同步到 state，否则后续 captureSnapshot() 拿不到
    if (state.taskId != taskId) {
      state = state.copyWith(taskId: taskId);
    }

    try {
      await for (final processingData in _repository.resumeTaskProgress(taskId)) {
        if (_activeSessionKey != owningSessionKey) {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] 恢复 WS 流中止 — 会话已切换');
          }
          return;
        }
        state = state.copyWith(
          processingSnapshot: mapProcessingDataToSnapshot(processingData),
        );
      }

      // WS 流正常结束（收到 completed），获取草稿并跳转
      if (_activeSessionKey != owningSessionKey) return;

      _repository.updateTaskId(taskId);
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());

      if (_activeSessionKey != owningSessionKey) return;

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
      if (_activeSessionKey != owningSessionKey) return;
      debugPrint('[FlowCtrl] 恢复 WS 监听失败 — taskId=$taskId: $e');
      // WS 恢复失败时回退到轮询
      _startProcessingPoll(taskId, owningSessionKey);
    }
  }

  /// 启动轮询，每 5 秒检查一次后端任务状态，直到完成或失败。
  /// 作为 WS 实时监听的兜底方案。
  void _startProcessingPoll(String taskId, Object owningSessionKey) {
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
            if (_activeSessionKey != owningSessionKey) return;
            state = state.copyWith(
              stage: VideoSummaryStage.ready,
              errorMessage: '视频处理失败，请重试',
            );
            break;

          case WorkflowState.draftGenerating:
          case WorkflowState.finalGenerating:
            // 仍在运行，继续轮询
            if (_activeSessionKey == owningSessionKey) {
              _processingPollTimer = Timer(const Duration(seconds: 5), poll);
            }
            break;
        }
      } catch (e) {
        debugPrint('[FlowCtrl] 轮询任务状态失败 — taskId=$taskId: $e');
        // 出错后仍然继续轮询（5 秒后重试）
        if (_activeSessionKey == owningSessionKey) {
          _processingPollTimer = Timer(const Duration(seconds: 5), poll);
        }
      }
    }

    debugPrint('[FlowCtrl] 开始轮询后台任务进度 — taskId=$taskId');
    _processingPollTimer = Timer(const Duration(seconds: 5), poll);
  }

  TimestampRangeSelection _buildDefaultTimestampRange(String durationLabel) {
    final total = parseVideoSummaryDurationLabel(
      label: durationLabel,
      minimumSeconds: minimumTimestampRangeSeconds,
    );
    final defaultLength = total >= 30 ? 30 : total;
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
    return _sanitizeTimestampRange(seeded ?? _buildDefaultTimestampRange(state.videoAsset.durationLabel));
  }

  // 所有进入 state 的时间范围都要过一次收口，避免 UI 或 demo 数据带来非法区间。
  TimestampRangeSelection _sanitizeTimestampRange(TimestampRangeSelection range) {
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