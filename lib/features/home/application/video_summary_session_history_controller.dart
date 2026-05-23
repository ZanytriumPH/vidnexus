import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final List<VideoSummarySessionHistoryEntry> sessions;
  final String activeSessionId;
  final int createdSessionCount;

  VideoSummarySessionHistoryState copyWith({
    List<VideoSummarySessionHistoryEntry>? sessions,
    String? activeSessionId,
    int? createdSessionCount,
  }) {
    return VideoSummarySessionHistoryState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      createdSessionCount: createdSessionCount ?? this.createdSessionCount,
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

    // 异步加载后端历史会话列表
    _loadFromBackend();

    return VideoSummarySessionHistoryState(
      sessions: [currentSession],
      activeSessionId: currentSession.id,
      createdSessionCount: 1,
    );
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
  Future<void> _loadFromBackend() async {
    try {
      final tasks = await _repository.listTaskHistory();
      if (tasks.isEmpty) return;

      final currentSession = state.sessions.first;
      final historyEntries = tasks.map(_mapTaskToEntry).toList();

      state = state.copyWith(
        sessions: [currentSession, ...historyEntries],
        createdSessionCount: 1 + historyEntries.length,
      );
    } catch (_) {
      // 后端不可用时静默保持仅当前会话，不影响用户操作
    }
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
      WorkflowState.finalGenerating => VideoSummaryStage.processing,
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
  }

  // 抽屉里展示的说明文案由当前阶段推导出来，而不是额外保存一份平行状态。
  String _detailForSnapshot(VideoSummarySessionSnapshot snapshot) {
    return switch (snapshot.flowSnapshot.stage) {
      VideoSummaryStage.ready => '新会话已创建，等待选择视频并生成总结。',
      VideoSummaryStage.processing => '处理中断点已保存，下次可直接恢复',
      VideoSummaryStage.draft => '已生成摘要，等待人工审阅',
      VideoSummaryStage.finalChat => '已完成总结，可继续时间旅行追问',
    };
  }
}