import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_buttons.dart';
import '../../app/widgets/app_card.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';

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
                    _HeaderRow(
                      onMenuPressed: () {},
                      onNewSessionPressed: _resetPageState,
                    ),
                    const SizedBox(height: 10),
                    _VideoSummaryWorkspace(
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
              child: _StageOneBottomNav(
                onKnowledgeBasePressed: () => _handleSectionSelection(
                  context,
                  _StageOneNavSection.knowledgeBase,
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
    _StageOneNavSection section,
  ) {
    switch (section) {
      case _StageOneNavSection.videoSummary:
        return;
      case _StageOneNavSection.knowledgeBase:
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
    setState(() {
      _stage = VideoSummaryStage.processing;
      _isGenerating = true;
      _processingExpanded = true;
      _uploadHighlighted = true;
      _processingSnapshot = null;
      _draftResult = null;
      _finalSummaryData = null;
      _chatMessages = const [];
    });

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
      _isGenerating = false;
      _processingExpanded = false;
    });
  }

  Future<void> _generateFinalSummary() async {
    final draft = _draftResult;
    if (draft == null) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final summary = await widget.repository.generateFinalSummary(
      guidance: _preferenceController.text.trim(),
      draft: draft,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _finalSummaryData = summary;
      _chatMessages = summary.messages;
      _selectedTimestampIndex = 0;
      _stage = VideoSummaryStage.finalChat;
      _isGenerating = false;
    });
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) {
      return;
    }

    setState(() {
      _isSendingChat = true;
      _chatMessages = [
        ..._chatMessages,
        ChatMessage(
          sender: SummaryChatSender.user,
          text: message,
          timestampLabel: _isTimestampScoped && _finalSummaryData != null
              ? _finalSummaryData!.timestampChips[_selectedTimestampIndex].label
              : null,
        ),
      ];
      _chatController.clear();
    });

    final reply = await widget.repository.sendSummaryChatMessage(message);
    if (!mounted) {
      return;
    }

    setState(() {
      _chatMessages = [..._chatMessages, reply];
      _isSendingChat = false;
    });
  }
}

class _VideoSummaryWorkspace extends StatelessWidget {
  const _VideoSummaryWorkspace({
    required this.stage,
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.draftResult,
    required this.finalSummaryData,
    required this.chatMessages,
    required this.preferenceController,
    required this.chatController,
    required this.processingExpanded,
    required this.isGenerating,
    required this.isSendingChat,
    required this.isTimestampScoped,
    required this.selectedTimestampIndex,
    required this.onUploadCardPressed,
    required this.onProcessingCardPressed,
    required this.onStartPressed,
    required this.onGenerateFinalPressed,
    required this.onSendChatPressed,
    required this.onTimestampScopeChanged,
    required this.onTimestampSelected,
  });

