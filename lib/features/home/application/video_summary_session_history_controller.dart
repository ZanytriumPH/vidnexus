import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/video_summary_domain_models.dart';
import '../video_summary_models.dart';
import '../video_summary_repository.dart';
import 'video_summary_flow_controller.dart';
import 'video_summary_result_mapper.dart';

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
    // 第一项始终代表当前正在编辑的主会话，后面几项是用于演示恢复能力的 seeded session。
    final sessions = [
      VideoSummarySessionHistoryEntry(
        id: 'session-1',
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
      ),
      VideoSummarySessionHistoryEntry(
        id: 'session-seed-final',
        title: '产品方案讲解',
        durationLabel: '14:32',
        detail: '已完成总结，可继续时间旅行追问',
        snapshot: _buildSeededFinalSnapshot(),
      ),
      VideoSummarySessionHistoryEntry(
        id: 'session-seed-processing',
        title: '架构评审录屏',
        durationLabel: '09:48',
        detail: '处理中断点已保存，下次可直接恢复',
        snapshot: _buildSeededProcessingSnapshot(),
      ),
      VideoSummarySessionHistoryEntry(
        id: 'session-seed-draft',
        title: '竞品分析 Demo',
        durationLabel: '22:05',
        detail: '已生成摘要，等待人工审阅',
        snapshot: _buildSeededDraftSnapshot(),
      ),
    ];

    return VideoSummarySessionHistoryState(
      sessions: sessions,
      activeSessionId: sessions.first.id,
      createdSessionCount: 1,
    );
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

  // 这些 seeded snapshot 走和正式数据同样的 mapper 链路，避免 demo 数据污染分层边界。
  VideoSummarySessionSnapshot _buildSeededProcessingSnapshot() {
    return VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.processing,
        uploadHighlighted: true,
        processingExpanded: true,
        isTimestampScoped: true,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds: 30,
        isDraftEditMode: true,
        processingSnapshot: mapProcessingDataToSnapshot(
          const VideoSummaryProcessingData(
            progress: 0.58,
            currentStage: VideoSummaryProcessingStage.analyzingVisionChunks,
            currentMessage: '视觉分片正在补齐关键帧证据，音频线索已进入回流阶段。',
            chunkProgress: VideoSummaryChunkProgressData(
              stage: VideoSummaryChunkProgressStage.running,
              totalChunks: 8,
              audioDone: 5,
              visionDone: 3,
              synthesisDone: 1,
              overallDone: 9,
              overallTotal: 24,
              overallPercent: 38,
            ),
            steps: [
              VideoSummaryProcessingStepData(
                phase: VideoSummaryProcessingPhase.preprocessing,
                progress: 100,
                completedUnits: 4,
                totalUnits: 4,
              ),
              VideoSummaryProcessingStepData(
                phase: VideoSummaryProcessingPhase.analysis,
                progress: 61,
                completedUnits: 8,
                totalUnits: 16,
              ),
              VideoSummaryProcessingStepData(
                phase: VideoSummaryProcessingPhase.synthesis,
                progress: 28,
                completedUnits: 1,
                totalUnits: 10,
              ),
            ],
          ),
        ),
        draftResult: null,
        finalSummaryData: null,
        chatMessages: [],
      ),
      readyPreferenceText: '先整理关键结论，再补充可执行动作。',
      draftGuidanceText: '',
      draftBodyText: '',
    );
  }

  VideoSummarySessionSnapshot _buildSeededDraftSnapshot() {
    return VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.draft,
        uploadHighlighted: true,
        processingExpanded: false,
        isTimestampScoped: true,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds: 30,
        isDraftEditMode: true,
        processingSnapshot: null,
        draftResult: mapDraftDataToResult(
          const VideoSummaryDraftData(
            paragraphs: [
              '这段竞品分析主要围绕用户分层、内容抓手和转化动作展开，前半段聚焦目标用户的需求切片，后半段则落到产品策略和执行节奏。',
              '当前结构稿已经整理完主线、亮点和风险项，适合继续补充面向团队同步的版本。',
            ],
          ),
        ),
        finalSummaryData: null,
        chatMessages: [],
      ),
        readyPreferenceText: '',
        draftGuidanceText: '保留原结论，但把执行建议写得更明确。',
      draftBodyText:
          '这段竞品分析主要围绕用户分层、内容抓手和转化动作展开，前半段聚焦目标用户的需求切片，后半段则落到产品策略和执行节奏。\n\n当前结构稿已经整理完主线、亮点和风险项，适合继续补充面向团队同步的版本。',
    );
  }

  VideoSummarySessionSnapshot _buildSeededFinalSnapshot() {
    return VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.finalChat,
        uploadHighlighted: true,
        processingExpanded: false,
        isTimestampScoped: false,
        selectedTimestampStartSeconds: 310,
        selectedTimestampEndSeconds: 420,
        isDraftEditMode: false,
        processingSnapshot: null,
        draftResult: mapDraftDataToResult(
          const VideoSummaryDraftData(
            paragraphs: ['产品方案讲解已经覆盖目标问题、用户路径和价值验证。'],
          ),
        ),
        finalSummaryData: mapFinalResultDataToSummary(
          const VideoSummaryFinalResultData(
            body:
                '该视频聚焦产品方案讲解，先梳理问题场景与目标用户，再展开方案结构、交付节奏和验证路径。整体结论已经可用于评审同步，并适合继续按时间戳展开追问。',
            references: [
              VideoSummaryReferenceRange(
                startSeconds: 5 * 60 + 10,
                endSeconds: 7 * 60,
                topic: '方案价值与验证',
              ),
              VideoSummaryReferenceRange(
                startSeconds: 10 * 60 + 20,
                endSeconds: 12 * 60 + 10,
                topic: '交付节奏与风险',
              ),
            ],
          ),
        ),
        chatMessages: [],
      ),
      readyPreferenceText: '',
      draftGuidanceText: '重点保留行动建议与里程碑。',
      draftBodyText: '产品方案讲解已经覆盖目标问题、用户路径和价值验证。',
    );
  }
}