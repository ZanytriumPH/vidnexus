import 'package:flutter/material.dart';

import 'video_summary_models.dart';
import 'video_summary_repository.dart';
import 'widgets/home_shell_widgets.dart';
import 'widgets/video_summary_content_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  static const routeName = '/';

  final VideoSummaryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _preferenceController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  bool _uploadHighlighted = false;
  bool _processingExpanded = true;
  bool _isGenerating = false;
  bool _isSendingChat = false;
  bool _isTimestampScoped = true;
  int _selectedTimestampIndex = 0;
  VideoSummaryStage _stage = VideoSummaryStage.ready;
  late final VideoAssetInfo _videoAsset;
  ProcessingSnapshot? _processingSnapshot;
  DraftResult? _draftResult;
  FinalSummaryData? _finalSummaryData;
  List<ChatMessage> _chatMessages = const [];

  @override
  void initState() {
    super.initState();
    _videoAsset = widget.repository.getVideoAsset();
  }

  @override
  void dispose() {
    _preferenceController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeaderRow(
                      onMenuPressed: () {},
                      onNewSessionPressed: _resetPageState,
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
                      processingExpanded: _processingExpanded,
                      isGenerating: _isGenerating,
                      isSendingChat: _isSendingChat,
                      isTimestampScoped: _isTimestampScoped,
                      selectedTimestampIndex: _selectedTimestampIndex,
                      onUploadCardPressed: _toggleUploadSelection,
                      onProcessingCardPressed: _toggleProcessingExpanded,
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
                        });
                      },
                      onTimestampSelected: (index) {
                        setState(() {
                          _selectedTimestampIndex = index;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: StageOneBottomNav(
                onKnowledgeBasePressed: () => _handleSectionSelection(
                  context,
                  StageOneNavSection.knowledgeBase,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSectionSelection(
    BuildContext context,
    StageOneNavSection section,
  ) {
    switch (section) {
      case StageOneNavSection.videoSummary:
        return;
      case StageOneNavSection.knowledgeBase:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('知识库模块仍保留占位，当前聚焦视频总结流程。')));
    }
  }

  void _resetPageState() {
    _preferenceController.clear();
    _chatController.clear();
    setState(() {
      _uploadHighlighted = false;
      _processingExpanded = true;
      _isGenerating = false;
      _isSendingChat = false;
      _isTimestampScoped = true;
      _selectedTimestampIndex = 0;
      _stage = VideoSummaryStage.ready;
      _processingSnapshot = null;
      _draftResult = null;
      _finalSummaryData = null;
      _chatMessages = const [];
    });
  }

  void _toggleUploadSelection() {
    setState(() {
      _uploadHighlighted = !_uploadHighlighted;
    });
  }

  void _toggleProcessingExpanded() {
    if (_stage != VideoSummaryStage.processing) {
      return;
    }

    setState(() {
      _processingExpanded = !_processingExpanded;
    });
  }

  Future<void> _startDraftGeneration() async {
    if (_isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _stage = VideoSummaryStage.processing;
      _processingExpanded = true;
      _processingSnapshot = null;
      _draftResult = null;
      _finalSummaryData = null;
      _chatMessages = const [];
    });

    try {
      await for (final snapshot in widget.repository.startDraftGeneration()) {
        if (!mounted) {
          return;
        }

        setState(() {
          _processingSnapshot = snapshot;
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
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _generateFinalSummary() async {
    final draft = _draftResult;
    if (_isGenerating || draft == null) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final summary = await widget.repository.generateFinalSummary(
        guidance: _preferenceController.text.trim(),
        draft: draft,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _finalSummaryData = summary;
        _chatMessages = List<ChatMessage>.from(summary.messages);
        _stage = VideoSummaryStage.finalChat;
        _selectedTimestampIndex = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
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
    });

    try {
      final reply = await widget.repository.sendSummaryChatMessage(text);
      if (!mounted) {
        return;
      }

      setState(() {
        _chatMessages = [..._chatMessages, reply];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingChat = false;
        });
      }
    }
  }
}
