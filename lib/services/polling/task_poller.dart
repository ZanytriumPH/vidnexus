import 'dart:async';

import '../../features/home/domain/video_summary_domain_models.dart';
import '../../services/models/video_summary_task_dto.dart';
import '../api/api_config.dart';
import '../task_service.dart';

/// 任务处理超时异常。
class PollingTimeoutException implements Exception {
  const PollingTimeoutException(this.taskId, this.elapsed);

  final String taskId;
  final Duration elapsed;

  @override
  String toString() => 'Polling timeout for task $taskId after ${elapsed.inSeconds}s';
}

/// 任务处理失败异常（workflow_state = FAILED）。
class TaskFailedException implements Exception {
  const TaskFailedException(this.taskId);

  final String taskId;

  @override
  String toString() => 'Task $taskId failed on server';
}

/// 将 TaskService 的轮询结果转化为 [VideoSummaryProcessingData] 流。
///
/// 使用方式：
/// ```dart
/// final poller = TaskPoller(taskService: taskService);
/// final stream = poller.pollTask(taskId);
/// ```
class TaskPoller {
  TaskPoller({
    required TaskService taskService,
    Duration interval = ApiConfig.defaultPollingInterval,
    Duration timeout = ApiConfig.defaultPollingTimeout,
  })  : _taskService = taskService,
        _interval = interval,
        _timeout = timeout;

  final TaskService _taskService;
  final Duration _interval;
  final Duration _timeout;

  /// 轮询 task 直到终态，每次状态变化产出 [VideoSummaryProcessingData]。
  ///
  /// 终态规则：
  /// - DRAFT_READY / COMPLETED → 流正常关闭
  /// - FAILED → 抛出 [TaskFailedException]
  /// - 超时 → 抛出 [PollingTimeoutException]
  Stream<VideoSummaryProcessingData> pollTask(String taskId) async* {
    final stopwatch = Stopwatch()..start();

    WorkflowState? previousState;
    int tick = 0;

    while (true) {
      if (stopwatch.elapsed > _timeout) {
        throw PollingTimeoutException(taskId, stopwatch.elapsed);
      }

      final resp = await _taskService.getTask(taskId);
      final dto = resp.data;
      if (dto == null) {
        await Future<void>.delayed(_interval);
        continue;
      }

      final currentState = WorkflowState.fromApi(dto.workflowState);

      // 仅在状态首次出现或 progress 更新时 yield
      final isNewState = currentState != previousState;
      final isProgressUpdate = currentState == WorkflowState.draftGenerating ||
          currentState == WorkflowState.finalGenerating;

      if (isNewState || isProgressUpdate) {
        previousState = currentState;
        yield _buildProcessingData(dto, currentState, tick);
        tick++;
      }

      if (currentState == WorkflowState.failed) {
        throw TaskFailedException(taskId);
      }

      if (currentState.isTerminal) {
        return; // 流正常关闭
      }

      await Future<void>.delayed(_interval);
    }
  }

  /// 将 DTO + 状态转换为阶段进度数据。
  VideoSummaryProcessingData _buildProcessingData(
    VideoSummaryTaskResponseData dto,
    WorkflowState state,
    int tick,
  ) {
    final stage = _mapStage(state);
    final message = _mapMessage(state, dto);
    final progress = _estimateProgress(state, tick, dto);

    return VideoSummaryProcessingData(
      progress: progress,
      currentStage: stage,
      currentMessage: message,
      steps: _buildSteps(state, progress),
    );
  }

  /// WorkflowState → VideoSummaryProcessingStage 映射。
  VideoSummaryProcessingStage _mapStage(WorkflowState state) {
    return switch (state) {
      WorkflowState.draftGenerating => VideoSummaryProcessingStage.dispatchingChunks,
      WorkflowState.draftReady => VideoSummaryProcessingStage.waitingHumanReview,
      WorkflowState.finalGenerating => VideoSummaryProcessingStage.aggregatingChunks,
      WorkflowState.completed => VideoSummaryProcessingStage.waitingHumanReview,
      WorkflowState.failed => VideoSummaryProcessingStage.acquiringVideo,
    };
  }

  /// 阶段中文消息。
  String _mapMessage(WorkflowState state, VideoSummaryTaskResponseData dto) {
    final title = dto.title ?? '';
    return switch (state) {
      WorkflowState.draftGenerating => '正在生成结构化初稿…$title',
      WorkflowState.draftReady => '初稿已生成，请查看并编辑',
      WorkflowState.finalGenerating => '正在根据您的指引生成终稿…',
      WorkflowState.completed => '终稿已完成',
      WorkflowState.failed => '处理失败，请重试',
    };
  }

  /// 基于 tick 和状态估算进度（0.0 ~ 1.0）。
  double _estimateProgress(
    WorkflowState state,
    int tick,
    VideoSummaryTaskResponseData dto,
  ) {
    switch (state) {
      case WorkflowState.draftGenerating:
        // 10 ticks 内从 0.1 → 0.85
        return (0.1 + (tick * 0.075)).clamp(0.0, 0.85);
      case WorkflowState.draftReady:
        return 0.9;
      case WorkflowState.finalGenerating:
        // 5 ticks 内从 0.9 → 0.99
        return (0.85 + (tick * 0.03)).clamp(0.0, 0.99);
      case WorkflowState.completed:
        return 1.0;
      case WorkflowState.failed:
        return 0.0;
    }
  }

  /// 构造处理步骤列表。
  List<VideoSummaryProcessingStepData> _buildSteps(
    WorkflowState state,
    double progress,
  ) {
    final preprocessProgress = state == WorkflowState.draftGenerating ||
            state == WorkflowState.finalGenerating ||
            state == WorkflowState.draftReady ||
            state == WorkflowState.completed
        ? 100
        : 0;

    final analysisProgress = switch (state) {
      WorkflowState.draftReady || WorkflowState.completed => 100,
      WorkflowState.draftGenerating ||
      WorkflowState.finalGenerating =>
        ((progress - 0.1) / 0.75 * 100).round().clamp(0, 100),
      _ => 0,
    };

    final synthesisProgress = switch (state) {
      WorkflowState.completed => 100,
      WorkflowState.draftReady => 85,
      WorkflowState.finalGenerating =>
        ((progress - 0.85) / 0.14 * 100).round().clamp(0, 100),
      _ => 0,
    };

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
}
