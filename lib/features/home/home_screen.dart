import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/widgets/app_bottom_nav.dart';
import 'application/video_summary_flow_controller.dart';
import 'application/video_summary_session_history_controller.dart';
import 'application/video_summary_settings_controller.dart';
import 'application/video_summary_text_editing_controller.dart';
import 'video_summary_models.dart';
import 'widgets/home_shell_widgets.dart';
import 'widgets/session_settings_sheet.dart';
import 'widgets/video_summary_content_widgets.dart';
import 'widgets/video_summary_drawer_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(videoSummaryFlowControllerProvider);
    final sessionHistory = ref.watch(videoSummarySessionHistoryProvider);
    final textEditing = ref.watch(videoSummaryTextEditingControllerProvider);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawerEnableOpenDragGesture: true,
      drawer: VideoSummaryHistoryDrawer(
        sessions: sessionHistory.sessions
            .map(
              (session) => VideoSummaryDrawerSessionItem(
                id: session.id,
                title: session.title,
                durationLabel: session.durationLabel,
                detail: session.detail,
                isActive: session.id == sessionHistory.activeSessionId,
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
                  child: flowState.stage == VideoSummaryStage.ready
                      ? Column(
                          children: [
                            const Spacer(flex: 5),
                            _buildWorkspace(flowState, textEditing),
                            const Spacer(flex: 4),
                          ],
                        )
                      : SingleChildScrollView(
                          child: _buildWorkspace(flowState, textEditing),
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
        AppNavigator.goToKnowledgeBaseHome(context);
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
    final flowController = ref.read(videoSummaryFlowControllerProvider.notifier);
    final sessionHistoryController = ref.read(
      videoSummarySessionHistoryProvider.notifier,
    );
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    textEditing.runWithoutSync(() {
      textEditing.clearForNewSession();
      flowController.reset();
      sessionHistoryController.createNewSession(textEditing.captureSnapshot());
    });
  }

  void _createNewSessionFromDrawer() {
    AppNavigator.popCurrent(context);
    _createNewSession();
  }

  void _restoreSessionFromDrawer(String sessionId) {
    final session = ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .getSessionById(sessionId);
    if (session == null) {
      return;
    }

    AppNavigator.popCurrent(context);
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    textEditing.runWithoutSync(() {
      textEditing.applySessionSnapshot(session.snapshot);
      ref.read(videoSummaryFlowControllerProvider.notifier).restoreSnapshot(
        session.snapshot.flowSnapshot,
      );
      ref.read(videoSummarySessionHistoryProvider.notifier).activateSession(
        session.id,
      );
    });
  }

  Future<void> _openSettingsFromDrawer() async {
    final settingsState = ref.read(videoSummarySettingsProvider);
    final settingsController = ref.read(videoSummarySettingsProvider.notifier);
    AppNavigator.popCurrent(context);
    await showSessionSettingsSheet(
      context: context,
      defaultTimestampScoped: settingsState.defaultTimestampScoped,
      defaultProcessingExpanded: settingsState.defaultProcessingExpanded,
      onDefaultTimestampScopedChanged:
          settingsController.setDefaultTimestampScoped,
      onDefaultProcessingExpandedChanged:
          settingsController.setDefaultProcessingExpanded,
    );
  }

  Future<void> _generateFinalSummary() {
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    return ref.read(videoSummaryFlowControllerProvider.notifier).generateFinalSummary(
      guidance: textEditing.preferenceText.trim(),
      draftBodyText: textEditing.draftBodyText,
    );
  }

  Future<void> _sendChatMessage() async {
    final textEditing = ref.read(videoSummaryTextEditingControllerProvider);
    final message = textEditing.consumeChatMessage();
    if (message == null) {
      return;
    }

    await ref.read(videoSummaryFlowControllerProvider.notifier).sendChatMessage(
      message,
    );
  }

  VideoSummaryWorkspace _buildWorkspace(
    VideoSummaryFlowState flowState,
    VideoSummaryTextEditingController textEditing,
  ) {
    return VideoSummaryWorkspace(
      stage: flowState.stage,
      highlighted: flowState.uploadHighlighted,
      videoAsset: flowState.videoAsset,
      processingSnapshot: flowState.processingSnapshot,
      draftResult: flowState.draftResult,
      finalSummaryData: flowState.finalSummaryData,
      chatMessages: flowState.chatMessages,
      preferenceController: textEditing.preferenceController,
      chatController: textEditing.chatController,
      draftBodyController: textEditing.draftBodyController,
      processingExpanded: flowState.processingExpanded,
      isDraftEditMode: flowState.isDraftEditMode,
      isGenerating: flowState.isGenerating,
      isSendingChat: flowState.isSendingChat,
      isTimestampScoped: flowState.isTimestampScoped,
      selectedTimestampLabel:
          ref.read(videoSummaryFlowControllerProvider.notifier).selectedTimestampLabel,
      totalDurationSeconds:
          ref.read(videoSummaryFlowControllerProvider.notifier).videoDurationInSeconds,
      selectedTimestampStartSeconds: flowState.selectedTimestampStartSeconds,
      selectedTimestampEndSeconds: flowState.selectedTimestampEndSeconds,
      onUploadCardPressed:
          ref.read(videoSummaryFlowControllerProvider.notifier).toggleUploadSelection,
      onProcessingCardPressed:
          ref.read(videoSummaryFlowControllerProvider.notifier).toggleProcessingExpanded,
      onDraftEditModeChanged:
          ref.read(videoSummaryFlowControllerProvider.notifier).setDraftEditMode,
      onStartPressed: flowState.isGenerating
          ? null
          : ref.read(videoSummaryFlowControllerProvider.notifier).startDraftGeneration,
      onGenerateFinalPressed:
          flowState.isGenerating ? null : _generateFinalSummary,
      onSendChatPressed: flowState.isSendingChat ? null : _sendChatMessage,
      onTimestampScopeChanged:
          ref.read(videoSummaryFlowControllerProvider.notifier).setTimestampScope,
      onTimestampRangeChanged:
          ref.read(videoSummaryFlowControllerProvider.notifier).setTimestampRange,
    );
  }
}
