import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vidnexus/features/home/application/video_summary_flow_controller.dart';
import 'package:vidnexus/features/home/application/video_summary_session_history_controller.dart';
import 'package:vidnexus/features/home/application/video_summary_text_editing_controller.dart';
import 'package:vidnexus/features/home/video_summary_repository.dart';
import 'package:vidnexus/features/home/video_summary_models.dart';
import 'package:vidnexus/services/task_service.dart';
import 'package:vidnexus/services/video_qa_service.dart';
import 'package:vidnexus/services/video_service.dart';
import 'package:vidnexus/services/websocket/ws_client.dart';
import 'package:vidnexus/services/websocket/ws_provider.dart';
import 'package:vidnexus/services/service_providers.dart';
import 'package:vidnexus/services/models/common_dto.dart';
import 'package:vidnexus/services/models/video_resource_dto.dart';
import 'package:vidnexus/services/models/video_summary_task_dto.dart';

class MockTaskService extends Mock implements TaskService {}
class MockVideoQAService extends Mock implements VideoQAService {}
class MockWsClient extends Mock implements WsClient {}
class MockVideoService extends Mock implements VideoService {}

class FakePageParams extends Fake implements PageParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePageParams());
  });

  group('Session History Loss Debug Test with Rebuilt Repo', () {
    late MockTaskService mockTaskService;
    late MockVideoQAService mockVideoQAService;
    late MockWsClient mockWsClient;
    late ProviderContainer container;

    setUp(() {
      mockTaskService = MockTaskService();
      mockVideoQAService = MockVideoQAService();
      mockWsClient = MockWsClient();
      final mockVideoService = MockVideoService();

      // Stub getVideo for any videoId to avoid real HTTP calls in _loadFromBackend.
      when(() => mockVideoService.getVideo(any())).thenAnswer(
        (_) async => ApiResponse(
          status: 'success',
          data: VideoResourceResponseData(
            videoId: 'vid_persistent_1',
            ownerId: 'owner-1',
            fileName: 'test_video.mp4',
            duration: 120,
          ),
        ),
      );

      // Stub default KB responses and task status
      when(() => mockTaskService.listTasks(
        params: any(named: 'params'),
      )).thenAnswer(
        (_) async => ApiListResponse(
          status: 'success',
          data: <VideoSummaryTaskResponseData>[
            const VideoSummaryTaskResponseData(
              taskId: 'task_persistent_1',
              kbid: 'kb_default',
              videoId: 'vid_persistent_1',
              workflowState: 'WAITING_USER_APPROVAL',
              draftSummary: 'Draft summary text',
              createdAt: '2026-06-06T12:00:00Z',
              updatedAt: '2026-06-06T12:00:00Z',
            ),
          ],
          meta: MetaInfo(requestId: 'req-1', timestamp: '2026-06-06T12:00:00Z'),
          pagination: const PaginationInfo(page: 1, pageSize: 50, total: 1, hasNext: false),
        ),
      );

      when(() => mockTaskService.getTask(any())).thenAnswer(
        (_) async => ApiResponse(
          status: 'success',
          data: const VideoSummaryTaskResponseData(
            taskId: 'task_persistent_1',
            kbid: 'kb_default',
            videoId: 'vid_persistent_1',
            workflowState: 'WAITING_USER_APPROVAL',
            draftSummary: 'Draft summary text',
            createdAt: '2026-06-06T12:00:00Z',
            updatedAt: '2026-06-06T12:00:00Z',
          ),
          meta: MetaInfo(requestId: 'req-2', timestamp: '2026-06-06T12:00:00Z'),
        ),
      );

      when(() => mockWsClient.eventStream).thenAnswer((_) => const Stream.empty());

      container = ProviderContainer(
        overrides: [
          taskServiceProvider.overrideWithValue(mockTaskService),
          videoQAServiceProvider.overrideWithValue(mockVideoQAService),
          wsClientProvider.overrideWithValue(mockWsClient),
          videoServiceProvider.overrideWithValue(mockVideoService),
          defaultKbidProvider.overrideWith((ref) => 'kb_default'),
        ],
      );
      addTearDown(container.dispose);
    });

    test('reproduces session loss when switching and repository rebuilds', () async {
      final historyNotifier = container.read(videoSummarySessionHistoryProvider.notifier);
      final flowNotifier = container.read(videoSummaryFlowControllerProvider.notifier);
      final textEditing = container.read(videoSummaryTextEditingControllerProvider);

      // Let history finish loading tasks from backend
      await Future.delayed(Duration.zero);
      expect(container.read(videoSummarySessionHistoryProvider).sessions.length, 2); // session-current, task_persistent_1

      // 2. Simulate video upload completion by restoring a flow snapshot
      final tempFlowSnapshot = VideoSummaryFlowSnapshot(
        taskId: null,
        videoAsset: const VideoAssetInfo(
          title: 'vid_temp_1',
          durationLabel: '1m 20s',
          sourceLabel: 'kb_default',
          fileName: 'temp_video.mp4',
        ),
        stage: VideoSummaryStage.ready,
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
      );
      
      container.read(currentVideoIdProvider.notifier).state = 'vid_temp_1';
      flowNotifier.restoreSnapshot(tempFlowSnapshot);

      final flowSnapshotBeforeReset = container.read(videoSummaryFlowControllerProvider.notifier).captureSnapshot();
      expect(flowSnapshotBeforeReset.videoAsset?.title, 'vid_temp_1');

      // Now add temporary session
      historyNotifier.addTempUploadSession(textEditing.captureSnapshot());

      var state = container.read(videoSummarySessionHistoryProvider);
      expect(state.activeSessionId, 'temp-vid_temp_1');
      expect(state.sessions.any((s) => s.id == 'temp-vid_temp_1'), isTrue);

      // 3. Click "New Session"
      // Simulate _createNewSession:
      historyNotifier.addTempUploadSession(textEditing.captureSnapshot());
      textEditing.clearForNewSession();
      flowNotifier.reset();

      // Verify state after reset
      state = container.read(videoSummarySessionHistoryProvider);
      expect(state.activeSessionId, 'session-current');
      expect(state.sessions.any((s) => s.id == 'temp-vid_temp_1'), isTrue, reason: 'Temp session should be in history after reset');

      // 4. Switch to a persistent session (task_persistent_1)
      final targetSession = historyNotifier.getSessionById('task_persistent_1')!;
      
      textEditing.runWithoutSync(() {
        historyNotifier.activateSession(targetSession.id);
        textEditing.applySessionSnapshot(targetSession.snapshot);
        flowNotifier.restoreSnapshot(targetSession.snapshot.flowSnapshot);
      });

      // Verify temp session is still in history list
      state = container.read(videoSummarySessionHistoryProvider);
      expect(state.sessions.any((s) => s.id == 'temp-vid_temp_1'), isTrue, reason: 'Temp session should NOT be lost after switching');
    });

    test('direct switch from temp session to persistent session causes session loss', () async {
      final historyNotifier = container.read(videoSummarySessionHistoryProvider.notifier);
      final flowNotifier = container.read(videoSummaryFlowControllerProvider.notifier);
      final textEditing = container.read(videoSummaryTextEditingControllerProvider);

      await Future.delayed(Duration.zero);
      expect(container.read(videoSummarySessionHistoryProvider).sessions.length, 2);

      // 1. Upload video and add temp session
      final tempFlowSnapshot = VideoSummaryFlowSnapshot(
        taskId: null,
        videoAsset: const VideoAssetInfo(
          title: 'vid_temp_1',
          durationLabel: '1m 20s',
          sourceLabel: 'kb_default',
          fileName: 'temp_video.mp4',
        ),
        stage: VideoSummaryStage.ready,
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
      );
      
      container.read(currentVideoIdProvider.notifier).state = 'vid_temp_1';
      flowNotifier.restoreSnapshot(tempFlowSnapshot);
      historyNotifier.addTempUploadSession(textEditing.captureSnapshot());

      var state = container.read(videoSummarySessionHistoryProvider);
      expect(state.activeSessionId, 'temp-vid_temp_1');
      expect(state.sessions.any((s) => s.id == 'temp-vid_temp_1'), isTrue);

      // 2. Direct switch to task_persistent_1 (WITHOUT reset() first!)
      final targetSession = historyNotifier.getSessionById('task_persistent_1')!;
      
      textEditing.runWithoutSync(() {
        historyNotifier.activateSession(targetSession.id);
        textEditing.applySessionSnapshot(targetSession.snapshot);
        flowNotifier.restoreSnapshot(targetSession.snapshot.flowSnapshot);
      });

      // Verify temp session is still in history list
      state = container.read(videoSummarySessionHistoryProvider);
      expect(state.sessions.any((s) => s.id == 'temp-vid_temp_1'), isTrue, reason: 'Temp session should NOT be lost after direct switch');
    });

    test('switching between temp sessions maintains their independent upload progress states', () async {
      final historyNotifier = container.read(videoSummarySessionHistoryProvider.notifier);
      final flowNotifier = container.read(videoSummaryFlowControllerProvider.notifier);
      final textEditing = container.read(videoSummaryTextEditingControllerProvider);

      await Future.delayed(Duration.zero);

      // Create Temp Session A (Vid A, uploading at 30%)
      final tempA = VideoSummaryFlowSnapshot(
        taskId: null,
        videoAsset: const VideoAssetInfo(
          title: 'vid_a',
          durationLabel: '0m 00s',
          sourceLabel: 'kb_default',
          fileName: 'video_a.mp4',
        ),
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
        chatMessages: const [],
        isUploading: true,
        uploadProgress: 0.3,
      );
      
      container.read(currentVideoIdProvider.notifier).state = 'vid_a';
      flowNotifier.restoreSnapshot(tempA);
      historyNotifier.addTempUploadSession(VideoSummarySessionSnapshot(
        flowSnapshot: tempA,
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: '',
      ));

      // Create Temp Session B (Vid B, uploading at 70%)
      final tempB = VideoSummaryFlowSnapshot(
        taskId: null,
        videoAsset: const VideoAssetInfo(
          title: 'vid_b',
          durationLabel: '0m 00s',
          sourceLabel: 'kb_default',
          fileName: 'video_b.mp4',
        ),
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
        chatMessages: const [],
        isUploading: true,
        uploadProgress: 0.7,
      );

      container.read(currentVideoIdProvider.notifier).state = 'vid_b';
      flowNotifier.restoreSnapshot(tempB);
      historyNotifier.addTempUploadSession(VideoSummarySessionSnapshot(
        flowSnapshot: tempB,
        readyPreferenceText: '',
        draftGuidanceText: '',
        draftBodyText: '',
      ));

      // 1. Switch back to Temp Session A
      final sessionA = historyNotifier.getSessionById('temp-vid_a')!;
      print('sessionA flowSnapshot title: ${sessionA.snapshot.flowSnapshot.videoAsset?.title}');
      textEditing.runWithoutSync(() {
        historyNotifier.activateSession(sessionA.id);
        textEditing.applySessionSnapshot(sessionA.snapshot);
        print('restoreSnapshot is about to be called with: ${sessionA.snapshot.flowSnapshot.videoAsset?.title}');
        flowNotifier.restoreSnapshot(sessionA.snapshot.flowSnapshot);
        print('flowState title immediately after restore: ${container.read(videoSummaryFlowControllerProvider).videoAsset.title}');
      });

      // Verify restored flowState progress is 30%
      var flowState = container.read(videoSummaryFlowControllerProvider);
      print('Restored flowState title: ${flowState.videoAsset.title}');
      expect(flowState.videoAsset.title, 'vid_a');
      expect(flowState.isUploading, isTrue);
      expect(flowState.uploadProgress, 0.3);

      // 2. Switch back to Temp Session B
      final sessionB = historyNotifier.getSessionById('temp-vid_b')!;
      textEditing.runWithoutSync(() {
        historyNotifier.activateSession(sessionB.id);
        textEditing.applySessionSnapshot(sessionB.snapshot);
        flowNotifier.restoreSnapshot(sessionB.snapshot.flowSnapshot);
      });

      // Verify restored flowState progress is 70%
      flowState = container.read(videoSummaryFlowControllerProvider);
      expect(flowState.videoAsset.title, 'vid_b');
      expect(flowState.isUploading, isTrue);
      expect(flowState.uploadProgress, 0.7);
    });
  });

  group('Sidebar stale tasks after KB deletion', () {
    late MockTaskService mockTaskService;
    late MockVideoQAService mockVideoQAService;
    late MockWsClient mockWsClient;
    late ProviderContainer container;

    /// Polls until the session history is no longer loading, or [maxTries] reached.
    Future<void> _waitForLoad(int maxTries) async {
      for (int i = 0; i < maxTries; i++) {
        if (!container.read(videoSummarySessionHistoryProvider).isLoadingHistory) {
          return;
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    setUp(() {
      mockTaskService = MockTaskService();
      mockVideoQAService = MockVideoQAService();
      mockWsClient = MockWsClient();
      final mockVideoService = MockVideoService();

      when(() => mockVideoService.getVideo(any())).thenAnswer(
        (_) async => ApiResponse(
          status: 'success',
          data: VideoResourceResponseData(
            videoId: 'vid_persistent_1',
            ownerId: 'owner-1',
            fileName: 'test_video.mp4',
            duration: 120,
          ),
        ),
      );

      when(() => mockTaskService.listTasks(
        params: any(named: 'params'),
      )).thenAnswer(
        (_) async => ApiListResponse(
          status: 'success',
          data: <VideoSummaryTaskResponseData>[
            const VideoSummaryTaskResponseData(
              taskId: 'task_persistent_1',
              kbid: 'kb_default',
              videoId: 'vid_persistent_1',
              workflowState: 'WAITING_USER_APPROVAL',
              draftSummary: 'Draft summary text',
              createdAt: '2026-06-06T12:00:00Z',
              updatedAt: '2026-06-06T12:00:00Z',
            ),
          ],
          meta: MetaInfo(requestId: 'req-1', timestamp: '2026-06-06T12:00:00Z'),
          pagination: const PaginationInfo(page: 1, pageSize: 50, total: 1, hasNext: false),
        ),
      );

      when(() => mockTaskService.getTask(any())).thenAnswer(
        (_) async => ApiResponse(
          status: 'success',
          data: const VideoSummaryTaskResponseData(
            taskId: 'task_persistent_1',
            kbid: 'kb_default',
            videoId: 'vid_persistent_1',
            workflowState: 'WAITING_USER_APPROVAL',
            draftSummary: 'Draft summary text',
            createdAt: '2026-06-06T12:00:00Z',
            updatedAt: '2026-06-06T12:00:00Z',
          ),
          meta: MetaInfo(requestId: 'req-2', timestamp: '2026-06-06T12:00:00Z'),
        ),
      );

      when(() => mockWsClient.eventStream).thenAnswer((_) => const Stream.empty());

      container = ProviderContainer(
        overrides: [
          taskServiceProvider.overrideWithValue(mockTaskService),
          videoQAServiceProvider.overrideWithValue(mockVideoQAService),
          wsClientProvider.overrideWithValue(mockWsClient),
          videoServiceProvider.overrideWithValue(mockVideoService),
          defaultKbidProvider.overrideWith((ref) => 'kb_default'),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build() triggers _loadAll when kbid is already AsyncData', () async {
      // Wait for the initial load to fully complete
      await _waitForLoad(20);
      final state = container.read(videoSummarySessionHistoryProvider);
      expect(state.isLoadingHistory, false);
      expect(state.sessions.length, 2); // session-current + task_persistent_1
      expect(state.sessions.any((s) => s.id == 'task_persistent_1'), isTrue);

      // Simulate KB deletion by invalidating the provider.
      // In the real app, deleteLibrary() calls ref.invalidate() while the user
      // is on the KB page. When they return to HomeScreen, build() runs fresh
      // and must trigger _loadAll() even though kbid is already AsyncData.
      container.invalidate(videoSummarySessionHistoryProvider);
      await _waitForLoad(20);

      final newState = container.read(videoSummarySessionHistoryProvider);
      expect(newState.isLoadingHistory, false,
          reason: 'Should finish loading after invalidation');
      expect(newState.sessions.length, 2,
          reason: 'Should reload backend data after invalidation');
      expect(
        newState.sessions.any((s) => s.id == 'task_persistent_1'),
        isTrue,
        reason: 'Backend task should appear in sidebar after fresh load',
      );
    });

    test('invalidated provider reflects deleted KB (backend returns no tasks)', () async {
      await _waitForLoad(20);
      expect(container.read(videoSummarySessionHistoryProvider).sessions.length, 2);

      // Update mock to simulate backend cascade-deleting tasks along with KB
      when(() => mockTaskService.listTasks(
        params: any(named: 'params'),
      )).thenAnswer(
        (_) async => ApiListResponse(
          status: 'success',
          data: <VideoSummaryTaskResponseData>[],
          meta: MetaInfo(requestId: 'req-3', timestamp: '2026-06-06T12:00:00Z'),
          pagination: const PaginationInfo(page: 1, pageSize: 50, total: 0, hasNext: false),
        ),
      );

      container.invalidate(videoSummarySessionHistoryProvider);
      await _waitForLoad(20);

      final state = container.read(videoSummarySessionHistoryProvider);
      expect(state.sessions.length, 1,
          reason: 'Only session-current should remain after KB cascade-deleted all tasks');
      expect(state.sessions.first.id, 'session-current');
      expect(state.isLoadingHistory, false);
    });

    test('_isLoadingAll guard prevents concurrent _loadFromBackend calls', () async {
      await _waitForLoad(20);

      // Reset the mock counter by setting up a new stub that tracks calls
      var callCount = 0;
      when(() => mockTaskService.listTasks(
        params: any(named: 'params'),
      )).thenAnswer((_) async {
        callCount++;
        // Small delay to simulate network latency and create a window for
        // concurrent calls to slip through without the guard
        await Future.delayed(const Duration(milliseconds: 50));
        return ApiListResponse(
          status: 'success',
          data: <VideoSummaryTaskResponseData>[],
          meta: MetaInfo(requestId: 'req-guard', timestamp: '2026-06-06T12:00:00Z'),
          pagination: const PaginationInfo(page: 1, pageSize: 50, total: 0, hasNext: false),
        );
      });

      final historyNotifier = container.read(videoSummarySessionHistoryProvider.notifier);

      // Fire two rapid retryLoadHistory calls — only one should reach the backend
      historyNotifier.retryLoadHistory();
      historyNotifier.retryLoadHistory();

      await _waitForLoad(20);

      expect(callCount, 1,
          reason: '_isLoadingAll guard should prevent duplicate concurrent API calls');
    });
  });
}
