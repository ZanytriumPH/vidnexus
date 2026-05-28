import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/models/common_dto.dart';
import '../../services/polling/task_poller.dart';
import '../../services/task_service.dart';
import '../../services/video_qa_service.dart';
import '../../services/websocket/ws_models.dart';
import '../../services/sse/sse_models.dart';
import 'domain/video_summary_domain_models.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';

/// 基于 HTTP 的真实 VideoSummaryRepository 实现。
///
/// 使用方式：
/// - 通过 Provider 注入，实现 [VideoSummaryRepository]
/// - [kbid] 和 [videoId] 在构造时指定（后续可由 Controller 动态设置）
class HttpVideoSummaryRepository extends VideoSummaryRepository {
  HttpVideoSummaryRepository({
    required TaskService taskService,
    VideoQAService? videoQAService,
    TaskPoller? taskPoller,
    required Stream<WSEventEnvelope?> wsEventStream,
    required this.kbid,
    required this.videoId,
  })  : _taskService = taskService,
        _videoQAService = videoQAService,
        _wsEventStream = wsEventStream,
        _taskPoller = taskPoller ??
            TaskPoller(taskService: taskService);

  final TaskService _taskService;
  final VideoQAService? _videoQAService;
  final Stream<WSEventEnvelope?> _wsEventStream;
  final TaskPoller _taskPoller;

  /// 当前知识库 ID。
  @override
  String kbid;

  /// 当前视频 ID。
  @override
  String videoId;

  String? _taskId;

  @override
  void updateVideoId(String newId) {
    videoId = newId;
  }

  @override
  void updateKbid(String newId) {
    kbid = newId;
  }

  @override
  void updateTaskId(String? newId) {
    _taskId = newId;
  }

  @override
  String? get activeTaskId => _taskId;

  // ---- VideoSummaryRepository 实现 ----

