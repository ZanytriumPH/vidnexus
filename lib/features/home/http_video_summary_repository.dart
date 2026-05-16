import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/polling/task_poller.dart';
import '../../services/task_service.dart';
import 'domain/video_summary_domain_models.dart';
import 'video_summary_models.dart';
import 'video_summary_repository.dart';

/// 基于 HTTP 的真实 VideoSummaryRepository 实现。
///
/// 使用方式：
/// - 通过 Provider 注入，替换 [FakeVideoSummaryRepository]
/// - [kbid] 和 [videoId] 在构造时指定（后续可由 Controller 动态设置）
class HttpVideoSummaryRepository extends VideoSummaryRepository {
  HttpVideoSummaryRepository({
    required TaskService taskService,
    TaskPoller? taskPoller,
    required this.kbid,
    required this.videoId,
  })  : _taskService = taskService,
        _taskPoller = taskPoller ??
            TaskPoller(taskService: taskService);

  final TaskService _taskService;
  final TaskPoller _taskPoller;

  /// 当前知识库 ID。
  final String kbid;

  /// 当前视频 ID。
  final String videoId;

  String? _taskId;

  // ---- VideoSummaryRepository 实现 ----

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

  @override
  Stream<VideoSummaryProcessingData> startDraftGeneration() async* {
    if (kDebugMode) {
      debugPrint(
        '[HttpRepo] 开始创建任务 — kbid=$kbid videoId=$videoId '
        'baseUrl=${_taskService.dio.options.baseUrl}',
      );
    }

    // 1. 创建任务
    final createResp = await _taskService.createTask(
      kbid: kbid,
      videoId: videoId,
    );
    final data = createResp.data;
    if (data == null) {
      throw StateError('Task creation returned null data');
    }
    _taskId = data.taskId;

    if (kDebugMode) {
      debugPrint('[HttpRepo] 任务已创建 — taskId=$_taskId state=${data.workflowState}');
    }

    // 2. 轮询进度
    yield* _taskPoller.pollTask(_taskId!);
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

    // 1. 提交用户指引
    await _taskService.updateTask(
      taskId,
      userGuidance: guidance,
      draftSummary: draftParagraphs.join('\n\n'),
    );

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
  Future<VideoSummaryChatReplyData> sendSummaryChatMessage(String message) async {
    // Phase 5 实现，当前抛出 UnimplementedError。
    throw UnimplementedError(
      'sendSummaryChatMessage will be implemented in Phase 5 (VideoQAService)',
    );
  }
}
