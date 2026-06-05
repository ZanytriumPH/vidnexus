import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/video_summary_domain_models.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';
import '../video_summary_repository.dart';
import 'video_summary_flow_controller.dart';

final videoSummarySessionHistoryProvider = NotifierProvider<
    VideoSummarySessionHistoryController, VideoSummarySessionHistoryState>(
  VideoSummarySessionHistoryController.new,
);

/// 管理历史会话列表，以及“当前页面状态如何保存/恢复”为一个可切换的 session。
class VideoSummarySessionHistoryState {
  const VideoSummarySessionHistoryState({
    required this.sessions,
    required this.activeSessionId,
    required this.createdSessionCount,
    this.isLoadingHistory = false,
    this.errorMessage,
  });

  final List<VideoSummarySessionHistoryEntry> sessions;
  final String activeSessionId;
  final int createdSessionCount;
  final bool isLoadingHistory;
  final String? errorMessage;

  VideoSummarySessionHistoryState copyWith({
    List<VideoSummarySessionHistoryEntry>? sessions,
    String? activeSessionId,
    int? createdSessionCount,
    bool? isLoadingHistory,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VideoSummarySessionHistoryState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      createdSessionCount: createdSessionCount ?? this.createdSessionCount,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VideoSummarySessionHistoryEntry {
  const VideoSummarySessionHistoryEntry({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.detail,
    required this.snapshot,
  });

  final String id;
  final String title;
  final String durationLabel;
  final String detail;
  final VideoSummarySessionSnapshot snapshot;

  VideoSummarySessionHistoryEntry copyWith({
    String? id,
    String? title,
    String? durationLabel,
    String? detail,
    VideoSummarySessionSnapshot? snapshot,
  }) {
    return VideoSummarySessionHistoryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      durationLabel: durationLabel ?? this.durationLabel,
      detail: detail ?? this.detail,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class VideoSummarySessionSnapshot {
  const VideoSummarySessionSnapshot({
    required this.flowSnapshot,
    required this.readyPreferenceText,
    required this.draftGuidanceText,
    required this.draftBodyText,
  });

  final VideoSummaryFlowSnapshot flowSnapshot;
  final String readyPreferenceText;
  final String draftGuidanceText;
  final String draftBodyText;
}

class VideoSummarySessionHistoryController
    extends Notifier<VideoSummarySessionHistoryState> {
  VideoSummaryRepository get _repository => ref.read(videoSummaryRepositoryProvider);

  @override
  VideoSummarySessionHistoryState build() {
    final videoAsset = _repository.getVideoAsset();
    final currentSession = _buildCurrentSessionEntry(videoAsset);

    // 先加载本地持久化会话，再异步加载后端任务列表
    _loadAll();

    return VideoSummarySessionHistoryState(
      sessions: [currentSession],
      activeSessionId: currentSession.id,
      createdSessionCount: 1,
      isLoadingHistory: true,
    );
  }

  /// 依次加载本地持久化会话和后端任务列表，合并到侧边栏。
  Future<void> _loadAll() async {
    // 1. 先同步加载本地会话（无后端任务的视频上传会话）
    final localSessions = await _loadLocalSessions();
    if (localSessions.isNotEmpty) {
      final currentSession = state.sessions.first;
      state = state.copyWith(
        sessions: [currentSession, ...localSessions],
        createdSessionCount: 1 + localSessions.length,
      );
    }

    // 2. 再加载后端任务（会去除重复的本地条目）
    await _loadFromBackend();
  }

  VideoSummarySessionHistoryEntry _buildCurrentSessionEntry(
    VideoAssetInfo videoAsset,
  ) {
    return VideoSummarySessionHistoryEntry(
      id: 'session-current',
      title: '当前视频会话',
      durationLabel: videoAsset.durationLabel,
      detail: '当前会话仍在主区域，可以继续生成或追问。',
      snapshot: VideoSummarySessionSnapshot(
        flowSnapshot:
            ref.read(videoSummaryFlowControllerProvider.notifier).captureSnapshot(),
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: '',
      ),
    );
  }

  /// 从后端 GET /api/v1/tasks 加载历史任务并合并到侧边栏列表。
  /// 加载完成后清理与后端任务 videoId 重复的本地持久化条目。
  Future<void> _loadFromBackend() async {
    try {
      final tasks = await _repository.listTaskHistory();

      final currentSession = state.sessions.firstWhere(
        (s) => s.id == 'session-current',
        orElse: () => state.sessions.first,
      );
      final historyEntries = tasks.map(_mapTaskToEntry).toList();

      // 收集后端任务的 videoId 集合，用于去重本地会话
      final backendVideoIds = historyEntries
          .map((e) => e.snapshot.flowSnapshot.videoAsset?.title)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      // 保留 session-current + 不与后端重复的本地会话 + 后端任务条目
      final existingLocal = state.sessions.where((s) {
        if (s.id == 'session-current') return false; // 由 currentSession 替代
        final hasTaskId = s.snapshot.flowSnapshot.taskId != null &&
            s.snapshot.flowSnapshot.taskId!.isNotEmpty;
        if (hasTaskId) return false; // 已有 taskId 的由后端条目替代
        final localVideoId = s.snapshot.flowSnapshot.videoAsset?.title;
        if (localVideoId != null &&
            localVideoId.isNotEmpty &&
            backendVideoIds.contains(localVideoId)) {
          return false; // 与后端条目 videoId 重复，去除
        }
        return true;
      }).toList();

      final merged = [currentSession, ...existingLocal, ...historyEntries];
      state = state.copyWith(
        sessions: merged,
        createdSessionCount: 1 + existingLocal.length + historyEntries.length,
        isLoadingHistory: false,
        clearError: true,
      );

      // 清理 JSON 文件中已被后端覆盖的冗余条目
      await _pruneLocalSessions(backendVideoIds);
    } catch (e, stackTrace) {
      debugPrint(
        '[SessionHistory] 加载历史会话失败: $e\n$stackTrace',
      );
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: '历史会话加载失败，请点击重试',
      );
    }
  }

  /// 重试加载历史会话列表。
  void retryLoadHistory() {
    if (state.isLoadingHistory) return;
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    _loadFromBackend();
  }

  /// 将后端 [VideoSummaryTaskInfo] 映射为侧边栏展示条目。
  VideoSummarySessionHistoryEntry _mapTaskToEntry(VideoSummaryTaskInfo task) {
    final stage = _stageFromWorkflowState(task.workflowState);
    final paragraphs = _splitParagraphs(task.draftSummary);

    return VideoSummarySessionHistoryEntry(
      id: task.taskId,
      title: task.title ?? '未命名会话',
      durationLabel: '--:--',
      detail: task.workflowState.label,
      snapshot: VideoSummarySessionSnapshot(
        flowSnapshot: VideoSummaryFlowSnapshot(
          taskId: task.taskId,
          videoAsset: VideoAssetInfo(
            title: task.videoId,
            durationLabel: '0m 00s',
            sourceLabel: task.kbid,
            fileName: '',
          ),
          stage: stage,
          uploadHighlighted: stage != VideoSummaryStage.ready,
          processingExpanded: stage == VideoSummaryStage.processing,
          isTimestampScoped: false,
          selectedTimestampStartSeconds: 0,
          selectedTimestampEndSeconds:
              VideoSummaryFlowController.minimumTimestampRangeSeconds,
          isDraftEditMode: false,
          processingSnapshot: null,
          draftResult: (stage == VideoSummaryStage.draft ||
                  stage == VideoSummaryStage.finalChat)
              ? DraftResult(paragraphs: paragraphs, suggestionHint: '')
              : null,
          finalSummaryData: stage == VideoSummaryStage.finalChat
              ? FinalSummaryData(
                  summaryTitle: task.title ?? '',
                  summaryBody: task.finalSummary ?? '',
                  timestampChips: const [],
                  messages: const [],
                )
              : null,
          chatMessages: const [],
        ),
        readyPreferenceText: task.userInitialPreference ?? '',
        draftGuidanceText: '',
        draftBodyText: task.draftSummary ?? '',
      ),
    );
  }

  /// WorkflowState → VideoSummaryStage 映射。
  VideoSummaryStage _stageFromWorkflowState(WorkflowState state) {
    return switch (state) {
      WorkflowState.draftGenerating => VideoSummaryStage.processing,
      WorkflowState.waitingUserApproval => VideoSummaryStage.draft,
      // finalGenerating 时初稿已生成、终稿正在生成，映射为 draft 而非 processing。
      // 原因：若映射为 processing，切回时会走 _recoverProcessingFromBackend →
      // _resumeDraftGeneration → resumeTaskProgress，其竞态窗口守护只检查
      // draftSummary 是否存在（Phase 1 完成后必然存在），导致误判为已完成而跳过
      // Phase 2 WS 订阅，前端再也收不到终稿完成的 WS completed 事件。
      WorkflowState.finalGenerating => VideoSummaryStage.draft,
      WorkflowState.completed => VideoSummaryStage.finalChat,
      WorkflowState.failed => VideoSummaryStage.ready,
    };
  }

  /// 将摘要文本按空行拆分为段落列表。
  List<String> _splitParagraphs(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  VideoSummarySessionHistoryEntry? getSessionById(String sessionId) {
    for (final session in state.sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  void createNewSession(VideoSummarySessionSnapshot snapshot) {
    final nextCount = state.createdSessionCount + 1;
    final session = VideoSummarySessionHistoryEntry(
      id: 'session-$nextCount',
      title: '视频总结会话 ${nextCount.toString().padLeft(2, '0')}',
      durationLabel: _repository.getVideoAsset().durationLabel,
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );

    state = state.copyWith(
      createdSessionCount: nextCount,
      activeSessionId: session.id,
      sessions: [session, ...state.sessions],
    );

    // 无后端任务的本地会话需要持久化到 JSON 文件
    _saveLocalSessions();
  }

  void activateSession(String sessionId) {
    if (state.activeSessionId == sessionId) {
      return;
    }
    state = state.copyWith(activeSessionId: sessionId);
  }

  void syncActiveSession(VideoSummarySessionSnapshot snapshot) {
    final index = state.sessions.indexWhere(
      (item) => item.id == state.activeSessionId,
    );
    if (index == -1) {
      return;
    }

    final current = state.sessions[index];
    final updated = current.copyWith(
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );
    final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
      ..[index] = updated;
    state = state.copyWith(sessions: sessions);

    // 若同步的是本地会话（无 taskId），将更新落盘
    _saveLocalSessions();
  }

  // 抽屉里展示的说明文案由当前阶段推导出来，而不是额外保存一份平行状态。
  String _detailForSnapshot(VideoSummarySessionSnapshot snapshot) {
    return switch (snapshot.flowSnapshot.stage) {
      VideoSummaryStage.ready => '已上传视频，可继续生成总结。',
      VideoSummaryStage.processing => '处理中断点已保存，下次可直接恢复',
      VideoSummaryStage.draft => '已生成摘要，等待人工审阅',
      VideoSummaryStage.finalChat => '已完成总结，可继续时间旅行追问',
    };
  }

  /// 上传视频后（Celery 处理完成），将当前会话持久化到本地 JSON 文件。
  /// 只有尚未创建后端任务的会话需要本地持久化；已有 taskId 的会话由后端
  /// listTaskHistory 负责恢复。
  void persistUploadSession(VideoSummarySessionSnapshot snapshot) {
    final flowSnapshot = snapshot.flowSnapshot;
    final videoId = flowSnapshot.videoAsset?.title ?? '';
    if (videoId.isEmpty || videoId == 'vid_default') return;

    final entryId = 'local-$videoId';

    // 若已存在同一 videoId 的本地条目，更新而非新建
    final existingIndex = state.sessions.indexWhere((s) => s.id == entryId);
    final entry = VideoSummarySessionHistoryEntry(
      id: entryId,
      title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
      durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );

    List<VideoSummarySessionHistoryEntry> sessions;
    int nextCount;
    if (existingIndex != -1) {
      sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions);
      sessions[existingIndex] = entry;
      nextCount = state.createdSessionCount;
    } else {
      nextCount = state.createdSessionCount + 1;
      // 插入到 current session 之后（index 0 之后）
      final current = state.sessions.first;
      sessions = [current, entry, ...state.sessions.skip(1)];
    }

    state = state.copyWith(
      sessions: sessions,
      createdSessionCount: nextCount,
    );

    _saveLocalSessions();
  }

  // ── 本地 JSON 文件持久化 ──────────────────────────────────────────

  static const String _localSessionsFileName = 'video_summary_local_sessions.json';

  Future<File> get _localSessionsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_localSessionsFileName');
  }

  /// 将所有无 taskId 的本地会话写入 JSON 文件。
  Future<void> _saveLocalSessions() async {
    try {
      final localOnly = state.sessions
          .where((s) =>
              s.id != 'session-current' &&
              (s.snapshot.flowSnapshot.taskId == null ||
                  s.snapshot.flowSnapshot.taskId!.isEmpty))
          .toList();
      final jsonList = localOnly.map(_sessionToJson).toList();
      final file = await _localSessionsFile;
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[SessionHistory] 保存本地会话失败: $e');
    }
  }

  /// 从 JSON 文件加载本地持久化的会话（仅无 taskId 的上传会话）。
  Future<List<VideoSummarySessionHistoryEntry>> _loadLocalSessions() async {
    try {
      final file = await _localSessionsFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList.map((j) => _sessionFromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[SessionHistory] 加载本地会话失败: $e');
      return [];
    }
  }

  /// 清理本地 JSON 文件中已被后端任务覆盖的条目。
  /// 当后端任务加载完成后调用，移除与后端任务 videoId 重复的本地会话。
  Future<void> _pruneLocalSessions(Set<String> backendVideoIds) async {
    try {
      final file = await _localSessionsFile;
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      final pruned = jsonList.where((j) {
        final videoTitle = (j as Map<String, dynamic>)['flowVideoTitle'] as String? ?? '';
        return !backendVideoIds.contains(videoTitle);
      }).toList();
      if (pruned.length != jsonList.length) {
        await file.writeAsString(jsonEncode(pruned));
      }
    } catch (e) {
      debugPrint('[SessionHistory] 清理本地会话失败: $e');
    }
  }

  // ── JSON 序列化 ──────────────────────────────────────────────────

  static Map<String, dynamic> _sessionToJson(VideoSummarySessionHistoryEntry entry) {
    final fs = entry.snapshot.flowSnapshot;
    return {
      'id': entry.id,
      'title': entry.title,
      'durationLabel': entry.durationLabel,
      'detail': entry.detail,
      'flowTaskId': fs.taskId,
      'flowVideoTitle': fs.videoAsset?.title ?? '',
      'flowDurationLabel': fs.videoAsset?.durationLabel ?? '0m 00s',
      'flowSourceLabel': fs.videoAsset?.sourceLabel ?? '',
      'flowFileName': fs.videoAsset?.fileName ?? '',
      'flowStage': fs.stage.name,
      'flowUploadHighlighted': fs.uploadHighlighted,
      'flowProcessingExpanded': fs.processingExpanded,
      'flowIsTimestampScoped': fs.isTimestampScoped,
      'flowSelectedTimestampStartSeconds': fs.selectedTimestampStartSeconds,
      'flowSelectedTimestampEndSeconds': fs.selectedTimestampEndSeconds,
      'flowIsDraftEditMode': fs.isDraftEditMode,
      'readyPreferenceText': entry.snapshot.readyPreferenceText,
      'draftGuidanceText': entry.snapshot.draftGuidanceText,
      'draftBodyText': entry.snapshot.draftBodyText,
    };
  }

  static VideoSummarySessionHistoryEntry _sessionFromJson(Map<String, dynamic> json) {
    final stageName = json['flowStage'] as String? ?? 'ready';
    final stage = VideoSummaryStage.values.firstWhere(
      (s) => s.name == stageName,
      orElse: () => VideoSummaryStage.ready,
    );

    return VideoSummarySessionHistoryEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      durationLabel: json['durationLabel'] as String? ?? '0m 00s',
      detail: json['detail'] as String? ?? '',
      snapshot: VideoSummarySessionSnapshot(
        flowSnapshot: VideoSummaryFlowSnapshot(
          taskId: json['flowTaskId'] as String?,
          videoAsset: VideoAssetInfo(
            title: json['flowVideoTitle'] as String? ?? '',
            durationLabel: json['flowDurationLabel'] as String? ?? '0m 00s',
            sourceLabel: json['flowSourceLabel'] as String? ?? '',
            fileName: json['flowFileName'] as String? ?? '',
          ),
          stage: stage,
          uploadHighlighted: json['flowUploadHighlighted'] as bool? ?? false,
          processingExpanded: json['flowProcessingExpanded'] as bool? ?? true,
          isTimestampScoped: json['flowIsTimestampScoped'] as bool? ?? false,
          selectedTimestampStartSeconds: json['flowSelectedTimestampStartSeconds'] as int? ?? 0,
          selectedTimestampEndSeconds: json['flowSelectedTimestampEndSeconds'] as int? ?? 10,
          isDraftEditMode: json['flowIsDraftEditMode'] as bool? ?? false,
          processingSnapshot: null,
          draftResult: null,
          finalSummaryData: null,
          chatMessages: const [],
        ),
        readyPreferenceText: json['readyPreferenceText'] as String? ?? '',
        draftGuidanceText: json['draftGuidanceText'] as String? ?? '',
        draftBodyText: json['draftBodyText'] as String? ?? '',
      ),
    );
  }
}