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

  /// 每次 state 写入自动过一遍去重：同一 videoId 只保留数据最完整的条目。
  @override
  set state(VideoSummarySessionHistoryState value) {
    super.state = _deduplicate(value);
  }

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

      // 保留当前内存中已有的临时上传会话，避免异步加载后端列表时将其覆盖。
      // 同时收集已存在的 taskId，避免与后端历史条目重复。
      final tempSessions =
          state.sessions.where((s) => s.id.startsWith('temp-')).toList();
      final existingTaskIds = <String>{};
      final tempVideoIds = <String>{};
      for (final s in state.sessions) {
        if (s.id == 'session-current') continue;
        if (!s.id.startsWith('temp-')) {
          // 非 temp 条目（Step 1 重构后用 taskId 作为 ID）
          existingTaskIds.add(s.id);
        } else {
          // temp 条目：记录其 videoId 用于去重
          final vid = s.id.substring(5); // 去掉 'temp-' 前缀
          if (vid.isNotEmpty) tempVideoIds.add(vid);
          final tid = s.snapshot.flowSnapshot.taskId;
          if (tid != null && tid.isNotEmpty) existingTaskIds.add(tid);
        }
      }

      // 从后端数据构建"应存在的条目"映射（taskId → entry）
      final backendEntries = <String, VideoSummarySessionHistoryEntry>{};
      for (final t in tasks) {
        backendEntries[t.taskId] = _mapTaskToEntry(t, videoDetails[t.videoId]);
      }

      // 已存在的条目标识
      final existingIds = <String>{};
      for (final s in state.sessions) {
        if (s.id == 'session-current' || s.id.startsWith('temp-')) continue;
        existingIds.add(s.id);
        // 如果已有后端数据且当前条目缺失 kbName，用后端数据替换
        if (backendEntries.containsKey(s.id) &&
            s.snapshot.flowSnapshot.videoAsset?.kbName == null) {
          // 将在下方 replaceExisting 中处理
        }
      }

      // 合并：保留已有非 temp 条目（含用后端数据补全的），添加新的后端条目
      final replaceExisting = <String, VideoSummarySessionHistoryEntry>{};
      for (final s in state.sessions) {
        if (s.id == 'session-current' || s.id.startsWith('temp-')) continue;
        final be = backendEntries[s.id];
        if (be != null &&
            s.snapshot.flowSnapshot.videoAsset?.kbName == null) {
          // 用后端数据补全缺失的 kbName
          replaceExisting[s.id] = be;
        }
      }

      final keptSessions = state.sessions.map((s) {
        return replaceExisting[s.id] ?? s;
      }).where((s) {
        // session-current 保留，temp- 保留
        if (s.id == 'session-current') return false; // 单独处理
        return true;
      }).toList();

      // 添加后端中全新的条目
      for (final entry in backendEntries.entries) {
        if (!existingIds.contains(entry.key) &&
            !tempVideoIds.contains(entry.value.snapshot.flowSnapshot.videoAsset?.title ?? '')) {
          keptSessions.add(entry.value);
        }
      }

      final merged = [currentSession, ...keptSessions];
      final historyCount = merged.length - 1 - tempSessions.length;
      debugPrint(
        '[SessionHistory] _loadFromBackend DONE —'
        ' currentSession=${currentSession.id}'
        ' tempSessions(${tempSessions.length})=${tempSessions.map((s) => s.id).toList()}'
        ' updatedExisting(${replaceExisting.length})=${replaceExisting.keys.toList()}'
        ' merged(${merged.length})=${merged.map((s) => s.id).toList()}',
      );
      state = state.copyWith(
        sessions: merged,
        createdSessionCount: merged.length,
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
            kbName: task.kbName,
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
                  summaryTitle: '视频总结',
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
      // 即使已是活跃会话，仍移动到顶部（用户可能从视频详情页重复点击同一任务）
      _moveSessionToTop(sessionId);
      return;
    }
    _moveSessionToTop(sessionId);
    state = state.copyWith(activeSessionId: sessionId);
  }

  /// 将指定会话移动到列表顶部（紧接 session-current 之后），实现"最近点击置顶"。
  void _moveSessionToTop(String sessionId) {
    final index = state.sessions.indexWhere((s) => s.id == sessionId);
    if (index <= 1) return; // 已在顶部（index 0 = session-current，index 1 = 已是第一个）
    final entry = state.sessions[index];
    final current = state.sessions.firstWhere(
      (s) => s.id == 'session-current',
      orElse: () => state.sessions.first,
    );
    final others = state.sessions
        .where((s) => s.id != sessionId && s.id != 'session-current')
        .toList();
    state = state.copyWith(
      sessions: [current, entry, ...others],
    );
  }

  void syncActiveSession(VideoSummarySessionSnapshot snapshot) {
    final flowSnapshot = snapshot.flowSnapshot;
    final taskId = flowSnapshot.taskId;

    debugPrint(
      '[SessionHistory] syncActiveSession — activeSessionId=${state.activeSessionId}'
      ' taskId=$taskId isUploading=${flowSnapshot.isUploading}'
      ' videoId=${flowSnapshot.videoAsset?.title}',
    );

    // 情况 A：如果当前活跃会话是临时上传会话，但现在已经有了 taskId（即用户点击了开始生成），
    // 那么我们需要删除原本的临时会话，晋升/替换为一个以 taskId 为主键的正式后端会话。
    if (state.activeSessionId.startsWith('temp-') &&
        taskId != null &&
        taskId.isNotEmpty) {
      debugPrint('[SessionHistory] syncActiveSession → CASE A (promote temp→taskId)');
      final tempId = state.activeSessionId;
      final entry = VideoSummarySessionHistoryEntry(
        id: taskId,
        title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
        durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
        detail: _detailForSnapshot(snapshot),
        snapshot: snapshot,
      );

      // 移除 temp 条目，同时去重：移除任何已存在的同 taskId 条目
      // （例如 _loadFromBackend 已经加载了该任务）以及同 video 的残留 temp 条目
      final videoId = flowSnapshot.videoAsset?.title ?? '';
      final otherSessions = state.sessions
          .where((s) =>
              s.id != tempId &&
              s.id != 'session-current' &&
              s.id != taskId &&
              s.snapshot.flowSnapshot.taskId != taskId &&
              !(videoId.isNotEmpty && s.id == 'temp-$videoId'))
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
      debugPrint('[SessionHistory] syncActiveSession → CASE B (promote session-current→taskId)');
      final entry = VideoSummarySessionHistoryEntry(
        id: taskId,
        title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
        durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
        detail: _detailForSnapshot(snapshot),
        snapshot: snapshot,
      );

      // 插入到 index 1，同时去重：移除任何已存在的同 taskId 条目
      final videoId = flowSnapshot.videoAsset?.title ?? '';
      final otherSessions = state.sessions
          .skip(1) // 跳过 session-current
          .where((s) =>
              s.id != taskId &&
              s.snapshot.flowSnapshot.taskId != taskId &&
              !(videoId.isNotEmpty && s.id == 'temp-$videoId'))
          .toList();
      final sessions = [state.sessions.first, entry, ...otherSessions];

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
      debugPrint(
        '[SessionHistory] syncActiveSession MISS — activeSessionId=${state.activeSessionId}'
        ' NOT FOUND in ${state.sessions.map((s) => s.id).toList()}',
      );
      return;
    }

    final current = state.sessions[index];

    // 保护：若 entry 已有确定的 videoId，而快照携带的是不同的 videoId，
    // 说明 activeSessionId 指向了上一次上传的残留条目（handleFlowStateChanged
    // 在新上传触发了 syncActiveSession），跳过更新防止条目被污染。
    final entryVideoId = current.snapshot.flowSnapshot.videoAsset?.title ?? '';
    final snapshotVideoId = snapshot.flowSnapshot.videoAsset?.title ?? '';
    if (entryVideoId.isNotEmpty &&
        snapshotVideoId.isNotEmpty &&
        entryVideoId != snapshotVideoId &&
        entryVideoId != 'vid_default') {
      debugPrint(
        '[SessionHistory] syncActiveSession SKIP — videoId mismatch:'
        ' entry=$entryVideoId snapshot=$snapshotVideoId',
      );
      return;
    }

    final updated = current.copyWith(
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );
    final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
      ..[index] = updated;
    state = state.copyWith(sessions: sessions);

    debugPrint(
      '[SessionHistory] syncActiveSession DEFAULT — updated index=$index'
      ' sessionId=${state.activeSessionId} detail=${_detailForSnapshot(snapshot)}',
    );
  }

  void updateSessionSnapshot(String sessionId, VideoSummarySessionSnapshot snapshot) {
    final index = state.sessions.indexWhere((item) => item.id == sessionId);
    if (index == -1) {
      debugPrint(
        '[SessionHistory] updateSessionSnapshot MISS — sessionId=$sessionId'
        ' NOT FOUND in ${state.sessions.map((s) => s.id).toList()}',
      );
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

    debugPrint(
      '[SessionHistory] updateSessionSnapshot OK — sessionId=$sessionId'
      ' index=$index isUploading=${snapshot.flowSnapshot.isUploading}'
      ' detail=${_detailForSnapshot(snapshot)}',
    );
  }

  /// 创建一个仅在内存中生存的临时会话。同 ID 替旧，同 videoId 去重在
  /// [_loadFromBackend] 刷新后端列表时统一处理。
  ///
  /// [uploadId] 在上传流程中使用；提供时条目 key 为 `temp-upload-$uploadId`，
  /// 不提供时回退到旧版 `temp-$videoId` 逻辑。
  void addTempUploadSession(
    VideoSummarySessionSnapshot snapshot, {
    String? uploadId,
  }) {
    final flowSnapshot = snapshot.flowSnapshot;
    final videoId = flowSnapshot.videoAsset?.title ?? '';
    final taskId = flowSnapshot.taskId;
    final useTaskId = taskId != null && taskId.isNotEmpty;

    final String entryId;
    if (useTaskId) {
      entryId = taskId;
    } else if (uploadId != null && uploadId.isNotEmpty) {
      entryId = 'temp-upload-$uploadId';
    } else if (videoId.isNotEmpty && videoId != 'vid_default') {
      entryId = 'temp-$videoId';
    } else {
      return; // 无有效标识，跳过
    }

    final entry = VideoSummarySessionHistoryEntry(
      id: entryId,
      title: flowSnapshot.videoAsset?.fileName ?? '视频总结会话',
      durationLabel: flowSnapshot.videoAsset?.durationLabel ?? '0m 00s',
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );

    // 同 ID 替旧；同 videoId 不同 ID 统一交给 _removeIncompleteDuplicates 清理
    final current = state.sessions.firstWhere(
      (s) => s.id == 'session-current',
      orElse: () => state.sessions.first,
    );
    final others = state.sessions
        .where((s) => s.id != entryId && s.id != 'session-current')
        .toList();
    final existed = state.sessions.any((s) => s.id == entryId);
    final nextCount = existed ? state.createdSessionCount : state.createdSessionCount + 1;

    state = state.copyWith(
      sessions: [current, entry, ...others],
      activeSessionId: entryId,
      createdSessionCount: nextCount,
    );
  }

  /// 按 videoId 去重：同一视频出现多条记录时，仅保留数据最完整的那条。
  /// 作为 state setter 的透明过滤器，所有写入自动经过此函数。
  ///
  /// 完整性排序（逐级比较）：
  /// 1. 有 taskId 优于无 taskId
  /// 2. isUploading == false 优于 true
  /// 3. durationLabel 非占位值优于 "0m 00s"
  static VideoSummarySessionHistoryState _deduplicate(
    VideoSummarySessionHistoryState s,
  ) {
    final sessions = s.sessions;
    if (sessions.length <= 2) return s;

    final groups = <String, List<int>>{};
    for (int i = 0; i < sessions.length; i++) {
      if (sessions[i].id == 'session-current') continue;
      final vid = sessions[i].snapshot.flowSnapshot.videoAsset?.title ?? '';
      if (vid.isEmpty || vid == 'vid_default') continue;
      groups.putIfAbsent(vid, () => []).add(i);
    }

    final toRemoveIndices = <int>{};
    for (final entry in groups.entries) {
      if (entry.value.length <= 1) continue;

      final sorted = List<int>.from(entry.value)
        ..sort((a, b) {
          final sa = sessions[a].snapshot.flowSnapshot;
          final sb = sessions[b].snapshot.flowSnapshot;
          final aHasTask = sa.taskId != null && sa.taskId!.isNotEmpty;
          final bHasTask = sb.taskId != null && sb.taskId!.isNotEmpty;
          if (aHasTask != bHasTask) return aHasTask ? -1 : 1;
          if (sa.isUploading != sb.isUploading) return sa.isUploading ? 1 : -1;
          final aHasDuration = sessions[a].durationLabel != '0m 00s';
          final bHasDuration = sessions[b].durationLabel != '0m 00s';
          if (aHasDuration != bHasDuration) return aHasDuration ? -1 : 1;
          return a.compareTo(b);
        });

      for (int i = 1; i < sorted.length; i++) {
        toRemoveIndices.add(sorted[i]);
        debugPrint(
          '[SessionHistory] 去重移除 — ${sessions[sorted[i]].id}'
          ' (videoId=${entry.key})',
        );
      }
    }

    if (toRemoveIndices.isEmpty) return s;

    final keepCurrent = sessions.firstWhere((s) => s.id == 'session-current');
    final others = <VideoSummarySessionHistoryEntry>[];
    for (int i = 0; i < sessions.length; i++) {
      if (sessions[i].id == 'session-current') continue;
      if (!toRemoveIndices.contains(i)) others.add(sessions[i]);
    }

    final activeWasRemoved = toRemoveIndices.any(
      (i) => sessions[i].id == s.activeSessionId,
    );

    return s.copyWith(
      sessions: [keepCurrent, ...others],
      activeSessionId: activeWasRemoved ? 'session-current' : s.activeSessionId,
    );
  }

  /// 显式移除指定会话条目（用于去重等场景下清理残留 temp 条目）。
  void removeSession(String sessionId) {
    final index = state.sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      debugPrint(
        '[SessionHistory] removeSession MISS — sessionId=$sessionId'
        ' NOT FOUND in ${state.sessions.map((s) => s.id).toList()}',
      );
      return;
    }
    final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
      ..removeAt(index);
    // 如果移除的是当前活跃会话，回退到 session-current
    String nextActiveId = state.activeSessionId;
    if (state.activeSessionId == sessionId) {
      nextActiveId = 'session-current';
    }
    state = state.copyWith(
      sessions: sessions,
      activeSessionId: nextActiveId,
      createdSessionCount:
          state.createdSessionCount > 0 ? state.createdSessionCount - 1 : 0,
    );

    debugPrint(
      '[SessionHistory] removeSession OK — sessionId=$sessionId'
      ' index=$index newActiveId=$nextActiveId'
      ' remainingIds=${sessions.map((s) => s.id).toList()}',
    );
  }

  /// 激活或添加一个已有的后端任务会话，防止在侧边栏中产生 temp- 前缀的重复项。
  void addOrActivateTaskSession({
    required String taskId,
    required VideoSummarySessionSnapshot snapshot,
  }) {
    final flowSnapshot = snapshot.flowSnapshot;
    final fileName = flowSnapshot.videoAsset?.fileName ?? '视频总结会话';
    final durationLabel = flowSnapshot.videoAsset?.durationLabel ?? '0m 00s';

    // 1. 检查是否存在该 taskId 的正式会话
    final existingIndex = state.sessions.indexWhere((s) => s.id == taskId);

    if (existingIndex != -1) {
      // 如果已存在，更新其快照并将其设为活跃状态
      final updated = state.sessions[existingIndex].copyWith(
        snapshot: snapshot,
        detail: _detailForSnapshot(snapshot),
      );
      final videoId = flowSnapshot.videoAsset?.title ?? '';
      final tempId = 'temp-$videoId';
      final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
        ..[existingIndex] = updated;

      // 清除对应的临时会话，防止产生重复项
      sessions.removeWhere((s) => s.id == tempId);

      state = state.copyWith(
        sessions: sessions,
        activeSessionId: taskId,
      );
      return;
    }

    // 2. 检查是否存在对应的临时会话（例如从上传刚晋升过来，或者有相同的 videoId）
    final videoId = flowSnapshot.videoAsset?.title ?? '';
    final tempId = 'temp-$videoId';
    final tempIndex = state.sessions.indexWhere((s) => s.id == tempId);

    if (tempIndex != -1) {
      // 如果存在临时会话，将其就地晋升为以 taskId 为主键的正式会话，避免重复
      final entry = VideoSummarySessionHistoryEntry(
        id: taskId,
        title: fileName,
        durationLabel: durationLabel,
        detail: _detailForSnapshot(snapshot),
        snapshot: snapshot,
      );
      final sessions = List<VideoSummarySessionHistoryEntry>.from(state.sessions)
        ..[tempIndex] = entry;
      state = state.copyWith(
        sessions: sessions,
        activeSessionId: taskId,
      );
      return;
    }

    // 3. 既无正式会话也无临时会话，新建正式会话并插入到 session-current 之后
    final entry = VideoSummarySessionHistoryEntry(
      id: taskId,
      title: fileName,
      durationLabel: durationLabel,
      detail: _detailForSnapshot(snapshot),
      snapshot: snapshot,
    );

    final current = state.sessions.first;
    final sessions = [current, entry, ...state.sessions.skip(1)];

    state = state.copyWith(
      sessions: sessions,
      activeSessionId: taskId,
      createdSessionCount: state.createdSessionCount + 1,
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