  @override
  Future<List<VideoSummaryTaskInfo>> listTaskHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    final resp = await _taskService.listTasks(
      params: PageParams(page: page, pageSize: pageSize, sort: '-created_at'),
    );
    return resp.data
        .map(
          (dto) => VideoSummaryTaskInfo(
            taskId: dto.taskId,
            videoId: dto.videoId,
            kbid: dto.kbid,
            workflowState: WorkflowState.fromApi(dto.workflowState),
            draftSummary: dto.draftSummary,
            finalSummary: dto.finalSummary,
            title: dto.title,
            userInitialPreference: dto.userInitialPreference,
          ),
        )
        .toList();
  }

  @override
  VideoAssetInfo getVideoAsset() {
    // 同步方法，返回合法默认值；真实数据通过 fetchDraftResult 异步获取。
    // durationLabel 必须是 parseVideoSummaryDurationLabel 可解析的格式：
    // "MM:SS"（如 "00:00"）或 "Xm Ys"（如 "0m 00s"）。
    return VideoAssetInfo(
      title: videoId,
      durationLabel: '0m 00s',
      sourceLabel: kbid,
      fileName: videoId,
    );
  }

  VideoSummaryProcessingStage _mapWSStage(WSStage? stage) {
    if (stage == null) return VideoSummaryProcessingStage.acquiringVideo;
    return switch (stage) {
      WSStage.extraction => VideoSummaryProcessingStage.acquiringVideo,
      WSStage.transcribing => VideoSummaryProcessingStage.transcribingAudio,
      WSStage.extractingKeyframes => VideoSummaryProcessingStage.extractingFrames,
      WSStage.ragRetrieval => VideoSummaryProcessingStage.dispatchingChunks,
      WSStage.llmReasoning => VideoSummaryProcessingStage.analyzingAudioChunks,
      WSStage.synthesis => VideoSummaryProcessingStage.synthesizingChunks,
      WSStage.cleanup => VideoSummaryProcessingStage.waitingHumanReview,
    };
  }

  List<VideoSummaryProcessingStepData> _buildWSSteps(WSStage? stage, int progress) {
    int preprocessProgress = 0;
    int analysisProgress = 0;
    int synthesisProgress = 0;

    if (stage == null) {
      preprocessProgress = progress;
    } else {
      switch (stage) {
        case WSStage.extraction:
        case WSStage.transcribing:
        case WSStage.extractingKeyframes:
          preprocessProgress = progress.clamp(0, 100);
          break;
        case WSStage.ragRetrieval:
        case WSStage.llmReasoning:
          preprocessProgress = 100;
          analysisProgress = progress.clamp(0, 100);
          break;
        case WSStage.synthesis:
        case WSStage.cleanup:
          preprocessProgress = 100;
          analysisProgress = 100;
          synthesisProgress = progress.clamp(0, 100);
          break;
      }
    }

    return [
      VideoSummaryProcessingStepData(
        phase: VideoSummaryProcessingPhase.preprocessing,
        progress: preprocessProgress,
        completedUnits: preprocessProgress,
        totalUnits: 100,
      ),
      VideoSummaryProcessingStepData(
        phase: VideoSummaryProcessingPhase.analysis,
        progress: analysisProgress,
        completedUnits: analysisProgress,
        totalUnits: 100,
      ),
      VideoSummaryProcessingStepData(
        phase: VideoSummaryProcessingPhase.synthesis,
        progress: synthesisProgress,
        completedUnits: synthesisProgress,
        totalUnits: 100,
      ),
    ];
  }

  @override
  Stream<VideoSummaryProcessingData> startDraftGeneration({
    String? userInitialPreference,
  }) async* {
    if (kDebugMode) {
      debugPrint(
        '[HttpRepo] 开始创建任务 — kbid=$kbid videoId=$videoId '
        'baseUrl=${_taskService.dio.options.baseUrl}',
      );
    }

    // 1. 创建任务（传入用户总结偏好）
    final createResp = await _taskService.createTask(
      kbid: kbid,
      videoId: videoId,
      userInitialPreference: userInitialPreference,
    );
    final data = createResp.data;
    if (data == null) {
      throw StateError('Task creation returned null data');
    }
    _taskId = data.taskId;

    if (kDebugMode) {
      debugPrint('[HttpRepo] 任务已创建 — taskId=$_taskId state=${data.workflowState}');
    }

    // 2. 触发 Phase-1 分析工作流（new.md 新增 startAnalysis）
    try {
      await _taskService.startAnalysis(_taskId!);
      if (kDebugMode) {
        debugPrint('[HttpRepo] 分析已启动 — taskId=$_taskId');
      }
    } catch (e) {
      debugPrint('[HttpRepo] startAnalysis 失败（可能后端已自动启动）: $e');
    }

    // 3. 监听进度 (WebSocket + 降级 Polling)
    final wsStream = _wsEventStream.where((env) =>
        env != null &&
        env.scope == WSScope.videoSummaryTask &&
        env.scopeId == _taskId);

    bool receivedWsEvent = false;
    final controller = StreamController<VideoSummaryProcessingData>();

    // 订阅 WS
    StreamSubscription? wsSubscription;
    wsSubscription = wsStream.listen(
      (env) {
        if (env == null) return;
        receivedWsEvent = true;

        if (env.eventType == WSEventType.error) {
          controller.addError(TaskFailedException(_taskId!));
          controller.close();
          return;
        }

        final progressVal = (env.progress ?? 0) / 100.0;
        final currentStage = _mapWSStage(env.stage);
        final currentMessage = env.message ?? '';
        final steps = _buildWSSteps(env.stage, env.progress ?? 0);

        controller.add(VideoSummaryProcessingData(
          progress: progressVal,
          currentStage: currentStage,
          currentMessage: currentMessage,
          steps: steps,
        ));

        if (env.eventType == WSEventType.completed) {
          controller.close();
        }
      },
      onError: (e) {
        debugPrint('[HttpRepo] WebSocket stream error: $e');
      },
    );

    // 3秒后检查是否有收到 WS 消息，若没有，启动 Polling 降级方案以防卡死
    Timer(const Duration(seconds: 3), () async {
      if (!receivedWsEvent && !controller.isClosed) {
        debugPrint('[HttpRepo] WebSocket 3秒内未收到消息，启用 Polling 降级方案');
        try {
          await for (final data in _taskPoller.pollTask(_taskId!)) {
            if (!receivedWsEvent && !controller.isClosed) {
              controller.add(data);
            } else {
              break;
            }
          }
          if (!receivedWsEvent && !controller.isClosed) {
            controller.close();
          }
        } catch (e) {
          if (!receivedWsEvent && !controller.isClosed) {
            controller.addError(e);
            controller.close();
          }
        }
      }
    });

    controller.onCancel = () {
      wsSubscription?.cancel();
    };

    yield* controller.stream;
  }

  @override
  Future<VideoSummaryDraftData> fetchDraftResult() async {
    final taskId = _taskId;
    if (taskId == null) {
      throw StateError('No active task — call startDraftGeneration() first');
    }

    final resp = await _taskService.getTask(taskId);
    final dto = resp.data;
    if (dto == null) {
      throw StateError('Task $taskId not found');
    }

    final draftText = dto.draftSummary ?? '';
    final paragraphs = draftText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return VideoSummaryDraftData(
      paragraphs: paragraphs.isEmpty ? [draftText] : paragraphs,
    );
  }

  @override
  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  }) async {
    final taskId = _taskId;
    if (taskId == null) {
      throw StateError('No active task — call startDraftGeneration() first');
    }

    // 1. 提交用户指引并触发 Phase-2 终稿生成（new.md 新增 approveAndFinalize）
    await _taskService.updateTask(
      taskId,
      userGuidance: guidance,
      draftSummary: draftParagraphs.join('\n\n'),
    );

    try {
      await _taskService.approveAndFinalize(
        taskId,
        editedAggregatedChunkInsights: draftParagraphs.join('\n\n'),
        humanGuidance: guidance,
      );
      if (kDebugMode) {
        debugPrint('[HttpRepo] 审批已提交 — taskId=$taskId');
      }
    } catch (e) {
      debugPrint('[HttpRepo] approveAndFinalize 失败: $e');
    }

    // 2. 轮询等待终稿完成
    try {
      await for (final _ in _taskPoller.pollTask(taskId)) {
        // 仅等待终态，不关心中间进度
      }
    } on PollingTimeoutException {
      // 超时但仍尝试获取最终结果
    }

    // 3. 获取最终任务数据
    final resp = await _taskService.getTask(taskId);
    final dto = resp.data;
    if (dto == null) {
      throw StateError('Task $taskId not found after final generation');
    }

    final finalText = dto.finalSummary ?? dto.draftSummary ?? '';

    return VideoSummaryFinalResultData(
      body: finalText,
      references: const [], // 引用来源由 Phase 5 QA 接口返回
    );
  }

  @override
  Stream<VideoSummaryChatReplyData> sendSummaryChatMessage(
    String message, {
    required String timestamp,
    int? windowSeconds,
  }) {
    final taskId = _taskId;
    if (taskId == null) {
      throw StateError('No active task — call startDraftGeneration() first');
    }
    final qaSvc = _videoQAService;
    if (qaSvc == null) {
      throw UnimplementedError('VideoQAService not injected — add videoQAService to provider');
    }

    final request = TimeTravelQAStreamRequest(
      timestamp: timestamp,
      questionContent: message,
      windowSeconds: windowSeconds,
    );

    final stream = qaSvc.createTimeTravelQAStream(taskId, request);
    final answerBuffer = StringBuffer();
    final controller = StreamController<VideoSummaryChatReplyData>();

    StreamSubscription? sub;
    controller.onListen = () {
      sub = stream.listen(
        (event) {
          if (event.type == SSEEventType.delta) {
            final delta = event.parseData<SSEDeltaData>(SSEDeltaData.fromJson);
            if (delta != null) {
              answerBuffer.write(delta.chunk);
              controller.add(VideoSummaryChatReplyData(text: answerBuffer.toString()));
            }
          } else if (event.type == SSEEventType.done) {
            final done = event.parseData<TimeTravelQADoneData>(TimeTravelQADoneData.fromJson);
            if (done?.answerContent != null && done!.answerContent!.isNotEmpty) {
              controller.add(VideoSummaryChatReplyData(text: done.answerContent!));
            }
            controller.close();
          } else if (event.type == SSEEventType.error) {
            controller.addError(Exception(event.data?.toString() ?? 'SSE stream error'));
            controller.close();
          }
        },
        onError: (e) {
          controller.addError(e);
          controller.close();
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    };

    controller.onCancel = () {
      sub?.cancel();
    };

    return controller.stream;
  }
}
