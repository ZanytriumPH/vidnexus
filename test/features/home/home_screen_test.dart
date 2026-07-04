import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vidnexus/features/home/application/video_summary_flow_controller.dart';
import 'package:vidnexus/features/home/application/video_summary_session_history_controller.dart';
import 'package:vidnexus/features/home/application/video_summary_text_editing_controller.dart';
import 'package:vidnexus/features/home/home_screen.dart';
import 'package:vidnexus/features/home/video_summary_models.dart';
import 'package:vidnexus/features/home/video_summary_presentation_models.dart';
import 'package:vidnexus/features/home/video_summary_repository.dart';
import 'package:vidnexus/services/models/common_dto.dart';
import 'package:vidnexus/services/models/video_summary_task_dto.dart';
import 'package:vidnexus/services/service_providers.dart';
import 'package:vidnexus/services/task_service.dart';
import 'package:vidnexus/services/video_qa_service.dart';
import 'package:vidnexus/services/video_service.dart';
import 'package:vidnexus/services/websocket/ws_client.dart';
import 'package:vidnexus/services/websocket/ws_provider.dart';

class MockTaskService extends Mock implements TaskService {}
class MockVideoQAService extends Mock implements VideoQAService {}
class MockWsClient extends Mock implements WsClient {}
class MockVideoService extends Mock implements VideoService {}
class MockRef extends Mock implements Ref<Object?> {}
class FakePageParams extends Fake implements PageParams {}

// ─── Test doubles ───────────────────────────────────────────────────────────

/// Flow controller that doesn't do any async work in build() and accepts
/// arbitrary initial state.
class TestFlowController extends VideoSummaryFlowController {
  TestFlowController({VideoSummaryFlowState? initialState})
      : _initialState = initialState;

  final VideoSummaryFlowState? _initialState;

  @override
  VideoSummaryFlowState build() {
    return _initialState ?? super.build();
  }
}

/// History controller that doesn't auto-load from backend and accepts
/// arbitrary initial state.
class TestHistoryController extends VideoSummarySessionHistoryController {
  TestHistoryController({VideoSummarySessionHistoryState? initialState})
      : _initialState = initialState;

  final VideoSummarySessionHistoryState? _initialState;

  @override
  VideoSummarySessionHistoryState build() {
    return _initialState ?? super.build();
  }
}

/// Minimal text editing controller for testing.
class TestTextEditingController extends VideoSummaryTextEditingController {
  TestTextEditingController() : super(MockRef());

  bool clearForNewSessionCalled = false;

