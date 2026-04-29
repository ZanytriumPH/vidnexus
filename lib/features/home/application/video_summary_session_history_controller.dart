import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../video_summary_models.dart';
import '../video_summary_repository.dart';
import 'video_summary_flow_controller.dart';

final videoSummarySessionHistoryProvider = NotifierProvider<
    VideoSummarySessionHistoryController, VideoSummarySessionHistoryState>(
  VideoSummarySessionHistoryController.new,
);

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
    required this.preferenceText,
    required this.draftBodyText,
  });

  final VideoSummaryFlowSnapshot flowSnapshot;
  final String preferenceText;
  final String draftBodyText;
}

class VideoSummarySessionHistoryController
    extends Notifier<VideoSummarySessionHistoryState> {
  VideoSummaryRepository get _repository => ref.read(videoSummaryRepositoryProvider);

  @override
  VideoSummarySessionHistoryState build() {
    final videoAsset = _repository.getVideoAsset();
    final sessions = [
      VideoSummarySessionHistoryEntry(
        id: 'session-1',
        title: '当前视频会话',
        durationLabel: videoAsset.durationLabel,
        detail: '当前会话仍在主区域，可以继续生成或追问。',
        snapshot: VideoSummarySessionSnapshot(
          flowSnapshot:
              ref.read(videoSummaryFlowControllerProvider.notifier).captureSnapshot(),
          preferenceText: '',
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

  String _detailForSnapshot(VideoSummarySessionSnapshot snapshot) {
    return switch (snapshot.flowSnapshot.stage) {
      VideoSummaryStage.ready => '新会话已创建，等待选择视频并生成总结。',
      VideoSummaryStage.processing => '处理中断点已保存，下次可直接恢复',
      VideoSummaryStage.draft => '已生成摘要，等待人工审阅',
      VideoSummaryStage.finalChat => '已完成总结，可继续时间旅行追问',
    };
  }

  VideoSummarySessionSnapshot _buildSeededProcessingSnapshot() {
    return const VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.processing,
        uploadHighlighted: true,
        processingExpanded: true,
        isTimestampScoped: true,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds: 30,
        isDraftEditMode: true,
        processingSnapshot: ProcessingSnapshot(
          progress: 0.58,
          statusLabel: '处理中',
          headline: '正在生成结构化初稿',
          etaLabel: '当前主步骤：融合语音、关键词和版面信息，准备输出第一版结构梳理。',
          badges: [
            ProcessingBadge(label: '语音转写 已完成', active: true),
            ProcessingBadge(label: '多轮融合 进行中', active: true),
            ProcessingBadge(label: '总结卡片可视化 处理中', active: false),
          ],
          steps: [
            ProcessingStep(
              label: '语音转写与切片',
              detail: '142 秒文本已完成校准。',
              progress: 100,
            ),
            ProcessingStep(
              label: '关键词归因与对齐',
              detail: '96 处关键点正在归入片段，质检线继续进行中。',
              progress: 61,
            ),
            ProcessingStep(
              label: '章节整合与摘要初稿',
              detail: '正在组织段间跳转语句与第一版总括。',
              progress: 28,
            ),
          ],
        ),
        draftResult: null,
        finalSummaryData: null,
        chatMessages: [],
      ),
      preferenceText: '先整理关键结论，再补充可执行动作。',
      draftBodyText: '',
    );
  }

  VideoSummarySessionSnapshot _buildSeededDraftSnapshot() {
    return const VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.draft,
        uploadHighlighted: true,
        processingExpanded: false,
        isTimestampScoped: true,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds: 30,
        isDraftEditMode: true,
        processingSnapshot: null,
        draftResult: DraftResult(
          overview: '初稿已生成，处理详情已自动折叠',
          paragraphs: [
            '这段竞品分析主要围绕用户分层、内容抓手和转化动作展开，前半段聚焦目标用户的需求切片，后半段则落到产品策略和执行节奏。',
            '当前结构稿已经整理完主线、亮点和风险项，适合继续补充面向团队同步的版本。',
          ],
          suggestionHint: '例如：把差异点和行动建议拆成更容易会议讨论的条目。',
        ),
        finalSummaryData: null,
        chatMessages: [],
      ),
      preferenceText: '保留原结论，但把执行建议写得更明确。',
      draftBodyText:
          '这段竞品分析主要围绕用户分层、内容抓手和转化动作展开，前半段聚焦目标用户的需求切片，后半段则落到产品策略和执行节奏。\n\n当前结构稿已经整理完主线、亮点和风险项，适合继续补充面向团队同步的版本。',
    );
  }

  VideoSummarySessionSnapshot _buildSeededFinalSnapshot() {
    return const VideoSummarySessionSnapshot(
      flowSnapshot: VideoSummaryFlowSnapshot(
        stage: VideoSummaryStage.finalChat,
        uploadHighlighted: true,
        processingExpanded: false,
        isTimestampScoped: false,
        selectedTimestampStartSeconds: 310,
        selectedTimestampEndSeconds: 420,
        isDraftEditMode: false,
        processingSnapshot: null,
        draftResult: DraftResult(
          overview: '初稿已生成，处理详情已自动折叠',
          paragraphs: ['产品方案讲解已经覆盖目标问题、用户路径和价值验证。'],
          suggestionHint: '继续补充差异化价值和风险边界。',
        ),
        finalSummaryData: FinalSummaryData(
          summaryTitle: '最终稿',
          summaryBody:
              '该视频聚焦产品方案讲解，先梳理问题场景与目标用户，再展开方案结构、交付节奏和验证路径。整体结论已经可用于评审同步，并适合继续按时间戳展开追问。',
          summaryTimestampLabel: '汇总片段 00:05:10 - 00:07:00',
          timestampChips: [
            TimestampChipData(label: '00:05:10 - 00:07:00', note: '方案价值与验证'),
            TimestampChipData(label: '00:10:20 - 00:12:10', note: '交付节奏与风险'),
          ],
          messages: [],
        ),
        chatMessages: [],
      ),
      preferenceText: '重点保留行动建议与里程碑。',
      draftBodyText: '产品方案讲解已经覆盖目标问题、用户路径和价值验证。',
    );
  }
}