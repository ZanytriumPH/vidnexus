import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../services/service_providers.dart';
import '../../../services/upload_service.dart';
import '../../../services/models/common_dto.dart';
import 'video_summary_result_mapper.dart';
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
    _repository.updateTaskId(null);
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
    );
  }

  Future<void> pickAndUploadVideo() async {
    if (state.isUploading || state.isGenerating) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final fileSize = result.files.single.size;

      state = state.copyWith(
        isUploading: true,
        uploadProgress: 0.0,
      );

      final uploadService = ref.read(uploadServiceProvider);

      // 1. 初始化上传
      final initResp = await uploadService.initUpload(
        fileName: fileName,
        totalSize: fileSize,
      );
      final uploadId = initResp.uploadId;
      if (uploadId.isEmpty) {
        throw Exception('Failed to initialize upload: empty upload_id');
      }

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
          state = state.copyWith(
            uploadProgress: offset / fileSize,
          );
        }
      } finally {
        await raf.close();
      }

      // 3. 注册视频资源
      final createVideoResp = await ref.read(videoServiceProvider).createVideo(
        fileName: fileName,
      );
      final newVideoId = createVideoResp.data?.videoId ?? fileName;
      final createdDuration = createVideoResp.data?.duration;

      // 4. 更新 repository 和 provider 中的 videoId
      _repository.updateVideoId(newVideoId);
      ref.read(currentVideoIdProvider.notifier).state = newVideoId;

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

  /// 轮询等待视频转写和关键帧抽取完成。
  ///
  /// 就绪条件与后端 createTask 的校验对齐：
  ///   extract_completed_at IS NOT NULL
  ///   AND transcribe_status = 'COMPLETED'
  ///   AND frame_extraction_status = 'COMPLETED'
  ///
  /// 最多等待 20 秒；超时后不阻塞流程，交由后端 422 返回明确错误。
  Future<void> _waitForVideoReady() async {
    const maxAttempts = 10; // 10 × 2s = 20s
    const pollInterval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final videoService = ref.read(videoServiceProvider);
        final resp = await videoService.getVideo(_repository.videoId);
        final data = resp.data;
        if (data != null &&
            data.extractCompletedAt != null &&
            data.transcribeStatus == 'COMPLETED' &&
            data.frameExtractionStatus == 'COMPLETED') {
          if (kDebugMode) {
            debugPrint('[FlowCtrl] 视频已就绪 — videoId=${_repository.videoId}');
          }
          // 用后端返回的真实视频时长更新本地状态
          _updateVideoDuration(data.duration);
          return;
        }
      } catch (e) {
        debugPrint('[FlowCtrl] _waitForVideoReady poll attempt ${i + 1}/$maxAttempts failed: $e');
      }
      await Future.delayed(pollInterval);
    }
    // 超时后不抛异常，交由后端 createTask 接口返回 422 明确错误
    debugPrint(
      '[FlowCtrl] 视频未在 ${maxAttempts * pollInterval.inSeconds}s 内就绪，'
      '继续流程，由后端校验',
    );
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

    try {
      // 确保 kbid 已解析（等待 defaultKbidProvider 完成）
      await _ensureKbidResolved();

      // 等待视频处理完成（转写 + 关键帧抽取），否则后端返回 422
      await _waitForVideoReady();

      await for (final processingData in _repository.startDraftGeneration(
        userInitialPreference: (userInitialPreference != null && userInitialPreference.isNotEmpty)
            ? userInitialPreference
            : null,
      )) {
        state = state.copyWith(
          processingSnapshot: mapProcessingDataToSnapshot(processingData),
        );
      }

      // repository 返回的是 raw draft data，进入页面前统一转换成 presentation model。
      final draft = mapDraftDataToResult(await _repository.fetchDraftResult());
      state = state.copyWith(
        draftResult: draft,
        stage: VideoSummaryStage.draft,
        processingExpanded: false,
        isDraftEditMode: false,
      );
    } catch (e) {
      debugPrint('[FlowCtrl] Start draft generation failed: $e');
      // 发生错误时将阶段重置回 ready，使用户可以重新尝试
      state = state.copyWith(
        stage: VideoSummaryStage.ready,
      );
    } finally {
      state = state.copyWith(isGenerating: false);
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

    // 最终稿生成基于“当前可编辑文本框中的内容”，而不是仅基于最初草稿结果。
    final editedParagraphs = draftBodyText
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final effectiveDraft = DraftResult(
      paragraphs: editedParagraphs.isEmpty ? draft.paragraphs : editedParagraphs,
      suggestionHint: draft.suggestionHint,
    );

    state = state.copyWith(isGenerating: true);

    try {
      final summary = await _repository.generateFinalSummary(
        guidance: guidance,
        draftParagraphs: effectiveDraft.paragraphs,
      );
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
      state = state.copyWith(isGenerating: false);
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
      state = state.copyWith(isSendingChat: false);
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
  }

  /// 从后端获取视频真实时长并更新本地状态（用于快照恢复场景）。
  Future<void> _refreshVideoDurationFromBackend() async {
    try {
      final videoService = ref.read(videoServiceProvider);
      final resp = await videoService.getVideo(_repository.videoId);
      final data = resp.data;
      if (data == null) return;

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

      if (messages.isNotEmpty) {
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