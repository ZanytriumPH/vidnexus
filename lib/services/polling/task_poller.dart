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
  /// - WAITING_USER_APPROVAL / COMPLETED → 流正常关闭
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
    final message = _mapMessage(state, dto);
    final progress = _estimateProgress(state, tick, dto);
    final int progressPercent = (progress * 100).round();

    return VideoSummaryProcessingData(
      progress: progress,
      currentMessage: message,
      chunkProgress: VideoSummaryChunkProgressData(
        stage: progressPercent >= 100
            ? VideoSummaryChunkProgressStage.finished
            : VideoSummaryChunkProgressStage.running,
        totalChunks: 5,
        doneCount: ((progressPercent / 100) * 5).round().clamp(0, 5),
        overallPercent: progressPercent,
      ),
    );
  }

  /// 阶段中文消息。
  String _mapMessage(WorkflowState state, VideoSummaryTaskResponseData dto) {
    final title = dto.title ?? '';
    return switch (state) {
      WorkflowState.draftGenerating => '正在生成结构化初稿…$title',
      WorkflowState.waitingUserApproval => '初稿已生成，请查看并编辑',
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
        return (0.1 + (tick * 0.075)).clamp(0.0, 0.85);
      case WorkflowState.waitingUserApproval:
        return 0.9;
      case WorkflowState.finalGenerating:
        return (0.85 + (tick * 0.03)).clamp(0.0, 0.99);
      case WorkflowState.completed:
        return 1.0;
      case WorkflowState.failed:
        return 0.0;
    }
  }
}
