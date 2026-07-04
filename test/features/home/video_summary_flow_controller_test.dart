import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vidnexus/features/home/application/video_summary_flow_controller.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';
import 'package:vidnexus/features/home/video_summary_models.dart';
import 'package:vidnexus/features/home/video_summary_presentation_models.dart';
import 'package:vidnexus/features/home/video_summary_repository.dart';

// ---- Mocks ----

class MockVideoSummaryRepository extends Mock
    implements VideoSummaryRepository {}

// ---- Helpers ----

const _defaultVideoAsset = VideoAssetInfo(
  title: 'vid_test',
  durationLabel: '5m00s',
  sourceLabel: 'kb_test',
  fileName: 'test.mp4',
);

VideoSummaryFlowState _defaultState() => VideoSummaryFlowState.initial(
      videoAsset: _defaultVideoAsset,
    );

/// Creates a FlowController that returns [initialState] from build(),
/// bypassing the normal provider read chain.
class TestFlowController extends VideoSummaryFlowController {
  TestFlowController({VideoSummaryFlowState? initialState})
      : _initialState = initialState;

  final VideoSummaryFlowState? _initialState;

  @override
  VideoSummaryFlowState build() {
    return _initialState ?? super.build();
  }
}

void main() {
  late MockVideoSummaryRepository mockRepo;

  ProviderContainer createContainer({
    VideoSummaryFlowState? initialState,
  }) {
    final container = ProviderContainer(
      overrides: [
        videoSummaryRepositoryProvider.overrideWithValue(mockRepo),
        videoSummaryFlowControllerProvider.overrideWith(
          () => TestFlowController(initialState: initialState),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    mockRepo = MockVideoSummaryRepository();

    // Default stubs — build() calls these
    when(() => mockRepo.getVideoAsset()).thenReturn(_defaultVideoAsset);
    when(() => mockRepo.activeTaskId).thenReturn(null);
    when(() => mockRepo.kbid).thenReturn('kb_test');
    when(() => mockRepo.videoId).thenReturn('vid_test');
    when(() => mockRepo.kbName).thenReturn(null);

    // No-op for mutation methods
    when(() => mockRepo.updateTaskId(any())).thenReturn(null);
    when(() => mockRepo.updateVideoId(any())).thenReturn(null);
    when(() => mockRepo.updateKbid(any())).thenReturn(null);
  });

  // ──── generateFinalSummary ────

  group('generateFinalSummary', () {
    test('returns early when isGenerating is true', () async {
      final container = createContainer(
        initialState: _defaultState().copyWith(
          isGenerating: true,
          draftResult: const DraftResult(paragraphs: ['p'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      await ctrl.generateFinalSummary(
        guidance: 'test',
        draftBodyText: 'test',
      );

      verifyNever(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          ));
    });

    test('returns early when draftResult is null', () async {
      final container = createContainer(
        initialState: _defaultState().copyWith(draftResult: null),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      await ctrl.generateFinalSummary(
        guidance: 'test',
        draftBodyText: 'test',
      );

      verifyNever(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          ));
    });

    test('returns early when taskId is null (new guard)', () async {
      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: null,
          draftResult: const DraftResult(paragraphs: ['p'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      await ctrl.generateFinalSummary(
        guidance: 'test',
        draftBodyText: 'test',
      );

      verifyNever(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          ));
    });

    test('enters finalChat stage immediately and isGenerating=true', () async {
      final wsCompleter = Completer<VideoSummaryFinalResultData>();

      when(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          )).thenAnswer((_) => wsCompleter.future);

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_001',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['p'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      // Fire and let it reach the await
      final future = ctrl.generateFinalSummary(
        guidance: 'test',
        draftBodyText: 'test paragraph',
      );
      await Future.delayed(Duration.zero);

      final intermediate =
          container.read(videoSummaryFlowControllerProvider);
      expect(intermediate.stage, VideoSummaryStage.finalChat);
      expect(intermediate.isGenerating, isTrue);

      // Complete WS
      wsCompleter.complete(
        const VideoSummaryFinalResultData(body: 'final output', references: []),
      );
      await future;

      final finalState = container.read(videoSummaryFlowControllerProvider);
      expect(finalState.isGenerating, isFalse);
      expect(finalState.finalSummaryData, isNotNull);
      expect(finalState.finalSummaryData!.summaryBody, 'final output');
    });

    test('completes successfully with WS result', () async {
      when(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          )).thenAnswer((_) async =>
              const VideoSummaryFinalResultData(body: 'generated final', references: []));

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_002',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['p1'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      await ctrl.generateFinalSummary(
        guidance: 'improve it',
        draftBodyText: 'p1',
      );

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.stage, VideoSummaryStage.finalChat);
      expect(state.isGenerating, isFalse);
      expect(state.finalSummaryData!.summaryBody, 'generated final');
    });

    test('finally block clears isGenerating even when WS fails', () async {
      when(() => mockRepo.generateFinalSummary(
            guidance: any(named: 'guidance'),
            draftParagraphs: any(named: 'draftParagraphs'),
          )).thenThrow(Exception('WS connection lost'));

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_003',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['p1'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      try {
        await ctrl.generateFinalSummary(
          guidance: 'test',
          draftBodyText: 'p1',
        );
      } catch (_) {
        // Exception propagates — expected
      }

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.isGenerating, isFalse,
          reason: 'finally block must clear isGenerating');
    });
  });

  // ──── Recovery paths (exercises the same backend state checking as polling) ────

  group('refreshProcessingStatus — draft stage recovery', () {
    test('detects completed and transitions to finalChat', () async {
      when(() => mockRepo.getTaskStatus('task_draft_01')).thenAnswer(
        (_) async => VideoSummaryTaskInfo(
          taskId: 'task_draft_01',
          kbid: 'kb_test',
          videoId: 'vid_test',
          workflowState: WorkflowState.completed,
          draftSummary: 'draft content',
          finalSummary: 'final content',
          kbName: 'Test KB',
        ),
      );
      when(() => mockRepo.fetchDraftResult()).thenAnswer(
        (_) async => const VideoSummaryDraftData(paragraphs: ['draft content']),
      );

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_draft_01',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['draft'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.refreshProcessingStatus();

      // Let async operations complete
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.stage, VideoSummaryStage.finalChat,
          reason: 'Should transition when backend is completed');
      expect(state.finalSummaryData, isNotNull);
      expect(state.finalSummaryData!.summaryBody, 'final content');
    });

    test('detects finalGenerating and enters finalChat with isGenerating=true', () async {
      when(() => mockRepo.getTaskStatus('task_draft_02')).thenAnswer(
        (_) async => VideoSummaryTaskInfo(
          taskId: 'task_draft_02',
          kbid: 'kb_test',
          videoId: 'vid_test',
          workflowState: WorkflowState.finalGenerating,
          kbName: 'Test KB',
        ),
      );

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_draft_02',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['draft'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.refreshProcessingStatus();
      await Future.delayed(Duration.zero);

      // When backend is still finalGenerating, _resumeFinalGeneration is called
      // which enters finalChat stage with isGenerating=true to show "终稿生成中..."
      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.stage, VideoSummaryStage.finalChat,
          reason: 'Should enter finalChat stage to show generation progress');
      expect(state.isGenerating, isTrue,
          reason: 'Should be in generating state while waiting for final result');
    });

    test('detects failed and sets error message', () async {
      when(() => mockRepo.getTaskStatus('task_draft_03')).thenAnswer(
        (_) async => VideoSummaryTaskInfo(
          taskId: 'task_draft_03',
          kbid: 'kb_test',
          videoId: 'vid_test',
          workflowState: WorkflowState.failed,
          kbName: 'Test KB',
        ),
      );

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_draft_03',
          stage: VideoSummaryStage.draft,
          draftResult: const DraftResult(paragraphs: ['draft'], suggestionHint: ''),
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.refreshProcessingStatus();
      await Future.delayed(Duration.zero);

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.errorMessage, isNotNull,
          reason: 'Should set error when backend reports failed');
    });
  });

  group('refreshProcessingStatus — processing stage recovery', () {
    test('detects waitingUserApproval and transitions to draft', () async {
      when(() => mockRepo.getTaskStatus('task_proc_01')).thenAnswer(
        (_) async => VideoSummaryTaskInfo(
          taskId: 'task_proc_01',
          kbid: 'kb_test',
          videoId: 'vid_test',
          workflowState: WorkflowState.waitingUserApproval,
          draftSummary: 'draft ready',
          kbName: 'Test KB',
        ),
      );
      when(() => mockRepo.fetchDraftResult()).thenAnswer(
        (_) async =>
            const VideoSummaryDraftData(paragraphs: ['draft ready']),
      );

      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_proc_01',
          stage: VideoSummaryStage.processing,
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.refreshProcessingStatus();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.stage, VideoSummaryStage.draft,
          reason: 'Should transition to draft when backend is waiting for approval');
      expect(state.draftResult, isNotNull);
    });

    test('does nothing when taskId is null', () {
      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: null,
          stage: VideoSummaryStage.processing,
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.refreshProcessingStatus();

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.stage, VideoSummaryStage.processing,
          reason: 'Should not change state when taskId is null');
    });
  });

  // ──── Session ownership ────

  group('restoreSnapshot session cleanup', () {
    test('restoreSnapshot resets isGenerating and cancels polling', () {
      final container = createContainer(
        initialState: _defaultState().copyWith(
          taskId: 'task_old',
          stage: VideoSummaryStage.finalChat,
          isGenerating: true,
          finalSummaryData: null,
        ),
      );
      final ctrl = container.read(videoSummaryFlowControllerProvider.notifier);

      ctrl.restoreSnapshot(VideoSummaryFlowSnapshot(
        taskId: 'task_new',
        videoAsset: _defaultVideoAsset,
        stage: VideoSummaryStage.ready,
        uploadHighlighted: true,
        processingExpanded: false,
        isTimestampScoped: false,
        selectedTimestampStartSeconds: 0,
        selectedTimestampEndSeconds: 10,
        isDraftEditMode: false,
        processingSnapshot: null,
        draftResult: null,
        finalSummaryData: null,
        chatMessages: const [],
      ));

      final state = container.read(videoSummaryFlowControllerProvider);
      expect(state.isGenerating, isFalse);
      expect(state.stage, VideoSummaryStage.ready);
    });
  });
}
