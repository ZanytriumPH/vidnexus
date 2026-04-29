import 'package:flutter/material.dart';

import '../../app/widgets/app_bottom_nav.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';
import '../knowledge_base/knowledge_base_home_screen.dart';
import 'widgets/home_shell_widgets.dart';
import 'widgets/session_settings_sheet.dart';
import 'widgets/video_summary_content_widgets.dart';
import 'widgets/video_summary_drawer_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  static const routeName = '/';

  final VideoSummaryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _minimumTimestampRangeSeconds = 10;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _preferenceController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _draftBodyController = TextEditingController();

  bool _uploadHighlighted = false;
  bool _processingExpanded = true;
  bool _isDraftEditMode = true;
  bool _isGenerating = false;
  bool _isSendingChat = false;
  bool _isTimestampScoped = false;
  int _selectedTimestampStartSeconds = 0;
  int _selectedTimestampEndSeconds = _minimumTimestampRangeSeconds;
  VideoSummaryStage _stage = VideoSummaryStage.ready;
  bool _defaultTimestampScoped = false;
  bool _defaultProcessingExpanded = true;
  late final VideoAssetInfo _videoAsset;
  late List<_SessionHistoryEntry> _sessions;
  late String _activeSessionId;
  int _createdSessionCount = 1;
  ProcessingSnapshot? _processingSnapshot;
  DraftResult? _draftResult;
  FinalSummaryData? _finalSummaryData;
  List<ChatMessage> _chatMessages = const [];

  @override
  void initState() {
    super.initState();
    _videoAsset = widget.repository.getVideoAsset();
    final initialRange = _buildDefaultTimestampRange();
    _selectedTimestampStartSeconds = initialRange.startSeconds;
    _selectedTimestampEndSeconds = initialRange.endSeconds;
    _sessions = _buildInitialSessions();
    _activeSessionId = _sessions.first.id;
  }

  @override
  void dispose() {
    _preferenceController.dispose();
    _chatController.dispose();
    _draftBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawerEnableOpenDragGesture: true,
      drawer: VideoSummaryHistoryDrawer(
        sessions: _sessions
            .map(
              (session) => VideoSummaryDrawerSessionItem(
                id: session.id,
                title: session.title,
                durationLabel: session.durationLabel,
                detail: session.detail,
                isActive: session.id == _activeSessionId,
              ),
            )
            .toList(),
        onNewSessionPressed: _createNewSessionFromDrawer,
        onSessionSelected: _restoreSessionFromDrawer,
        onSettingsPressed: _openSettingsFromDrawer,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  child: _stage == VideoSummaryStage.ready
                      ? Column(
                          children: [
                            const Spacer(flex: 5),
                            _buildWorkspace(),
                            const Spacer(flex: 4),
                          ],
                        )
                      : SingleChildScrollView(
                          child: _buildWorkspace(),
                        ),
                ),
              ],
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          KnowledgeBaseHomeScreen.routeName,
          (route) => false,
        );
    }
  }

  void _resetPageState() {
    _preferenceController.clear();
    _chatController.clear();
    _draftBodyController.clear();
    _uploadHighlighted = false;
    _processingExpanded = _defaultProcessingExpanded;
    _isDraftEditMode = true;
    _isGenerating = false;
    _isSendingChat = false;
    _isTimestampScoped = _defaultTimestampScoped;
    final defaultRange = _buildDefaultTimestampRange();
    _selectedTimestampStartSeconds = defaultRange.startSeconds;
    _selectedTimestampEndSeconds = defaultRange.endSeconds;
    _stage = VideoSummaryStage.ready;
    _processingSnapshot = null;
    _draftResult = null;
    _finalSummaryData = null;
    _chatMessages = const [];
  }

  void _toggleUploadSelection() {
    setState(() {
      _uploadHighlighted = !_uploadHighlighted;
      _syncActiveSession();
    });
  }

  void _toggleProcessingExpanded() {
    if (_stage != VideoSummaryStage.processing) {
      return;
    }

    setState(() {
      _processingExpanded = !_processingExpanded;
      _syncActiveSession();
    });
  }

  Future<void> _startDraftGeneration() async {
    if (_isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _stage = VideoSummaryStage.processing;
      _processingExpanded = _defaultProcessingExpanded;
      _processingSnapshot = null;
      _draftResult = null;
      _finalSummaryData = null;
      _chatMessages = const [];
      _syncActiveSession();
    });

    try {
      await for (final snapshot in widget.repository.startDraftGeneration()) {
        if (!mounted) {
          return;
        }

        setState(() {
          _processingSnapshot = snapshot;
          _syncActiveSession();
        });
      }

      final draft = await widget.repository.fetchDraftResult();
      if (!mounted) {
        return;
      }

      setState(() {
        _draftResult = draft;
        _stage = VideoSummaryStage.draft;
        _processingExpanded = false;
        _isDraftEditMode = true;
        _draftBodyController.text = draft.paragraphs.join('\n\n');
        _syncActiveSession();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _syncActiveSession();
        });
      }
    }
  }

  Future<void> _generateFinalSummary() async {
    final draft = _draftResult;
    if (_isGenerating || draft == null) {
      return;
    }

    final editedParagraphs = _draftBodyController.text
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final effectiveDraft = DraftResult(
      overview: draft.overview,
      paragraphs: editedParagraphs.isEmpty ? draft.paragraphs : editedParagraphs,
      suggestionHint: draft.suggestionHint,
    );

    setState(() {
      _isGenerating = true;
    });

    try {
      final summary = await widget.repository.generateFinalSummary(
        guidance: _preferenceController.text.trim(),
        draft: effectiveDraft,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _finalSummaryData = summary;
        _chatMessages = List<ChatMessage>.from(summary.messages);
        _draftResult = effectiveDraft;
        _stage = VideoSummaryStage.finalChat;
        final seededRange = _buildRangeFromSummary(summary);
        _selectedTimestampStartSeconds = seededRange.startSeconds;
        _selectedTimestampEndSeconds = seededRange.endSeconds;
        _syncActiveSession();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _syncActiveSession();
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (_isSendingChat || text.isEmpty) {
      return;
    }

    final timestampLabel =
      _isTimestampScoped
      ? _formatTimestampRange(
        _selectedTimestampStartSeconds,
        _selectedTimestampEndSeconds,
        )
      : null;

    final userMessage = ChatMessage(
      sender: SummaryChatSender.user,
      text: text,
      timestampLabel: timestampLabel,
    );

    setState(() {
      _isSendingChat = true;
      _chatMessages = [..._chatMessages, userMessage];
      _chatController.clear();
      _syncActiveSession();
    });

    try {
      final reply = await widget.repository.sendSummaryChatMessage(text);
      if (!mounted) {
        return;
      }

      setState(() {
        _chatMessages = [
          ..._chatMessages,
          ChatMessage(
            sender: reply.sender,
            text: reply.text,
            timestampLabel: timestampLabel,
          ),
        ];
        _syncActiveSession();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingChat = false;
          _syncActiveSession();
        });
      }
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

  void _createNewSession() {
    setState(() {
      _createdSessionCount += 1;
      _resetPageState();
      final session = _SessionHistoryEntry(
        id: 'session-$_createdSessionCount',
        title: '视频总结会话 ${_createdSessionCount.toString().padLeft(2, '0')}',
        durationLabel: _videoAsset.durationLabel,
        detail: '新会话已创建，等待选择视频并生成总结。',
        snapshot: _captureCurrentSnapshot(),
      );
      _activeSessionId = session.id;
      _sessions = [session, ..._sessions];
      _syncActiveSession();
    });
  }

  void _createNewSessionFromDrawer() {
    Navigator.of(context).pop();
    _createNewSession();
  }

  void _restoreSessionFromDrawer(String sessionId) {
    final session = _sessions.where((item) => item.id == sessionId).firstOrNull;
    if (session == null) {
      return;
    }

    Navigator.of(context).pop();
    setState(() {
      _applySnapshot(session.snapshot);
      _activeSessionId = session.id;
      _syncActiveSession();
    });
  }

  Future<void> _openSettingsFromDrawer() async {
    Navigator.of(context).pop();
    await showSessionSettingsSheet(
      context: context,
      defaultTimestampScoped: _defaultTimestampScoped,
      defaultProcessingExpanded: _defaultProcessingExpanded,
      onDefaultTimestampScopedChanged: (value) {
        setState(() {
          _defaultTimestampScoped = value;
        });
      },
      onDefaultProcessingExpandedChanged: (value) {
        setState(() {
          _defaultProcessingExpanded = value;
        });
      },
    );
  }

  VideoSummaryWorkspace _buildWorkspace() {
    return VideoSummaryWorkspace(
      stage: _stage,
      highlighted: _uploadHighlighted,
      videoAsset: _videoAsset,
      processingSnapshot: _processingSnapshot,
      draftResult: _draftResult,
      finalSummaryData: _finalSummaryData,
      chatMessages: _chatMessages,
      preferenceController: _preferenceController,
      chatController: _chatController,
      draftBodyController: _draftBodyController,
      processingExpanded: _processingExpanded,
      isDraftEditMode: _isDraftEditMode,
      isGenerating: _isGenerating,
      isSendingChat: _isSendingChat,
      isTimestampScoped: _isTimestampScoped,
      selectedTimestampLabel: _formatTimestampRange(
        _selectedTimestampStartSeconds,
        _selectedTimestampEndSeconds,
      ),
      totalDurationSeconds: _videoDurationInSeconds,
      selectedTimestampStartSeconds: _selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: _selectedTimestampEndSeconds,
      onUploadCardPressed: _toggleUploadSelection,
      onProcessingCardPressed: _toggleProcessingExpanded,
      onDraftEditModeChanged: (value) {
        setState(() {
          _isDraftEditMode = value;
          _syncActiveSession();
        });
      },
      onStartPressed: _isGenerating ? null : _startDraftGeneration,
      onGenerateFinalPressed: _isGenerating ? null : _generateFinalSummary,
      onSendChatPressed: _isSendingChat ? null : _sendChatMessage,
      onTimestampScopeChanged: (value) {
        setState(() {
          _isTimestampScoped = value;
          _syncActiveSession();
        });
      },
      onTimestampRangeChanged: (range) {
        setState(() {
          _selectedTimestampStartSeconds = range.startSeconds;
          _selectedTimestampEndSeconds = range.endSeconds;
          _syncActiveSession();
        });
      },
    );
  }

  List<_SessionHistoryEntry> _buildInitialSessions() {
    return [
      _SessionHistoryEntry(
        id: 'session-1',
        title: '当前视频会话',
        durationLabel: _videoAsset.durationLabel,
        detail: '当前会话仍在主区域，可以继续生成或追问。',
        snapshot: _captureCurrentSnapshot(),
      ),
      _SessionHistoryEntry(
        id: 'session-seed-final',
        title: '产品方案讲解',
        durationLabel: '14:32',
        detail: '已完成总结，可继续时间旅行追问',
        snapshot: _buildSeededFinalSnapshot(),
      ),
      _SessionHistoryEntry(
        id: 'session-seed-processing',
        title: '架构评审录屏',
        durationLabel: '09:48',
        detail: '处理中断点已保存，下次可直接恢复',
        snapshot: _buildSeededProcessingSnapshot(),
      ),
      _SessionHistoryEntry(
        id: 'session-seed-draft',
        title: '竞品分析 Demo',
        durationLabel: '22:05',
        detail: '已生成摘要，等待人工审阅',
        snapshot: _buildSeededDraftSnapshot(),
      ),
    ];
  }

  _SessionSnapshot _captureCurrentSnapshot() {
    return _SessionSnapshot(
      stage: _stage,
      uploadHighlighted: _uploadHighlighted,
      processingExpanded: _processingExpanded,
      isTimestampScoped: _isTimestampScoped,
      selectedTimestampStartSeconds: _selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: _selectedTimestampEndSeconds,
      preferenceText: _preferenceController.text,
      draftBodyText: _draftBodyController.text,
      isDraftEditMode: _isDraftEditMode,
      processingSnapshot: _processingSnapshot,
      draftResult: _draftResult,
      finalSummaryData: _finalSummaryData,
      chatMessages: List<ChatMessage>.from(_chatMessages),
    );
  }

  void _applySnapshot(_SessionSnapshot snapshot) {
    _stage = snapshot.stage;
    _uploadHighlighted = snapshot.uploadHighlighted;
    _processingExpanded = snapshot.processingExpanded;
    _isGenerating = false;
    _isSendingChat = false;
    _isTimestampScoped = snapshot.isTimestampScoped;
    _selectedTimestampStartSeconds = snapshot.selectedTimestampStartSeconds;
    _selectedTimestampEndSeconds = snapshot.selectedTimestampEndSeconds;
    _isDraftEditMode = snapshot.isDraftEditMode;
    _processingSnapshot = snapshot.processingSnapshot;
    _draftResult = snapshot.draftResult;
    _finalSummaryData = snapshot.finalSummaryData;
    _chatMessages = List<ChatMessage>.from(snapshot.chatMessages);
    _preferenceController.text = snapshot.preferenceText;
    _draftBodyController.text = snapshot.draftBodyText;
    _chatController.clear();
  }

  void _syncActiveSession() {
    final index = _sessions.indexWhere((item) => item.id == _activeSessionId);
    if (index == -1) {
      return;
    }

    final current = _sessions[index];
    final updated = current.copyWith(
      detail: _detailForSnapshot(_captureCurrentSnapshot()),
      snapshot: _captureCurrentSnapshot(),
    );
    _sessions = List<_SessionHistoryEntry>.from(_sessions)..[index] = updated;
  }

  String _detailForSnapshot(_SessionSnapshot snapshot) {
    return switch (snapshot.stage) {
      VideoSummaryStage.ready => '新会话已创建，等待选择视频并生成总结。',
      VideoSummaryStage.processing => '处理中断点已保存，下次可直接恢复',
      VideoSummaryStage.draft => '已生成摘要，等待人工审阅',
      VideoSummaryStage.finalChat => '已完成总结，可继续时间旅行追问',
    };
  }

  _SessionSnapshot _buildSeededProcessingSnapshot() {
    return _SessionSnapshot(
      stage: VideoSummaryStage.processing,
      uploadHighlighted: true,
      processingExpanded: true,
      isTimestampScoped: true,
      selectedTimestampStartSeconds: 0,
      selectedTimestampEndSeconds: 30,
      preferenceText: '先整理关键结论，再补充可执行动作。',
      draftBodyText: '',
      isDraftEditMode: true,
      processingSnapshot: const ProcessingSnapshot(
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
      chatMessages: const [],
    );
  }

  _SessionSnapshot _buildSeededDraftSnapshot() {
    return const _SessionSnapshot(
      stage: VideoSummaryStage.draft,
      uploadHighlighted: true,
      processingExpanded: false,
      isTimestampScoped: true,
      selectedTimestampStartSeconds: 0,
      selectedTimestampEndSeconds: 30,
      preferenceText: '保留原结论，但把执行建议写得更明确。',
      draftBodyText:
          '这段竞品分析主要围绕用户分层、内容抓手和转化动作展开，前半段聚焦目标用户的需求切片，后半段则落到产品策略和执行节奏。\n\n当前结构稿已经整理完主线、亮点和风险项，适合继续补充面向团队同步的版本。',
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
    );
  }

  _SessionSnapshot _buildSeededFinalSnapshot() {
    return const _SessionSnapshot(
      stage: VideoSummaryStage.finalChat,
      uploadHighlighted: true,
      processingExpanded: false,
      isTimestampScoped: false,
      selectedTimestampStartSeconds: 310,
      selectedTimestampEndSeconds: 420,
      preferenceText: '重点保留行动建议与里程碑。',
      draftBodyText: '产品方案讲解已经覆盖目标问题、用户路径和价值验证。',
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
    );
  }

  int get _videoDurationInSeconds => _parseVideoDurationLabel(_videoAsset.durationLabel);

  _TimestampRange _buildDefaultTimestampRange() {
    final total = _videoDurationInSeconds;
    final defaultLength = total >= 30 ? 30 : total;
    final safeLength = defaultLength >= _minimumTimestampRangeSeconds
        ? defaultLength
        : _minimumTimestampRangeSeconds;
    final end = safeLength.clamp(
      _minimumTimestampRangeSeconds,
      total,
    );
    return _TimestampRange(startSeconds: 0, endSeconds: end);
  }

  _TimestampRange _buildRangeFromSummary(FinalSummaryData summary) {
    final seeded = summary.timestampChips.isNotEmpty
        ? _tryParseTimestampRange(summary.timestampChips.first.label)
        : _tryParseTimestampRange(summary.summaryTimestampLabel);
    return _sanitizeTimestampRange(seeded ?? _buildDefaultTimestampRange());
  }

  _TimestampRange _sanitizeTimestampRange(_TimestampRange range) {
    final total = _videoDurationInSeconds;
    final maxStart = (total - _minimumTimestampRangeSeconds).clamp(0, total);
    final start = range.startSeconds.clamp(0, maxStart);
    final minEnd = (start + _minimumTimestampRangeSeconds).clamp(
      _minimumTimestampRangeSeconds,
      total,
    );
    final end = range.endSeconds.clamp(minEnd, total);
    return _TimestampRange(startSeconds: start, endSeconds: end);
  }

  _TimestampRange? _tryParseTimestampRange(String raw) {
    final matches = RegExp(r'(\d{2}:\d{2}(?::\d{2})?)').allMatches(raw).toList();
    if (matches.length < 2) {
      return null;
    }

    final start = _parseClockLabel(matches.first.group(0)!);
    final end = _parseClockLabel(matches[1].group(0)!);
    if (end - start < _minimumTimestampRangeSeconds) {
      return null;
    }

    return _TimestampRange(startSeconds: start, endSeconds: end);
  }

  int _parseClockLabel(String value) {
    final parts = value.split(':').map(int.parse).toList();
    if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  int _parseVideoDurationLabel(String label) {
    final compact = label.trim();
    if (compact.contains(':')) {
      return _parseClockLabel(compact);
    }

    final minuteMatch = RegExp(r'(\d+)\s*m').firstMatch(compact);
    final secondMatch = RegExp(r'(\d+)\s*s').firstMatch(compact);
    final minutes = int.tryParse(minuteMatch?.group(1) ?? '0') ?? 0;
    final seconds = int.tryParse(secondMatch?.group(1) ?? '0') ?? 0;
    final total = minutes * 60 + seconds;
    return total >= _minimumTimestampRangeSeconds
        ? total
        : _minimumTimestampRangeSeconds;
  }

  String _formatTimestampRange(int startSeconds, int endSeconds) {
    return '${_formatClock(startSeconds)} - ${_formatClock(endSeconds)}';
  }

  String _formatClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SessionHistoryEntry {
  const _SessionHistoryEntry({
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
  final _SessionSnapshot snapshot;

  _SessionHistoryEntry copyWith({
    String? id,
    String? title,
    String? durationLabel,
    String? detail,
    _SessionSnapshot? snapshot,
  }) {
    return _SessionHistoryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      durationLabel: durationLabel ?? this.durationLabel,
      detail: detail ?? this.detail,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class _SessionSnapshot {
  const _SessionSnapshot({
    required this.stage,
    required this.uploadHighlighted,
    required this.processingExpanded,
    required this.isTimestampScoped,
    required this.selectedTimestampStartSeconds,
    required this.selectedTimestampEndSeconds,
    required this.preferenceText,
    required this.draftBodyText,
    required this.isDraftEditMode,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
  });

  final VideoSummaryStage stage;
  final bool uploadHighlighted;
  final bool processingExpanded;
  final bool isTimestampScoped;
  final int selectedTimestampStartSeconds;
  final int selectedTimestampEndSeconds;
  final String preferenceText;
  final String draftBodyText;
  final bool isDraftEditMode;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
}

class _TimestampRange {
  const _TimestampRange({
    required this.startSeconds,
    required this.endSeconds,
  });

  final int startSeconds;
  final int endSeconds;
}
