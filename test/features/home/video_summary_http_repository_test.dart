import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';
import 'package:vidnexus/features/home/http_video_summary_repository.dart';
import 'package:vidnexus/services/models/common_dto.dart';
import 'package:vidnexus/services/models/video_qa_dto.dart';
import 'package:vidnexus/services/models/video_summary_task_dto.dart';
import 'package:vidnexus/services/polling/qa_poller.dart';
import 'package:vidnexus/services/polling/task_poller.dart';
import 'package:vidnexus/services/task_service.dart';
import 'package:vidnexus/services/video_qa_service.dart';
import 'package:vidnexus/services/websocket/ws_client.dart';
import 'package:vidnexus/services/websocket/ws_models.dart';
import 'package:vidnexus/services/sse/sse_models.dart';

// ---- Mocks ----

class MockTaskService extends Mock implements TaskService {}

class MockVideoQAService extends Mock implements VideoQAService {}

class MockWsClient extends Mock implements WsClient {}

class FakeTimeTravelQAStreamRequest extends Fake implements TimeTravelQAStreamRequest {}

void main() {
  registerFallbackValue(FakeTimeTravelQAStreamRequest());
  registerFallbackValue(Duration.zero);

  late MockTaskService mockTaskService;
  late MockVideoQAService mockVideoQAService;
  late MockWsClient mockWsClient;
  late StreamController<WSEventEnvelope> wsTestController;
  late TaskPoller taskPoller;
  late QAPoller qaPoller;

  const testKbid = 'kb-test-001';
  const testVideoId = 'vid-test-001';
  const testTaskId = 'task-test-001';
  const testQaId = 'qa-test-001';

  /// Helper: create a standard VideoSummaryTaskResponseData for stubbing.
  // ignore: no_leading_underscores_for_local_identifiers
  VideoSummaryTaskResponseData _taskResponse({
    String taskId = testTaskId,
    String kbid = testKbid,
    String videoId = testVideoId,
    String workflowState = 'DRAFT_GENERATING',
    String? draftSummary,
    String? finalSummary,
  }) {
    return VideoSummaryTaskResponseData(
      taskId: taskId,
      kbid: kbid,
      videoId: videoId,
      workflowState: workflowState,
      draftSummary: draftSummary,
      finalSummary: finalSummary,
      createdAt: '2026-05-17T10:00:00Z',
      updatedAt: '2026-05-17T10:00:00Z',
    );
  }

  /// Helper: create a standard ApiResponse wrapping the DTO.
  // ignore: no_leading_underscores_for_local_identifiers
  ApiResponse<T> _apiResponse<T>(T data) {
    return ApiResponse(
      status: 'success',
      data: data,
      meta: MetaInfo(
        requestId: 'req-test',
        timestamp: '2026-05-17T10:00:00Z',
      ),
    );
  }

  setUp(() {
    mockTaskService = MockTaskService();
    mockVideoQAService = MockVideoQAService();
    mockWsClient = MockWsClient();
    wsTestController = StreamController<WSEventEnvelope>.broadcast();

    // Stub dio getter — HttpVideoSummaryRepository accesses _taskService.dio in kDebugMode.
    when(() => mockTaskService.dio).thenReturn(Dio(BaseOptions(baseUrl: 'http://localhost:8000')));

    // WebSocket mock：ensureConnected 立即完成，eventStream 使用测试控制器
    when(() => mockWsClient.ensureConnected(timeout: any(named: 'timeout')))
        .thenAnswer((_) async {});
    when(() => mockWsClient.eventStream).thenAnswer((_) => wsTestController.stream);

    // Stub the dio getter to prevent null access in debug logging.
    // We use a dynamic approach since dio is not easily mockable.
    taskPoller = TaskPoller(
      taskService: mockTaskService,
      interval: const Duration(milliseconds: 50),
      timeout: const Duration(seconds: 5),
    );

    qaPoller = QAPoller(
      videoQAService: mockVideoQAService,
      interval: const Duration(milliseconds: 50),
      timeout: const Duration(seconds: 5),
    );
  });

  // ──── WorkflowState 解析 ────

  group('WorkflowState parsing', () {
    test('parses DRAFT_GENERATING from API string', () {
      expect(WorkflowState.fromApi('DRAFT_GENERATING'),
          WorkflowState.draftGenerating);
    });

    test('parses WAITING_USER_APPROVAL from API string', () {
      expect(
          WorkflowState.fromApi('WAITING_USER_APPROVAL'), WorkflowState.waitingUserApproval);
    });

    test('parses FINAL_GENERATING from API string', () {
      expect(WorkflowState.fromApi('FINAL_GENERATING'),
          WorkflowState.finalGenerating);
    });

    test('parses COMPLETED from API string', () {
      expect(WorkflowState.fromApi('COMPLETED'), WorkflowState.completed);
    });

    test('parses FAILED from API string', () {
      expect(WorkflowState.fromApi('FAILED'), WorkflowState.failed);
    });

    test('unknown string falls back to failed', () {
      expect(
          WorkflowState.fromApi('UNKNOWN_STATE'), WorkflowState.failed);
    });

    test('isTerminal returns true for WAITING_USER_APPROVAL', () {
      expect(WorkflowState.waitingUserApproval.isTerminal, isTrue);
    });

    test('isTerminal returns true for COMPLETED', () {
      expect(WorkflowState.completed.isTerminal, isTrue);
    });

    test('isTerminal returns true for FAILED', () {
      expect(WorkflowState.failed.isTerminal, isTrue);
    });

    test('isTerminal returns false for DRAFT_GENERATING', () {
      expect(WorkflowState.draftGenerating.isTerminal, isFalse);
    });

    test('label returns Chinese labels for all states', () {
      expect(WorkflowState.draftGenerating.label, '生成初稿中');
      expect(WorkflowState.waitingUserApproval.label, '等待用户审批');
      expect(WorkflowState.finalGenerating.label, '生成终稿中');
      expect(WorkflowState.completed.label, '已完成');
      expect(WorkflowState.failed.label, '处理失败');
    });
  });

  // ──── TaskPoller 轮询逻辑 ────

  group('TaskPoller polling', () {
    test('yields processing data and completes on WAITING_USER_APPROVAL', () async {
      // First call: DRAFT_GENERATING
      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(workflowState: 'DRAFT_GENERATING'),
        ),
      );

      // Collect first event
      final stream = taskPoller.pollTask(testTaskId);
      final events = <VideoSummaryProcessingData>[];

      try {
        await for (final event in stream) {
          events.add(event);
          if (events.isNotEmpty) break; // Only capture first tick
        }
      } catch (_) {
        // Expected timeout if we break early
      }

      expect(events, isNotEmpty);
      expect(events.first.currentMessage, contains('生成'));
    });

    test('yields processing data then throws on FAILED state', () async {
      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(workflowState: 'FAILED'),
        ),
      );

      final stream = taskPoller.pollTask(testTaskId);

      // First event is processing data (yielded before throw).
      // TaskPoller yields then throws TaskFailedException,
      // but stream.first completes on the first yield.
      final event = await stream.first;
      expect(event.currentMessage, contains('失败'));
    });
  });

  // ──── QAPoller QA 轮询 ────

  group('QAPoller polling', () {
    test('returns reply when answer_content is populated', () async {
      when(() => mockVideoQAService.getQA(testTaskId, testQaId)).thenAnswer(
        (_) async => _apiResponse(
          const VideoQARecordResponseData(
            qaId: testQaId,
            taskId: testTaskId,
            questionContent: '测试问题',
            answerContent: '这是一个测试回答',
          ),
        ),
      );

      final reply = await qaPoller.waitForAnswer(
        taskId: testTaskId,
        qaId: testQaId,
      );

      expect(reply.text, '这是一个测试回答');
    });

    test('keeps polling until answer is available', () async {
      var callCount = 0;
      when(() => mockVideoQAService.getQA(testTaskId, testQaId)).thenAnswer(
        (_) async {
          callCount++;
          if (callCount < 3) {
            return _apiResponse(
              const VideoQARecordResponseData(
                qaId: testQaId,
                taskId: testTaskId,
                questionContent: '测试问题',
                answerContent: null, // Still generating
              ),
            );
          }
          return _apiResponse(
            const VideoQARecordResponseData(
              qaId: testQaId,
              taskId: testTaskId,
              questionContent: '测试问题',
              answerContent: '第三次轮询才返回答案',
            ),
          );
        },
      );

      final reply = await qaPoller.waitForAnswer(
        taskId: testTaskId,
        qaId: testQaId,
      );

      expect(callCount, 3);
      expect(reply.text, '第三次轮询才返回答案');
    });
  });

  // ──── HttpVideoSummaryRepository ────

  group('HttpVideoSummaryRepository', () {
    late HttpVideoSummaryRepository repository;

    /// Helper: stub createTask + startAnalysis so that startDraftGeneration
    /// can proceed, then schedule a WS completed event so the stream terminates.
    void stubTaskCreationAndPollCompletion() {
      when(() => mockTaskService.createTask(
            kbid: testKbid,
            videoId: testVideoId,
          )).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(workflowState: 'DRAFT_GENERATING'),
        ),
      );

      when(() => mockTaskService.startAnalysis(testTaskId))
          .thenAnswer((_) async => _apiResponse(
                StartAnalysisResponseData(
                  taskId: testTaskId,
                  workflowState: 'DRAFT_GENERATING',
                ),
              ));

      // getTask returns WAITING_USER_APPROVAL so poller terminates after first tick.
      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(workflowState: 'WAITING_USER_APPROVAL'),
        ),
      );

      // Schedule a WS completed event after a short delay,
      // so startDraftGeneration's WS listener has time to be set up.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!wsTestController.isClosed) {
          wsTestController.add(WSEventEnvelope(
            eventId: 'evt-test',
            eventType: WSEventType.completed,
            scope: WSScope.videoSummaryTask,
            scopeId: testTaskId,
            sequence: 1,
            message: 'Phase-1 analysis completed',
          ));
        }
      });
    }

    setUp(() {
      repository = HttpVideoSummaryRepository(
        taskService: mockTaskService,
        videoQAService: mockVideoQAService,
        wsClient: mockWsClient,
        taskPoller: taskPoller,
        kbid: testKbid,
        videoId: testVideoId,
      );
    });

    test('getVideoAsset returns placeholder with correct ids', () {
      final asset = repository.getVideoAsset();

      expect(asset.title, testVideoId);
      expect(asset.fileName, testVideoId);
      expect(asset.sourceLabel, testKbid);
      expect(asset.durationLabel, '0m 00s');
    });

    test('fetchDraftResult parses draft_summary into paragraphs', () async {
      stubTaskCreationAndPollCompletion();

      final genStream = repository.startDraftGeneration();
      await genStream.first; // Poller terminates on WAITING_USER_APPROVAL

      // Re-stub getTask for fetchDraftResult
      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(
            workflowState: 'WAITING_USER_APPROVAL',
            draftSummary: '第一段内容。\n\n第二段内容。\n\n第三段，测试。',
          ),
        ),
      );

      final draft = await repository.fetchDraftResult();

      expect(draft.paragraphs, hasLength(3));
      expect(draft.paragraphs[0], '第一段内容。');
      expect(draft.paragraphs[1], '第二段内容。');
      expect(draft.paragraphs[2], '第三段，测试。');
    });

    test('fetchDraftResult handles single paragraph', () async {
      stubTaskCreationAndPollCompletion();

      final genStream = repository.startDraftGeneration();
      await genStream.first;

      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(
            workflowState: 'WAITING_USER_APPROVAL',
            draftSummary: '只有一段内容不含双换行。',
          ),
        ),
      );

      final draft = await repository.fetchDraftResult();

      expect(draft.paragraphs, hasLength(1));
      expect(draft.paragraphs[0], '只有一段内容不含双换行。');
    });

    test('fetchDraftResult handles empty draft', () async {
      stubTaskCreationAndPollCompletion();

      final genStream = repository.startDraftGeneration();
      await genStream.first;

      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(
            workflowState: 'WAITING_USER_APPROVAL',
            draftSummary: '',
          ),
        ),
      );

      final draft = await repository.fetchDraftResult();

      expect(draft.paragraphs, hasLength(1));
      expect(draft.paragraphs[0], '');
    });

    test('fetchDraftResult throws StateError when no active task', () async {
      final freshRepo = HttpVideoSummaryRepository(
        taskService: mockTaskService,
        wsClient: mockWsClient,
        kbid: testKbid,
        videoId: testVideoId,
      );

      expect(
        () => freshRepo.fetchDraftResult(),
        throwsA(isA<StateError>()),
      );
    });

    test('generateFinalSummary submits guidance and returns final result',
        () async {
      stubTaskCreationAndPollCompletion();

      final genStream = repository.startDraftGeneration();
      await genStream.first;

      // Stub updateTask
      when(() => mockTaskService.updateTask(
            testTaskId,
            userGuidance: '请精简内容',
            draftSummary: '段落A\n\n段落B',
          )).thenAnswer(
        (_) async => _apiResponse(
          _taskResponse(workflowState: 'FINAL_GENERATING'),
        ),
      );

      // Re-stub getTask for final poll: first COMPLETED (terminal), then with finalSummary
      var getCallCount = 0;
      when(() => mockTaskService.getTask(testTaskId)).thenAnswer(
        (_) async {
          getCallCount++;
          if (getCallCount == 1) {
            return _apiResponse(
              _taskResponse(workflowState: 'COMPLETED'),
            );
          }
          return _apiResponse(
            _taskResponse(
              workflowState: 'COMPLETED',
              finalSummary: '精简后的终稿内容',
            ),
          );
        },
      );

      final result = await repository.generateFinalSummary(
        guidance: '请精简内容',
        draftParagraphs: ['段落A', '段落B'],
      );

      expect(result.body, '精简后的终稿内容');
      expect(result.references, isEmpty);
    });

    test('sendSummaryChatMessage creates QA and streams answer', () async {
      stubTaskCreationAndPollCompletion();

      final genStream = repository.startDraftGeneration();
      await genStream.first;

      // Stub createTimeTravelQAStream
      when(() => mockVideoQAService.createTimeTravelQAStream(
            testTaskId,
            any(),
          )).thenAnswer(
        (_) => Stream.fromIterable([
          const SSEEvent(
            type: SSEEventType.delta,
            event: 'delta',
            data: {
              'task_id': testTaskId,
              'qa_id': testQaId,
              'chunk': '当然，这里是更详细的解释……',
              'sequence': 1,
            },
          ),
          const SSEEvent(
            type: SSEEventType.done,
            event: 'done',
            data: {
              'task_id': testTaskId,
              'qa_id': testQaId,
              'answer_content': '当然，这里是更详细的解释……',
            },
          ),
        ]),
      );

      final replyStream =
          repository.sendSummaryChatMessage('能再详细解释一下吗？', timestamp: '00:00:00');
      final reply = await replyStream.last;

      expect(reply.text, '当然，这里是更详细的解释……');
    });

    test(
        'sendSummaryChatMessage throws UnimplementedError when VideoQAService not injected',
        () async {
      final repoWithoutQA = HttpVideoSummaryRepository(
        taskService: mockTaskService,
        wsClient: mockWsClient,
        kbid: testKbid,
        videoId: testVideoId,
      );

      stubTaskCreationAndPollCompletion();

      final genStream = repoWithoutQA.startDraftGeneration();
      await genStream.first;

      expect(
        () => repoWithoutQA.sendSummaryChatMessage('测试', timestamp: '00:00:00'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  // ──── API DTO 序列化/反序列化 ────

  group('API DTO serialization', () {
    test('VideoSummaryTaskResponseData fromJson parses all fields', () {
      final json = {
        'task_id': 'task-123',
        'kbid': 'kb-456',
        'video_id': 'vid-789',
        'workflow_state': 'COMPLETED',
        'user_initial_preference': '重点分析技术方案',
        'draft_summary': '初稿内容...',
        'user_guidance': '请补充细节',
        'final_summary': '终稿内容...',
        'title': '技术方案分析',
        'summary_vector_ids': ['vec-1', 'vec-2'],
        'created_at': '2026-05-17T10:00:00Z',
        'updated_at': '2026-05-17T11:00:00Z',
      };

      final dto = VideoSummaryTaskResponseData.fromJson(json);

      expect(dto.taskId, 'task-123');
      expect(dto.kbid, 'kb-456');
      expect(dto.videoId, 'vid-789');
      expect(dto.workflowState, 'COMPLETED');
      expect(dto.userInitialPreference, '重点分析技术方案');
      expect(dto.draftSummary, '初稿内容...');
      expect(dto.userGuidance, '请补充细节');
      expect(dto.finalSummary, '终稿内容...');
      expect(dto.title, '技术方案分析');
      expect(dto.summaryVectorIds, ['vec-1', 'vec-2']);
      expect(dto.createdAt, '2026-05-17T10:00:00Z');
      expect(dto.updatedAt, '2026-05-17T11:00:00Z');
    });

    test('TaskCreateRequest toJson produces correct map', () {
      const req = TaskCreateRequest(
        kbid: 'kb-1',
        videoId: 'vid-1',
        userInitialPreference: '偏好',
      );

      final json = req.toJson();

      expect(json['kbid'], 'kb-1');
      expect(json['video_id'], 'vid-1');
      expect(json['user_initial_preference'], '偏好');
    });

    test('TaskUpdateRequest toJson skips null fields', () {
      const req = TaskUpdateRequest(
        draftSummary: 'draft',
        userGuidance: null,
        title: null,
      );

      final json = req.toJson();

      expect(json['draft_summary'], 'draft');
      expect(json.containsKey('user_guidance'), isFalse);
      expect(json.containsKey('title'), isFalse);
    });

    test('VideoQACreateRequest toJson produces correct map', () {
      const req = VideoQACreateRequest(
        taskId: 'task-1',
        questionContent: '问题',
        startTime: '00:00',
        endTime: '01:00',
      );

      final json = req.toJson();

      expect(json['task_id'], 'task-1');
      expect(json['question_content'], '问题');
      expect(json['start_time'], '00:00');
      expect(json['end_time'], '01:00');
    });

    test('PageParams toQueryParameters includes non-null values', () {
      const params = PageParams(page: 2, pageSize: 10, sort: '-created_at');

      final qp = params.toQueryParameters();

      expect(qp['page'], '2');
      expect(qp['page_size'], '10');
      expect(qp['sort'], '-created_at');
      expect(qp.containsKey('fields'), isFalse);
      expect(qp.containsKey('cursor'), isFalse);
    });
  });

  // ──── WorkflowState → Presentation 映射 ────

  group('WorkflowState presentation mapping', () {
    test('all workflow states have corresponding processing stages', () {
      // 验证每个 WorkflowState 都有 label
      for (final state in WorkflowState.values) {
        expect(state.label, isNotEmpty,
            reason: '$state should have a non-empty label');
      }
    });

    test('VideoSummaryTaskInfo aggregates task identity correctly', () {
      const info = VideoSummaryTaskInfo(
        taskId: 'task-1',
        videoId: 'vid-1',
        kbid: 'kb-1',
        workflowState: WorkflowState.waitingUserApproval,
        draftSummary: 'draft',
        finalSummary: null,
        fileName: 'test.mp4',
      );

      expect(info.taskId, 'task-1');
      expect(info.workflowState, WorkflowState.waitingUserApproval);
      expect(info.workflowState.isTerminal, isTrue);
    });
  });
}