  final VideoSummaryStage stage;
  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final DraftResult? draftResult;
  final FinalSummaryData? finalSummaryData;
  final List<ChatMessage> chatMessages;
  final TextEditingController preferenceController;
  final TextEditingController chatController;
  final bool processingExpanded;
  final bool isGenerating;
  final bool isSendingChat;
  final bool isTimestampScoped;
  final int selectedTimestampIndex;
  final VoidCallback onUploadCardPressed;
  final VoidCallback onProcessingCardPressed;
  final VoidCallback? onStartPressed;
  final VoidCallback? onGenerateFinalPressed;
  final VoidCallback? onSendChatPressed;
  final ValueChanged<bool> onTimestampScopeChanged;
  final ValueChanged<int> onTimestampSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _HeroCard(
        stage: stage,
        highlighted: highlighted,
        videoAsset: videoAsset,
        processingSnapshot: processingSnapshot,
        processingExpanded: processingExpanded,
        onTap: stage == VideoSummaryStage.processing
            ? onProcessingCardPressed
            : onUploadCardPressed,
      ),
    ];

    if (stage == VideoSummaryStage.ready) {
      children.addAll([
        const SizedBox(height: 18),
        const _SectionLabel(title: '总结指导（可选）', centered: false),
        const SizedBox(height: 6),
        _PreferenceCard(
          controller: preferenceController,
          hintText: '例如：请先给我按行业、声线和行动建议展开。',
        ),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: isGenerating ? '正在生成中...' : '开始生成初稿',
          onPressed: onStartPressed,
        ),
      ]);
    }

    if (stage == VideoSummaryStage.processing && processingSnapshot != null) {
      children.addAll([
        const SizedBox(height: 12),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: processingExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _ProcessingDetailCard(snapshot: processingSnapshot!),
          secondChild: const _ProcessingCollapsedHintCard(),
        ),
      ]);
    }

    if (stage == VideoSummaryStage.draft && draftResult != null) {
      children.addAll([
        const SizedBox(height: 12),
        _DraftBodyCard(draft: draftResult!),
        const SizedBox(height: 10),
        const _SectionLabel(title: '总结指导（可选）', centered: false),
        const SizedBox(height: 6),
        _PreferenceCard(
          controller: preferenceController,
          hintText: draftResult!.suggestionHint,
          singleLine: true,
        ),
        const SizedBox(height: 14),
        AppPrimaryButton(
          label: isGenerating ? '正在整理最终稿...' : '生成最终稿',
          onPressed: onGenerateFinalPressed,
        ),
      ]);
    }

    if (stage == VideoSummaryStage.finalChat && finalSummaryData != null) {
      children.addAll([
        const SizedBox(height: 12),
        _FinalSummaryCard(summary: finalSummaryData!),
        const SizedBox(height: 10),
        _ChatThread(messages: chatMessages),
        const SizedBox(height: 10),
        const _MessageActionRow(),
        const SizedBox(height: 12),
        _TimestampSection(
          chips: finalSummaryData!.timestampChips,
          enabled: isTimestampScoped,
          selectedIndex: selectedTimestampIndex,
          onEnabledChanged: onTimestampScopeChanged,
          onSelected: onTimestampSelected,
        ),
        const SizedBox(height: 10),
        _ChatComposer(
          controller: chatController,
          isSending: isSendingChat,
          onSendPressed: onSendChatPressed,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.onMenuPressed,
    required this.onNewSessionPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onNewSessionPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _RoundGhostButton(
            size: 44,
            onPressed: onMenuPressed,
            child: const Icon(Icons.menu_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              '视频总结',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _RoundGhostButton(
            outlined: true,
            size: 35,
            onPressed: onNewSessionPressed,
            child: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.stage,
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.processingExpanded,
    required this.onTap,
  });

  final VideoSummaryStage stage;
  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final bool processingExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isProcessing = stage == VideoSummaryStage.processing;
    final bool isDraft = stage == VideoSummaryStage.draft;
    final bool isFinal = stage == VideoSummaryStage.finalChat;
    final String pillLabel = switch (stage) {
      VideoSummaryStage.ready => '本地上传',
      VideoSummaryStage.processing => processingSnapshot?.statusLabel ?? '处理中',
      VideoSummaryStage.draft => '处理已完成',
      VideoSummaryStage.finalChat => '终稿已生成',
    };
    final String title = switch (stage) {
      VideoSummaryStage.ready => '本地上传',
      VideoSummaryStage.processing => '正在生成结构化初稿',
      VideoSummaryStage.draft => '聚合稿已生成，处理详情已自动折叠',
      VideoSummaryStage.finalChat => '当前会话已切换为可追问对话窗口',
    };
    final String subtitle = switch (stage) {
      VideoSummaryStage.ready => '从设备选择文件',
      VideoSummaryStage.processing =>
        processingSnapshot?.etaLabel ?? '正在准备处理内容。',
      VideoSummaryStage.draft => '你现在可以调整偏好指令，再补充摘要层次。',
      VideoSummaryStage.finalChat => '先展示系统总结，再决定是否用时间范围追问。',
    };

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDE2FF), Color(0xFFE9F5FF)],
      ),
      borderColor: const Color(0xFFD3E7F8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusPill(label: pillLabel),
                const Spacer(),
                if (isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      processingExpanded ? '点击收起详情' : '点击展开详情',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: const Color(0xFF384A59),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            if (stage == VideoSummaryStage.ready)
              _WhiteButtonBar(
                label: highlighted ? '已选中 product-review.mp4' : '点击或拖拽视频到这里',
                leadingIcon: highlighted
                    ? Icons.check_circle_rounded
                    : Icons.add_rounded,
              ),
            if (isProcessing && processingSnapshot != null) ...[
              Text(
                '${videoAsset.fileName} · ${videoAsset.durationLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: const Color(0xFF51606D),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AnimatedProgressBar(
                      value: processingSnapshot!.progress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFD9EAF8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(processingSnapshot!.progress * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: processingSnapshot!.badges
                    .map((badge) => _ProcessingBadgeChip(badge: badge))
                    .toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    processingExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    processingExpanded
                        ? '点击蓝色卡片可收起详细处理信息'
                        : '点击蓝色卡片可展开详细处理信息',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (isDraft || isFinal)
              const _WhiteButtonBar(
                label: '视频回放',
                leadingIcon: Icons.play_arrow_rounded,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCFF),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _WhiteButtonBar extends StatelessWidget {
  const _WhiteButtonBar({required this.label, required this.leadingIcon});

  final String label;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4DCE5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(leadingIcon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingBadgeChip extends StatelessWidget {
  const _ProcessingBadgeChip({required this.badge});

  final ProcessingBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.active ? const Color(0xFF1F5BEA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.active
              ? const Color(0xFF1F5BEA)
              : const Color(0xFFD7E0E8),
        ),
      ),
      child: Text(
        badge.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: badge.active ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ProcessingDetailCard extends StatelessWidget {
  const _ProcessingDetailCard({required this.snapshot});

  final ProcessingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '详细处理信息',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '实时刷新',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '展开后显示实时任务进度',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          ...snapshot.steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProcessingStepTile(step: step),
            ),
          ),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '完成后自动进入总结草稿\n展示摘要、结构大纲和建议指令入口',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingCollapsedHintCard extends StatelessWidget {
  const _ProcessingCollapsedHintCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '详细处理信息已收起',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '点击上方蓝色卡片可再次展开，查看各步骤实时进度。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStepTile extends StatelessWidget {
  const _ProcessingStepTile({required this.step});

  final ProcessingStep step;

  @override
  Widget build(BuildContext context) {
    final progressValue = step.progress / 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '${step.progress}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _AnimatedProgressBar(
            value: progressValue,
            minHeight: 4,
            backgroundColor: const Color(0xFFE3E9EF),
          ),
          const SizedBox(height: 6),
          Text(
            step.detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
  });

  final double value;
  final double minHeight;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: safeValue),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              _progressColor(animatedValue),
            ),
          ),
        );
      },
    );
  }
}

Color _progressColor(double value) {
  final safeValue = value.clamp(0.0, 1.0);
  return Color.lerp(
        const Color(0xFFAED8FF),
        const Color(0xFF1F5BEA),
        safeValue,
      ) ??
      AppColors.primary;
}

class _DraftBodyCard extends StatelessWidget {
  const _DraftBodyCard({required this.draft});

  final DraftResult draft;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '聚合稿正文',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _MiniTab(active: true, label: '编辑'),
              const SizedBox(width: 6),
              const _MiniTab(active: false, label: '预览'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '可复制出口到其它模式，连续阅读再补上下文。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6DEE6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.paragraphs.join('\n\n'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.55),
                ),
                const SizedBox(height: 12),
                Text(
                  draft.overview,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '当前版本：结构稿',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
              ),
              const Spacer(),
              Text(
                '切换预览后自动接入几次指令细节层',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTab extends StatelessWidget {
  const _MiniTab({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1E2430) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _FinalSummaryCard extends StatelessWidget {
  const _FinalSummaryCard({required this.summary});

  final FinalSummaryData summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.summaryTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DFE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.summaryBody,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.55),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    summary.summaryTimestampLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatThread extends StatelessWidget {
  const _ChatThread({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages
          .map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: message.sender == SummaryChatSender.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: message.sender == SummaryChatSender.user ? 290 : 320,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD7DFE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                      if (message.timestampLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          message.timestampLabel!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 9,
                                color: AppColors.textHint,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _ActionIconButton(icon: Icons.copy_all_outlined),
        SizedBox(width: 6),
        _ActionIconButton(icon: Icons.note_alt_outlined),
        SizedBox(width: 6),
        _ActionIconButton(icon: Icons.image_outlined),
        SizedBox(width: 6),
        _ActionIconButton(icon: Icons.photo_outlined),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    );
  }
}

class _TimestampSection extends StatelessWidget {
  const _TimestampSection({
    required this.chips,
    required this.enabled,
    required this.selectedIndex,
    required this.onEnabledChanged,
    required this.onSelected,
  });

  final List<TimestampChipData> chips;
  final bool enabled;
  final int selectedIndex;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '时间戳追问，发送时附加这段片段',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: enabled,
                onChanged: onEnabledChanged,
                activeTrackColor: const Color(0xFF2B63EB),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD8DEE7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled
              ? () => onSelected((selectedIndex + 1) % chips.length)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7DFE7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFD7DFE7)),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chips[selectedIndex].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FA8B7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSendPressed,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback? onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD7DFE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '继续追问这段总结...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSendPressed,
              padding: EdgeInsets.zero,
              icon: isSending
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.centered});

  final String title;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.controller,
    required this.hintText,
    this.singleLine = false,
  });

  final TextEditingController controller;
  final String hintText;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        height: singleLine ? 50 : 86,
        child: TextField(
          controller: controller,
          maxLines: singleLine ? 1 : 4,
          minLines: singleLine ? 1 : 4,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textHint,
              height: 1.45,
            ),
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.45),
        ),
      ),
    );
  }
}

class _RoundGhostButton extends StatelessWidget {
  const _RoundGhostButton({
    required this.child,
    required this.onPressed,
    this.outlined = false,
    this.size = 44,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool outlined;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 2),
        side: outlined
            ? const BorderSide(color: AppColors.borderStrong)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

enum _StageOneNavSection { videoSummary, knowledgeBase }

class _StageOneBottomNav extends StatelessWidget {
  const _StageOneBottomNav({required this.onKnowledgeBasePressed});

  final VoidCallback onKnowledgeBasePressed;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE1E6EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F7),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 15),
                    const SizedBox(width: 6),
                    Text('视频总结', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onKnowledgeBasePressed,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmarks_outlined, size: 14),
                    const SizedBox(width: 6),
                    Text('知识库', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