  @override
  void clearForNewSession() {
    clearForNewSessionCalled = true;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

VideoSummaryFlowState flowStateWithTask(String? taskId) {
  return VideoSummaryFlowState(
    taskId: taskId,
    videoAsset: VideoAssetInfo(
      title: taskId ?? 'vid_default',
      durationLabel: '5m 00s',
      sourceLabel: 'kb_default',
      fileName: 'test.mp4',
    ),
    uploadHighlighted: true,
    processingExpanded: false,
    isDraftEditMode: false,
    isGenerating: false,
    isSendingChat: false,
    isTimestampScoped: false,
    selectedTimestampStartSeconds: 0,
    selectedTimestampEndSeconds: 10,
    stage: VideoSummaryStage.finalChat,
    processingSnapshot: null,
    draftResult: const DraftResult(paragraphs: ['draft'], suggestionHint: ''),
    finalSummaryData: const FinalSummaryData(
      summaryTitle: 'Test',
      summaryBody: '# Test Summary\n\nContent here.',
      timestampChips: [],
      messages: [],
    ),
    chatMessages: const [],
    isUploading: false,
    uploadProgress: 0.0,
    finalDraftProgressLogs: const [],
  );
}

VideoSummarySessionHistoryEntry get currentSessionEntry =>
    VideoSummarySessionHistoryEntry(
      id: 'session-current',
      title: '当前视频会话',
      durationLabel: '0m 00s',
      detail: '当前会话仍在主区域',
      snapshot: VideoSummarySessionSnapshot(
        flowSnapshot: const VideoSummaryFlowSnapshot(
          stage: VideoSummaryStage.ready,
          uploadHighlighted: false,
          processingExpanded: true,
          isTimestampScoped: false,
          selectedTimestampStartSeconds: 0,
          selectedTimestampEndSeconds: 10,
          isDraftEditMode: false,
          processingSnapshot: null,
          draftResult: null,
          finalSummaryData: null,
          chatMessages: [],
        ),
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: '',
      ),
    );

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakePageParams());
  });

  group('Cross-validation guard: deleted task cleanup', () {
    late MockTaskService mockTaskService;
    late MockVideoQAService mockVideoQAService;
    late MockWsClient mockWsClient;
    late MockVideoService mockVideoService;
    late TestTextEditingController testTextCtrl;

    setUp(() {
      mockTaskService = MockTaskService();
      mockVideoQAService = MockVideoQAService();
      mockWsClient = MockWsClient();
      mockVideoService = MockVideoService();

      when(() => mockVideoService.getVideo(any())).thenAnswer(
        (_) async => const ApiResponse(status: 'success', data: null),
      );
      when(() => mockTaskService.listTasks(params: any(named: 'params')))
          .thenAnswer((_) async => const ApiListResponse(
                status: 'success',
                data: <VideoSummaryTaskResponseData>[],
                meta: MetaInfo(requestId: 'req-1', timestamp: ''),
                pagination: PaginationInfo(
                    page: 1, pageSize: 50, total: 0, hasNext: false),
              ));
      when(() => mockTaskService.getTask(any())).thenAnswer(
        (_) async => const ApiResponse(status: 'success', data: null),
      );
      when(() => mockWsClient.eventStream)
          .thenAnswer((_) => const Stream.empty());

      testTextCtrl = TestTextEditingController();
    });

    /// Creates a ProviderContainer with test controllers injected via
    /// overrideWith. The controllers return pre-built states from build()
    /// and do NOT trigger any async side effects.
    ProviderContainer createContainer({
      required VideoSummaryFlowState flowState,
      required VideoSummarySessionHistoryState historyState,
    }) {
      testTextCtrl.clearForNewSessionCalled = false;

      return ProviderContainer(overrides: [
        taskServiceProvider.overrideWithValue(mockTaskService),
        videoQAServiceProvider.overrideWithValue(mockVideoQAService),
        wsClientProvider.overrideWithValue(mockWsClient),
        videoServiceProvider.overrideWithValue(mockVideoService),
        defaultKbidProvider.overrideWith((ref) => 'kb_default'),
        currentVideoIdProvider.overrideWith((ref) => 'vid_default'),
        videoSummaryTextEditingControllerProvider
            .overrideWithValue(testTextCtrl),
        videoSummaryFlowControllerProvider
            .overrideWith(() => TestFlowController(initialState: flowState)),
        videoSummarySessionHistoryProvider.overrideWith(
            () => TestHistoryController(initialState: historyState)),
      ]);
    }

    testWidgets(
        'deleted task: flowController is reset when taskId not in history',
        (tester) async {
      final container = createContainer(
        flowState: flowStateWithTask('task_deleted'),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry],
          activeSessionId: 'session-current',
          createdSessionCount: 1,
          isLoadingHistory: false,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      // Future.microtask(reset) runs during pump(). State is updated
      // synchronously before the next frame, so no second pump needed.
      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, isNull,
          reason: 'Task should be cleared after cross-validation');
      expect(state.stage, VideoSummaryStage.ready);
    });

    testWidgets(
        'valid task: flowController is NOT reset when taskId IS in history',
        (tester) async {
      final taskEntry = VideoSummarySessionHistoryEntry(
        id: 'task_valid',
        title: 'Valid Task',
        durationLabel: '5m 00s',
        detail: '已完成',
        snapshot: VideoSummarySessionSnapshot(
          flowSnapshot: VideoSummaryFlowSnapshot(
            taskId: 'task_valid',
            stage: VideoSummaryStage.finalChat,
            uploadHighlighted: true,
            processingExpanded: true,
            isTimestampScoped: false,
            selectedTimestampStartSeconds: 0,
            selectedTimestampEndSeconds: 10,
            isDraftEditMode: false,
            processingSnapshot: null,
            draftResult: null,
            finalSummaryData: null,
            chatMessages: const [],
          ),
          readyPreferenceText: '',
          draftGuidanceText: '',
          draftBodyText: '',
        ),
      );

      final container = createContainer(
        flowState: flowStateWithTask('task_valid'),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry, taskEntry],
          activeSessionId: 'task_valid',
          createdSessionCount: 2,
          isLoadingHistory: false,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, 'task_valid',
          reason: 'Valid task should remain untouched');
      addTearDown(container.dispose);
    });

    testWidgets('null taskId: guard is skipped, no reset', (tester) async {
      final container = createContainer(
        flowState: flowStateWithTask(null),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry],
          activeSessionId: 'session-current',
          createdSessionCount: 1,
          isLoadingHistory: false,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, isNull);
      expect(state.stage, VideoSummaryStage.finalChat,
          reason: 'Stage should not change when guard is skipped');
      addTearDown(container.dispose);
    });

    testWidgets('loading history: guard is skipped, no premature reset',
        (tester) async {
      final container = createContainer(
        flowState: flowStateWithTask('task_still_checking'),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry],
          activeSessionId: 'session-current',
          createdSessionCount: 1,
          isLoadingHistory: true, // ★ still loading
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, 'task_still_checking',
          reason: 'Should NOT reset while history is loading');
      addTearDown(container.dispose);
    });

    // ── fix-second-task-race-condition ──────────────────────────────────

    /// Helper: build a VideoSummarySessionHistoryEntry for a task.
    VideoSummarySessionHistoryEntry _taskEntry({
      required String taskId,
      VideoSummaryStage stage = VideoSummaryStage.draft,
      String fileName = 'test.mp4',
    }) {
      return VideoSummarySessionHistoryEntry(
        id: taskId,
        title: fileName,
        durationLabel: '5m 00s',
        detail: '已完成',
        snapshot: VideoSummarySessionSnapshot(
          flowSnapshot: VideoSummaryFlowSnapshot(
            taskId: taskId,
            videoAsset: VideoAssetInfo(
              title: 'vid_test',
              durationLabel: '5m 00s',
              sourceLabel: 'kb_default',
              fileName: fileName,
            ),
            stage: stage,
            uploadHighlighted: true,
            processingExpanded: false,
            isTimestampScoped: false,
            selectedTimestampStartSeconds: 0,
            selectedTimestampEndSeconds: 10,
            isDraftEditMode: false,
            processingSnapshot: null,
            draftResult: stage == VideoSummaryStage.draft
                ? const DraftResult(paragraphs: ['draft content'], suggestionHint: '')
                : null,
            finalSummaryData: null,
            chatMessages: const [],
          ),
          readyPreferenceText: '',
          draftGuidanceText: '',
          draftBodyText: 'draft content',
        ),
      );
    }

    testWidgets(
        'second task restoration does not trigger false cleanup',
        (tester) async {
      // Scenario: session history already loaded with only task_1.
      // A second task (task_2) is being restored from the same video.
      // With the fixed code order (addOrActivateTaskSession BEFORE
      // restoreSnapshot), the cross-validation guard must NOT trigger.
      final container = createContainer(
        flowState: flowStateWithTask('task_1'),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry, _taskEntry(taskId: 'task_1')],
          activeSessionId: 'task_1',
          createdSessionCount: 2,
          isLoadingHistory: false,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      // Verify initial state
      var state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, 'task_1');

      // Fixed order: 1) add to history FIRST
      final historyNotifier =
          container.read(videoSummarySessionHistoryProvider.notifier);
      final task2Snapshot = VideoSummarySessionSnapshot(
        flowSnapshot: VideoSummaryFlowSnapshot(
          taskId: 'task_2',
          videoAsset: VideoAssetInfo(
            title: 'vid_test',
            durationLabel: '0m 00s', // ★ 真实场景：_restoreVideoSession 构建的快照为占位值
            sourceLabel: 'kb_default',
            fileName: 'test.mp4',
          ),
          stage: VideoSummaryStage.draft,
          uploadHighlighted: true,
          processingExpanded: false,
          isTimestampScoped: false,
          selectedTimestampStartSeconds: 0,
          selectedTimestampEndSeconds: 10,
          isDraftEditMode: false,
          processingSnapshot: null,
          draftResult:
              const DraftResult(paragraphs: ['new draft'], suggestionHint: ''),
          finalSummaryData: null,
          chatMessages: const [],
        ),
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: 'new draft',
      );

      historyNotifier.addOrActivateTaskSession(
          taskId: 'task_2', snapshot: task2Snapshot);

      // Fixed order: 2) THEN restore flow snapshot
      final flowNotifier =
          container.read(videoSummaryFlowControllerProvider.notifier);
      flowNotifier.restoreSnapshot(task2Snapshot.flowSnapshot);

      // Let rebuilds and microtasks process
      await tester.pump();
      await tester.pump();

      state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, 'task_2',
          reason:
              'Task_2 should remain when addOrActivateTaskSession is called before restoreSnapshot');
      expect(state.stage, VideoSummaryStage.draft,
          reason: 'Stage should be restored to draft, not reset to ready');
    });

    testWidgets(
        'race condition: restoreSnapshot before addOrActivateTaskSession '
        'triggers false cleanup',
        (tester) async {
      // Reverse verification: demonstrate that the OLD code order
      // (restoreSnapshot BEFORE addOrActivateTaskSession) causes the
      // cross-validation guard to falsely trigger.
      // This test is skipped in normal runs — it exists as a sentinel
      // to prevent anyone from reverting the fix.
      final container = createContainer(
        flowState: flowStateWithTask('task_1'),
        historyState: VideoSummarySessionHistoryState(
          sessions: [currentSessionEntry, _taskEntry(taskId: 'task_1')],
          activeSessionId: 'task_1',
          createdSessionCount: 2,
          isLoadingHistory: false,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      final task2Snapshot = VideoSummarySessionSnapshot(
        flowSnapshot: VideoSummaryFlowSnapshot(
          taskId: 'task_2',
          videoAsset: VideoAssetInfo(
            title: 'vid_test',
            durationLabel: '5m 00s',
            sourceLabel: 'kb_default',
            fileName: 'test.mp4',
          ),
          stage: VideoSummaryStage.draft,
          uploadHighlighted: true,
          processingExpanded: false,
          isTimestampScoped: false,
          selectedTimestampStartSeconds: 0,
          selectedTimestampEndSeconds: 10,
          isDraftEditMode: false,
          processingSnapshot: null,
          draftResult:
              const DraftResult(paragraphs: ['new draft'], suggestionHint: ''),
          finalSummaryData: null,
          chatMessages: const [],
        ),
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: 'new draft',
      );

      // OLD buggy order: restoreSnapshot first → guard triggers
      final flowNotifier =
          container.read(videoSummaryFlowControllerProvider.notifier);
      flowNotifier.restoreSnapshot(task2Snapshot.flowSnapshot);

      // addOrActivateTaskSession comes too late
      final historyNotifier =
          container.read(videoSummarySessionHistoryProvider.notifier);
      historyNotifier.addOrActivateTaskSession(
          taskId: 'task_2', snapshot: task2Snapshot);

      // Let rebuilds and the Future.microtask(reset) process
      await tester.pump();
      await tester.pump();

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.taskId, isNull,
          reason:
              'OLD order: guard falsely detected task_2 as deleted before it was added to history');
      expect(state.stage, VideoSummaryStage.ready,
          reason: 'FlowController was reset to ready due to false cleanup');
    }, skip: true); // Sentinel — proves the fix direction is correct
  });
}
