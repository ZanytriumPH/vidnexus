import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/models/common_dto.dart';
import '../../services/models/video_summary_task_dto.dart';
import '../../services/task_service.dart';
import '../../services/video_qa_service.dart';
import '../../services/websocket/ws_client.dart';
import '../../services/websocket/ws_models.dart';
import '../../services/sse/sse_models.dart';
import 'domain/chunk_progress_estimator.dart';
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
    required WsClient wsClient,
    required this.kbid,
    required this.videoId,
  }) : _taskService = taskService,
       _videoQAService = videoQAService,
       _wsClient = wsClient,
       _connectionStateStream = wsClient.connectionStateStream;

  final TaskService _taskService;
  final VideoQAService? _videoQAService;
  final WsClient _wsClient;
  final Stream<WsConnectionState> _connectionStateStream;

  /// 当前知识库 ID。
  @override
  String kbid;

  /// 当前视频 ID。
  @override
  String videoId;

  String? _taskId;
  String? _kbName;

  /// 上次 WS 进度值（0.0~1.0），用于 progress=null 时保持不回退。
  double _lastProgress = 0.0;

  /// 去重集合：记录已处理的 scopeId:sequence，防止 Redis 双通道重复推送。
  Set<String> _seenSequences = {};

  /// 分片进度估算器：从 WS 单值 + 阶段推导 4 轨并行进度。
  final ChunkProgressEstimator _estimator = ChunkProgressEstimator();

  /// 状态日志缓冲区：保留最近 20 条后端消息。
  final List<String> _statusLog = [];

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

  /// 当前任务关联的知识库名称（从 API 响应捕获）。
  String? get kbName => _kbName;

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
            kbName: dto.kbName,
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
  Future<List<VideoSummaryTaskInfo>> listVideoTasks(
    String videoId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final resp = await _taskService.listVideoTasks(
      videoId,
      params: PageParams(page: page, pageSize: pageSize, sort: '-created_at'),
    );
    return resp.data
        .map(
          (dto) => VideoSummaryTaskInfo(
            taskId: dto.taskId,
            videoId: dto.videoId,
            kbid: dto.kbid,
            kbName: dto.kbName,
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
  Future<VideoSummaryTaskInfo> cloneTaskToKb(
    String taskId, {
    required String targetKbid,
    String? replaceExistingTaskId,
  }) async {
    final resp = await _taskService.cloneTaskToKb(
      taskId,
      kbid: targetKbid,
      replaceExistingTaskId: replaceExistingTaskId,
    );
    final dto = resp.data;
    if (dto == null) {
      throw StateError('cloneTaskToKb returned null data');
    }
    _kbName = dto.kbName;
    return VideoSummaryTaskInfo(
      taskId: dto.taskId,
      videoId: dto.videoId,
      kbid: dto.kbid,
      kbName: dto.kbName,
      workflowState: WorkflowState.fromApi(dto.workflowState),
      draftSummary: dto.draftSummary,
      finalSummary: dto.finalSummary,
      title: dto.title,
      userInitialPreference: dto.userInitialPreference,
    );
  }

  @override
  Future<VideoSummaryTaskInfo?> getTaskStatus(String taskId) async {
    try {
      final resp = await _taskService.getTask(taskId);
      final dto = resp.data;
      if (dto == null) return null;
      _kbName = dto.kbName; // sync to repository cache
      return VideoSummaryTaskInfo(
        taskId: dto.taskId,
        videoId: dto.videoId,
        kbid: dto.kbid,
        kbName: dto.kbName,
        workflowState: WorkflowState.fromApi(dto.workflowState),
        draftSummary: dto.draftSummary,
        finalSummary: dto.finalSummary,
        title: dto.title,
        userInitialPreference: dto.userInitialPreference,
      );
    } catch (e) {
      debugPrint('[HttpRepo] getTaskStatus 失败 — taskId=$taskId: $e');
      return null;
    }
  }

  @override
  Stream<VideoSummaryProcessingData> resumeTaskProgress(String taskId) async* {
    // 重置状态追踪器（和 startDraftGeneration 保持一致）
    _lastProgress = 0.0;
    _seenSequences = {};
    _estimator.reset();
    _statusLog.clear();
    _taskId = taskId;

    if (kDebugMode) {
      debugPrint('[HttpRepo] resumeTaskProgress — 开始监听 WS 事件 taskId=$taskId');
    }

    // 订阅 WebSocket 事件（与 startDraftGeneration 相同的处理逻辑）
    final wsStream = _wsClient.eventStream.where(
      (env) => env.scope == WSScope.videoSummaryTask && env.scopeId == taskId,
    );

    final controller = StreamController<VideoSummaryProcessingData>();
    StreamSubscription<WSEventEnvelope>? wsSubscription;

    // 恢复场景的首事件超时缩短为 15s（并行轮询提供兜底）
    Timer? firstEventTimeout;
    firstEventTimeout = Timer(const Duration(seconds: 15), () {
      if (!controller.isClosed) {
        debugPrint('[HttpRepo] resumeTaskProgress — 首事件超时（15s）taskId=$taskId');
        controller.addError(TimeoutException('恢复进度监听超时，taskId=$taskId'));
        controller.close();
      }
    });

    Timer? totalTimeout;
    const totalTimeoutDuration = Duration(seconds: 120);

    wsSubscription = wsStream.listen(
      (env) {
        if (controller.isClosed) return;
        if (env.eventType == WSEventType.reconnectAck) return;

        final seqKey = '${env.scopeId}:${env.sequence}';
        if (_seenSequences.contains(seqKey)) return;
        _seenSequences.add(seqKey);
        if (_seenSequences.length > 200) {
          _seenSequences = _seenSequences.skip(100).toSet();
        }

        if (firstEventTimeout != null) {
          firstEventTimeout!.cancel();
          firstEventTimeout = null;
          totalTimeout = Timer(totalTimeoutDuration, () {
            if (!controller.isClosed) {
              debugPrint('[HttpRepo] resumeTaskProgress — 总超时 taskId=$taskId');
              controller.addError(
                TimeoutException(
                  '任务处理超时（${totalTimeoutDuration.inSeconds}s），taskId=$taskId',
                ),
              );
              controller.close();
            }
          });
        }

        if (env.eventType == WSEventType.error) {
          debugPrint('[HttpRepo] resumeTaskProgress — error: ${env.message}');
          controller.addError(TaskFailedException(taskId));
          controller.close();
          return;
        }

        if (env.eventType == WSEventType.completed) {
          if (kDebugMode) {
            debugPrint(
              '[HttpRepo] resumeTaskProgress — completed taskId=$taskId',
            );
          }
          final finalChunkProgress = _estimator.estimate(
            wsProgress: 100,
            wsMessage: env.message,
            wsStageLabel: env.stage?.name,
            substage: env.substage,
            payload: env.payload,
          );
          controller.add(
            VideoSummaryProcessingData(
              progress: 1.0,
              currentMessage: env.message ?? '初稿生成完成',
              chunkProgress: finalChunkProgress,
              statusLog: List<String>.from(_statusLog),
            ),
          );
          controller.close();
          return;
        }

        final msg = env.message;
        if (msg != null &&
            msg.isNotEmpty &&
            env.substage != 'chunk_processing') {
          _statusLog.add(msg);
          if (_statusLog.length > 20) _statusLog.removeAt(0);
        }

        final chunkProgress = _estimator.estimate(
          wsProgress: env.progress,
          wsMessage: env.message,
          wsStageLabel: env.stage?.name,
          substage: env.substage,
          payload: env.payload,
        );

        final progressVal = env.progress != null
            ? env.progress! / 100.0
            : _lastProgress;
        _lastProgress = progressVal;

        controller.add(
          VideoSummaryProcessingData(
            progress: progressVal,
            currentMessage: env.message ?? '',
            chunkProgress: chunkProgress,
            statusLog: List<String>.from(_statusLog),
          ),
        );

        if (kDebugMode) {
          debugPrint(
            '[HttpRepo] WS进度(恢复) — stage=${env.stage?.name} '
            'progress=${env.progress}% '
            'displayProgress=${(progressVal * 100).toStringAsFixed(0)}% '
            'msg=${env.message}',
          );
        }
      },
      onError: (e) {
        debugPrint('[HttpRepo] resumeTaskProgress — WS error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      },
      onDone: () {
        debugPrint(
          '[HttpRepo] resumeTaskProgress — WS stream done taskId=$taskId',
        );
        if (!controller.isClosed) controller.close();
      },
    );

    // 监听 WS 连接状态，断连时记录日志（恢复由 FlowController 并行轮询保证）
    StreamSubscription<WsConnectionState>? connStateSub;
    connStateSub = _connectionStateStream.listen((state) {
      if (state == WsConnectionState.disconnected ||
          state == WsConnectionState.reconnecting) {
        debugPrint(
          '[HttpRepo] resumeTaskProgress — WS connection $state '
          'taskId=$taskId',
        );
      }
    });

    controller.onCancel = () {
      firstEventTimeout?.cancel();
      totalTimeout?.cancel();
      wsSubscription?.cancel();
      connStateSub?.cancel();
    };

    // 竞态窗口守护：WS 订阅已就绪，再次检查后端是否在订阅建立间隙已完成。
    // 若已完成则直接推送 completion 事件，避免漏掉已发出的 completed 消息。
    try {
      final gapCheckResp = await _taskService.getTask(taskId);
      final gapData = gapCheckResp.data;
      if (!controller.isClosed &&
          gapData != null &&
          gapData.draftSummary != null &&
          gapData.draftSummary!.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[HttpRepo] resumeTaskProgress — 竞态窗口守护：后端已有初稿，直接闭合');
        }
        final finalChunkProgress = _estimator.estimate(
          wsProgress: 100,
          wsMessage: '初稿已生成',
          wsStageLabel: null,
          substage: null,
          payload: null,
        );
        controller.add(
          VideoSummaryProcessingData(
            progress: 1.0,
            currentMessage: '初稿已生成',
            chunkProgress: finalChunkProgress,
            statusLog: List<String>.from(_statusLog),
          ),
        );
        controller.close();
      }
    } catch (_) {
      // 守护检查失败不影响 WS 监听
    }

    yield* controller.stream;
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
      kbName: _kbName,
    );
  }

  @override
  Stream<VideoSummaryProcessingData> startDraftGeneration({
    required String kbid,
    String? userInitialPreference,
  }) async* {
    // 同步 kbid 供后续方法（fetchDraftResult / generateFinalSummary）使用
    this.kbid = kbid;

    // 每次开始新任务时重置状态
    _lastProgress = 0.0;
    _seenSequences = {};
    _estimator.reset();
    _statusLog.clear();

    if (kDebugMode) {
      debugPrint(
        '[HttpRepo] 开始创建任务 — kbid=$kbid videoId=$videoId '
        'baseUrl=${_taskService.dio.options.baseUrl}',
      );
    }

    // 0. 确保 WebSocket 已连接（最多等待 10 秒）
    try {
      await _wsClient.ensureConnected(timeout: const Duration(seconds: 10));
      if (kDebugMode) {
        debugPrint('[HttpRepo] WebSocket 连接就绪');
      }
    } catch (e) {
      debugPrint(
        '[HttpRepo] WebSocket 连接失败（${e.toString().split('\n').first}），将无法接收实时进度',
      );
      throw TaskFailedException('WebSocket 未连接，无法启动任务');
    }

    // 1. 创建任务（传入用户总结偏好）
    final ApiResponse<VideoSummaryTaskResponseData> createResp;
    try {
      createResp = await _taskService.createTask(
        kbid: kbid,
        videoId: videoId,
        userInitialPreference: userInitialPreference,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final conflict = TaskConflictData.tryExtract(e.response?.data);
        if (conflict != null) {
          throw TaskConflictException(
            existingTaskId: conflict.existingTaskId,
            kbid: conflict.kbid,
            message: conflict.message,
          );
        }
      }
      rethrow;
    }
    final data = createResp.data;
    if (data == null) {
      throw StateError('Task creation returned null data');
    }
    _taskId = data.taskId;
    _kbName = data.kbName;

    if (kDebugMode) {
      debugPrint(
        '[HttpRepo] 任务已创建 — taskId=$_taskId state=${data.workflowState} kbName=$_kbName',
      );
    }

    // 短路优化：后端已有初稿时（Phase-1 已完成），跳过 startAnalysis + WS，直接返回完成事件。
    // 避免重复执行（旧行为 bug）和不必要的 60s WS 等待。
    if (data.draftSummary != null && data.draftSummary!.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[HttpRepo] 后端已有初稿，跳过 WS 直接返回');
      }
      final shortcutController = StreamController<VideoSummaryProcessingData>();
      shortcutController.add(
        const VideoSummaryProcessingData(
          progress: 1.0,
          currentMessage: '初稿已生成',
          chunkProgress: VideoSummaryChunkProgressData(
            stage: VideoSummaryChunkProgressStage.finished,
            totalChunks: 1,
            doneCount: 1,
            overallPercent: 100,
          ),
          statusLog: [],
        ),
      );
      shortcutController.close();
      yield* shortcutController.stream;
      return;
    }

    // 2. 触发 Phase-1 分析工作流
    try {
      await _taskService.startAnalysis(_taskId!);
      if (kDebugMode) {
        debugPrint('[HttpRepo] 分析已启动 — taskId=$_taskId');
      }
    } catch (e) {
      debugPrint('[HttpRepo] startAnalysis 失败（可能后端已自动启动）: $e');
    }

    // 3. 纯 WebSocket 监听进度 — 严格对齐后端 WSEventEnvelope 消息
    final taskId = _taskId!;
    final wsStream = _wsClient.eventStream.where(
      (env) => env.scope == WSScope.videoSummaryTask && env.scopeId == taskId,
    );

    final controller = StreamController<VideoSummaryProcessingData>();
    StreamSubscription<WSEventEnvelope>? wsSubscription;

    // 首次事件超时：启动分析后 120 秒内必须收到第一条 WS 事件
    // 给 Celery Worker 冷启动留足余量（见 docs/ws-events.md 场景 16）
    Timer? firstEventTimeout;
    firstEventTimeout = Timer(const Duration(seconds: 120), () {
      if (!controller.isClosed) {
        debugPrint('[HttpRepo] WebSocket 首事件超时（120s 内未收到任何进度消息）');
        controller.addError(
          TimeoutException('任务启动超时，未收到后端进度反馈，taskId=$taskId'),
        );
        controller.close();
      }
    });

    // 总超时计时器：第一个事件到达后 900 秒内未收到 completed/error 事件则超时
    Timer? totalTimeout;
    const totalTimeoutDuration = Duration(seconds: 900);

    wsSubscription = wsStream.listen(
      (env) {
        // 防护：controller 已关闭则忽略后续事件（如重复 completed）
        if (controller.isClosed) return;

        // 跳过重连确认事件
        if (env.eventType == WSEventType.reconnectAck) {
          return;
        }

        // 去重：后端 Redis Pub/Sub 发布到 tenant + control 双通道，
        // 同一 sequence 的事件会到达两次，仅处理首次。
        final seqKey = '${env.scopeId}:${env.sequence}';
        if (_seenSequences.contains(seqKey)) return;
        _seenSequences.add(seqKey);
        // 限制去重集合大小，防止内存泄漏
        if (_seenSequences.length > 200) {
          _seenSequences = _seenSequences.skip(100).toSet();
        }

        // 收到第一个有效事件时：取消首事件超时，启动总超时
        if (firstEventTimeout != null) {
          firstEventTimeout!.cancel();
          firstEventTimeout = null;

          totalTimeout = Timer(totalTimeoutDuration, () {
            if (!controller.isClosed) {
              debugPrint(
                '[HttpRepo] WebSocket 进度超时（${totalTimeoutDuration.inSeconds}s 内未完成）',
              );
              controller.addError(
                TimeoutException(
                  '任务处理超时（${totalTimeoutDuration.inSeconds}s），taskId=$taskId',
                ),
              );
              controller.close();
            }
          });
        }

        if (env.eventType == WSEventType.error) {
          debugPrint('[HttpRepo] 收到 error 事件: ${env.message}');
          controller.addError(TaskFailedException(taskId));
          controller.close();
          return;
        }

        if (env.eventType == WSEventType.completed) {
          if (kDebugMode) {
            debugPrint('[HttpRepo] 收到 completed 事件 — taskId=$taskId');
          }
          // 驱动估算器到 100% 后取最终状态
          final finalChunkProgress = _estimator.estimate(
            wsProgress: 100,
            wsMessage: env.message,
            wsStageLabel: env.stage?.name,
            substage: env.substage,
            payload: env.payload,
          );
          controller.add(
            VideoSummaryProcessingData(
              progress: 1.0,
              currentMessage: env.message ?? '初稿生成完成',
              chunkProgress: finalChunkProgress,
              statusLog: List<String>.from(_statusLog),
            ),
          );
          controller.close();
          return;
        }

        // progress / status_update 事件：
        // 后端仅在 [[PROGRESS]] 消息携带具体进度值，其余状态消息 progress=null。
        // 对于 progress=null 的消息：保持上次进度不变，仅更新阶段和文本。

        // ── 状态日志：非 chunk_processing 的消息追加到日志 ──
        final msg = env.message;
        if (msg != null &&
            msg.isNotEmpty &&
            env.substage != 'chunk_processing') {
          _statusLog.add(msg);
          if (_statusLog.length > 20) {
            _statusLog.removeAt(0);
          }
        }

        // ── 单轨分片进度（优先从 payload 读取）──
        final chunkProgress = _estimator.estimate(
          wsProgress: env.progress,
          wsMessage: env.message,
          wsStageLabel: env.stage?.name,
          substage: env.substage,
          payload: env.payload,
        );

        // env.progress 现在准确（旧后端始终为 0），直接使用。
        // 对于纯文本状态消息（progress=null），保持上次值不变。
        final progressVal = env.progress != null
            ? env.progress! / 100.0
            : _lastProgress;
        _lastProgress = progressVal;

        final currentMessage = env.message ?? '';

        controller.add(
          VideoSummaryProcessingData(
            progress: progressVal,
            currentMessage: currentMessage,
            chunkProgress: chunkProgress,
            statusLog: List<String>.from(_statusLog),
          ),
        );

        if (kDebugMode) {
          debugPrint(
            '[HttpRepo] WS进度 — stage=${env.stage?.name} '
            'progress=${env.progress}% '
            'displayProgress=${(progressVal * 100).toStringAsFixed(0)}% '
            'msg=${env.message}',
          );
        }
      },
      onError: (e) {
        debugPrint('[HttpRepo] WebSocket stream error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      },
      onDone: () {
        debugPrint('[HttpRepo] WebSocket stream done — taskId=$taskId');
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    // 监听 WS 连接状态，断连时记录日志（恢复由 FlowController 并行轮询保证）
    StreamSubscription<WsConnectionState>? connStateSub;
    connStateSub = _connectionStateStream.listen((state) {
      if (state == WsConnectionState.disconnected ||
          state == WsConnectionState.reconnecting) {
        debugPrint(
          '[HttpRepo] WS connection $state — taskId=$taskId, '
          'progress=$_lastProgress',
        );
      }
    });

    controller.onCancel = () {
      firstEventTimeout?.cancel();
      totalTimeout?.cancel();
      wsSubscription?.cancel();
      connStateSub?.cancel();
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

    await _taskService.approveAndFinalize(
      taskId,
      editedAggregatedChunkInsights: draftParagraphs.join('\n\n'),
      humanGuidance: guidance,
    );
    if (kDebugMode) {
      debugPrint('[HttpRepo] 审批已提交 — taskId=$taskId');
    }

    // 2. 监听 WebSocket 等待终稿完成（后端在 workflow_state 变化时主动推送）
    final wsStream = _wsClient.eventStream.where(
      (env) => env.scope == WSScope.videoSummaryTask && env.scopeId == taskId,
    );

    final completer = Completer<void>();
    StreamSubscription<WSEventEnvelope>? wsSubscription;
    Timer? timeout;

    wsSubscription = wsStream.listen(
      (env) {
        if (env.eventType == WSEventType.completed) {
          if (kDebugMode) {
            debugPrint('[HttpRepo] Phase-2 WS completed — taskId=$taskId');
          }
          if (!completer.isCompleted) completer.complete();
        } else if (env.eventType == WSEventType.error) {
          debugPrint(
            '[HttpRepo] Phase-2 WS error — taskId=$taskId msg=${env.message}',
          );
          if (!completer.isCompleted) {
            completer.completeError(TaskFailedException(taskId));
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    // 总超时与 Phase-1 一致：900s 内未收到 completed/error 则超时
    timeout = Timer(const Duration(seconds: 900), () {
      if (!completer.isCompleted) {
        debugPrint('[HttpRepo] Phase-2 WS 超时（900s）— taskId=$taskId');
        completer.completeError(
          TimeoutException('终稿生成超时（900s），taskId=$taskId'),
        );
      }
    });

    try {
      await completer.future;
    } finally {
      wsSubscription.cancel();
      timeout.cancel();
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
  Future<VideoSummaryFinalResultData> resumeFinalGeneration(
    String taskId,
  ) async {
    _taskId = taskId;

    // 先检查任务是否已完成（短路优化 + 竞态窗口守护）
    try {
      final checkResp = await _taskService.getTask(taskId);
      final checkData = checkResp.data;
      if (checkData != null) {
        final state = WorkflowState.fromApi(checkData.workflowState);
        if (state == WorkflowState.completed) {
          if (kDebugMode) {
            debugPrint('[HttpRepo] resumeFinalGeneration — 后端已完成，直接获取数据');
          }
          final finalText =
              checkData.finalSummary ?? checkData.draftSummary ?? '';
          return VideoSummaryFinalResultData(
            body: finalText,
            references: const [],
          );
        }
      }
    } catch (_) {
      // 短路检查失败不影响后续 WS 监听
    }

    if (kDebugMode) {
      debugPrint('[HttpRepo] resumeFinalGeneration — 开始监听 WS taskId=$taskId');
    }

    // 监听 WebSocket 等待终稿完成（与 generateFinalSummary 相同的 WS 逻辑，
    // 但不调用 approveAndFinalize）
    final wsStream = _wsClient.eventStream.where(
      (env) => env.scope == WSScope.videoSummaryTask && env.scopeId == taskId,
    );

    final completer = Completer<void>();
    StreamSubscription<WSEventEnvelope>? wsSubscription;
    Timer? timeout;

    wsSubscription = wsStream.listen(
      (env) {
        if (env.eventType == WSEventType.completed) {
          if (kDebugMode) {
            debugPrint(
              '[HttpRepo] resumeFinalGeneration — WS completed taskId=$taskId',
            );
          }
          if (!completer.isCompleted) completer.complete();
        } else if (env.eventType == WSEventType.error) {
          debugPrint(
            '[HttpRepo] resumeFinalGeneration — WS error taskId=$taskId',
          );
          if (!completer.isCompleted) {
            completer.completeError(TaskFailedException(taskId));
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    timeout = Timer(const Duration(seconds: 120), () {
      if (!completer.isCompleted) {
        debugPrint(
          '[HttpRepo] resumeFinalGeneration — WS 超时（120s）taskId=$taskId',
        );
        completer.completeError(
          TimeoutException('终稿生成超时（120s），taskId=$taskId'),
        );
      }
    });

    try {
      await completer.future;
    } finally {
      wsSubscription.cancel();
      timeout.cancel();
    }

    // 获取最终任务数据
    final resp = await _taskService.getTask(taskId);
    final dto = resp.data;
    if (dto == null) {
      throw StateError('Task $taskId not found after final generation');
    }

    final finalText = dto.finalSummary ?? dto.draftSummary ?? '';

    return VideoSummaryFinalResultData(body: finalText, references: const []);
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
      throw UnimplementedError(
        'VideoQAService not injected — add videoQAService to provider',
      );
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
              controller.add(
                VideoSummaryChatReplyData(text: answerBuffer.toString()),
              );
            }
          } else if (event.type == SSEEventType.done) {
            final done = event.parseData<TimeTravelQADoneData>(
              TimeTravelQADoneData.fromJson,
            );
            if (done?.answerContent != null &&
                done!.answerContent!.isNotEmpty) {
              controller.add(
                VideoSummaryChatReplyData(
                  text: done.answerContent!,
                  citedSources: done.citedSources,
                ),
              );
            }
            controller.close();
          } else if (event.type == SSEEventType.error) {
            controller.addError(
              Exception(event.data?.toString() ?? 'SSE stream error'),
            );
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
