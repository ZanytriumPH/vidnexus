import 'package:flutter/material.dart';

import '../../app/widgets/app_bottom_nav.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';
import '../knowledge_base/knowledge_base_home_screen.dart';
import 'widgets/home_shell_widgets.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _preferenceController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _draftBodyController = TextEditingController();

  bool _uploadHighlighted = false;
  bool _processingExpanded = true;
  bool _isDraftEditMode = true;
  bool _isGenerating = false;
  bool _isSendingChat = false;
  bool _isTimestampScoped = true;
  int _selectedTimestampIndex = 0;
  VideoSummaryStage _stage = VideoSummaryStage.ready;
  bool _defaultTimestampScoped = true;
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeHeaderRow(
                        onMenuPressed: _openDrawer,
                        onNewSessionPressed: _createNewSession,
                      ),
                      const SizedBox(height: 10),
                      VideoSummaryWorkspace(
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
                        selectedTimestampIndex: _selectedTimestampIndex,
                        onUploadCardPressed: _toggleUploadSelection,
                        onProcessingCardPressed: _toggleProcessingExpanded,
                        onDraftEditModeChanged: (value) {
                          setState(() {
                            _isDraftEditMode = value;
                            _syncActiveSession();
                          });
                        },
                        onStartPressed: _isGenerating
                            ? null
                            : _startDraftGeneration,
                        onGenerateFinalPressed: _isGenerating
                            ? null
                            : _generateFinalSummary,
                        onSendChatPressed: _isSendingChat
                            ? null
                            : _sendChatMessage,
                        onTimestampScopeChanged: (value) {
                          setState(() {
                            _isTimestampScoped = value;
                            _syncActiveSession();
                          });
                        },
                        onTimestampSelected: (index) {
                          setState(() {
                            _selectedTimestampIndex = index;
                            _syncActiveSession();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: AppBottomNav(
                  current: AppNavSection.videoSummary,
                  onSelected: (section) =>
                      _handleSectionSelection(context, section),
                ),
              ),
            ],
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
    _selectedTimestampIndex = 0;
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
        _selectedTimestampIndex = 0;
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
        _isTimestampScoped &&
            _finalSummaryData != null &&
            _finalSummaryData!.timestampChips.isNotEmpty
        ? _finalSummaryData!.timestampChips[_selectedTimestampIndex].label
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
        _chatMessages = [..._chatMessages, reply];
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '会话设置',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '这里控制新会话打开时的默认行为。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsTile(
                    title: '新会话默认开启时间戳追问',
                    subtitle: '进入最终稿后保留时间范围筛选开关。',
                    value: _defaultTimestampScoped,
                    onChanged: (value) {
                      setState(() {
                        _defaultTimestampScoped = value;
                      });
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    title: '处理中默认展开详细信息',
                    subtitle: '新会话进入处理中时自动展开步骤进度。',
                    value: _defaultProcessingExpanded,
                    onChanged: (value) {
                      setState(() {
                        _defaultProcessingExpanded = value;
                      });
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
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
      selectedTimestampIndex: _selectedTimestampIndex,
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
    _selectedTimestampIndex = snapshot.selectedTimestampIndex;
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
      selectedTimestampIndex: 0,
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
      selectedTimestampIndex: 0,
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
      isTimestampScoped: true,
      selectedTimestampIndex: 0,
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
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFD8DEE7),
            ),
          ),
        ],
      ),
    );
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
    required this.selectedTimestampIndex,
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
  final int selectedTimestampIndex;
  final String preferenceText;
  final String draftBodyText;
  final bool isDraftEditMode;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
}
