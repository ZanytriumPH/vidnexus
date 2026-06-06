import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/service_providers.dart';
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

  /// 加载后端任务列表到侧边栏。
  Future<void> _loadAll() async {
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
  /// 同时批量拉取每个任务对应视频的 fileName + duration，
  /// 确保所有历史会话的标题格式统一为 "视频名称 / 时间"。
  Future<void> _loadFromBackend() async {
    try {
      final tasks = await _repository.listTaskHistory();

      // 批量拉取视频详情，用于获取 fileName 和 duration
      final videoService = ref.read(videoServiceProvider);
      final videoDetails = <String, _VideoMeta>{};
      for (final task in tasks) {
        if (videoDetails.containsKey(task.videoId)) continue;
        try {
          final resp = await videoService.getVideo(task.videoId);
          final data = resp.data;
          videoDetails[task.videoId] = _VideoMeta(
            fileName: data?.fileName ?? '',
            durationSeconds: data?.duration ?? 0,
          );
        } catch (_) {
          videoDetails[task.videoId] =
              const _VideoMeta(fileName: '', durationSeconds: 0);
        }
      }

      final currentSession = state.sessions.firstWhere(
        (s) => s.id == 'session-current',
        orElse: () => state.sessions.first,
      );

      // 保留当前内存中已有的临时上传会话，避免异步加载后端列表时将其覆盖
      final tempSessions =
          state.sessions.where((s) => s.id.startsWith('temp-')).toList();
      final historyEntries = tasks
          .map((t) => _mapTaskToEntry(t, videoDetails[t.videoId]))
          .toList();

      final merged = [currentSession, ...tempSessions, ...historyEntries];
      state = state.copyWith(
        sessions: merged,
        createdSessionCount: 1 + tempSessions.length + historyEntries.length,
        isLoadingHistory: false,
        clearError: true,
      );
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
  /// 标题统一使用"视频名称 / 时间"格式（与仅上传视频的临时会话一致）。
  VideoSummarySessionHistoryEntry _mapTaskToEntry(
    VideoSummaryTaskInfo task,
    _VideoMeta? meta,
  ) {
    final stage = _stageFromWorkflowState(task.workflowState);
    final paragraphs = _splitParagraphs(task.draftSummary);
    final fileName = (meta != null && meta.fileName.isNotEmpty)
        ? meta.fileName
        : task.videoId;
    final durationLabel = (meta != null && meta.durationSeconds > 0)
        ? _formatDurationLabel(meta.durationSeconds)
        : '--:--';

    return VideoSummarySessionHistoryEntry(
      id: task.taskId,
      title: fileName,
      durationLabel: durationLabel,
      detail: task.workflowState.label,
      snapshot: VideoSummarySessionSnapshot(
        flowSnapshot: VideoSummaryFlowSnapshot(
          taskId: task.taskId,
          videoAsset: VideoAssetInfo(
            title: task.videoId,
            durationLabel: durationLabel,
            sourceLabel: task.kbid,
            fileName: fileName,
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

  void activateSession(String sessionId) {
    if (state.activeSessionId == sessionId) {
      return;
    }
    state = state.copyWith(activeSessionId: sessionId);
  }

  void syncActiveSession(VideoSummarySessionSnapshot snapshot) {
    final flowSnapshot = snapshot.flowSnapshot;
    final taskId = flowSnapshot.taskId;

    // 情况 A：如果当前活跃会话是临时上传会话，但现在已经有了 taskId（即用户点击了开始生成），
    // 那么我们需要删除原本的临时会话，晋升/替换为一个以 taskId 为主键的正式后端会话。
    if (state.activeSessionId.startsWith('temp-') &&
        taskId != null &&
        taskId.isNotEmpty) {
      final tempId = state.activeSessionId;
      final entry = VideoSummarySessionHistoryEntry(
        id: taskId,
        title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
        durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
        detail: _detailForSnapshot(snapshot),
        snapshot: snapshot,
      );

      final otherSessions = state.sessions
          .where((s) => s.id != tempId && s.id != 'session-current')
          .toList();
      final current = state.sessions.firstWhere(
        (s) => s.id == 'session-current',
        orElse: () => state.sessions.first,
      );
      final sessions = [current, entry, ...otherSessions];

      state = state.copyWith(
        sessions: sessions,
        activeSessionId: taskId,
      );
      return;
    }

    // 情况 B：如果当前活跃会话是 session-current，但已经有了 taskId，也晋升为正式会话
    if (state.activeSessionId == 'session-current' &&
        taskId != null &&
        taskId.isNotEmpty) {
      final entry = VideoSummarySessionHistoryEntry(
        id: taskId,
        title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
        durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
        detail: _detailForSnapshot(snapshot),
        snapshot: snapshot,
      );

      // 插入到 index 1（在 session-current 之后）
      final current = state.sessions.first;
      final otherSessions = state.sessions.skip(1).toList();
      final sessions = [current, entry, ...otherSessions];

      state = state.copyWith(
        sessions: sessions,
        activeSessionId: taskId,
        createdSessionCount: state.createdSessionCount + 1,
      );
      return;
    }

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
  }

  void updateSessionSnapshot(String sessionId, VideoSummarySessionSnapshot snapshot) {
    final index = state.sessions.indexWhere((item) => item.id == sessionId);
    if (index == -1) return;
    final current = state.sessions[index];
    final updated = current.copyWith(
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );
    final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
      ..[index] = updated;
    state = state.copyWith(sessions: sessions);
  }

  /// 当视频上传成功且 Celery 处理完毕时，创建一个仅在内存中生存的临时会话。
  /// 此临时会话不落盘，允许在应用退出后丢失。
  void addTempUploadSession(VideoSummarySessionSnapshot snapshot) {
    final flowSnapshot = snapshot.flowSnapshot;
    final videoId = flowSnapshot.videoAsset?.title ?? '';
    if (videoId.isEmpty || videoId == 'vid_default') return;

    final entryId = 'temp-$videoId';

    // 若已存在同一 videoId 的临时条目，更新而非新建
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
      activeSessionId: entryId,
      createdSessionCount: nextCount,
    );
  }

  // 抽屉里展示的说明文案由当前阶段推导出来，而不是额外保存一份平行状态。
  String _detailForSnapshot(VideoSummarySessionSnapshot snapshot) {
    if (snapshot.flowSnapshot.isUploading) {
      final percentage = (snapshot.flowSnapshot.uploadProgress * 100).toStringAsFixed(0);
      return '视频上传中... $percentage%';
    }
    return switch (snapshot.flowSnapshot.stage) {
      VideoSummaryStage.ready => '已上传视频，可继续生成总结。',
      VideoSummaryStage.processing => '处理中断点已保存，下次可直接恢复',
      VideoSummaryStage.draft => '已生成摘要，等待人工审阅',
      VideoSummaryStage.finalChat => '已完成总结，可继续时间旅行追问',
    };
  }

  /// 将秒数格式化为 "Xm Ys" 或 "Xh Ym Zs"。
  static String _formatDurationLabel(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

/// 轻量视频元数据，用于批量拉取后传递给 _mapTaskToEntry。
class _VideoMeta {
  const _VideoMeta({required this.fileName, required this.durationSeconds});

  final String fileName;
  final int durationSeconds;
}