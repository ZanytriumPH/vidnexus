import 'dart:async';

import '../../features/home/domain/video_summary_domain_models.dart';
import '../api/api_config.dart';
import '../video_qa_service.dart';

/// QA 回答异步生成超时异常。
class QAPollingTimeoutException implements Exception {
  const QAPollingTimeoutException(this.qaId, this.elapsed);

  final String qaId;
  final Duration elapsed;

  @override
  String toString() => 'QA polling timeout for $qaId after ${elapsed.inSeconds}s';
}

/// 将 VideoQAService 的 QA 轮询转化为 [VideoSummaryChatReplyData]。
class QAPoller {
  QAPoller({
    required VideoQAService videoQAService,
    Duration interval = ApiConfig.defaultPollingInterval,
    Duration timeout = ApiConfig.qaPollingTimeout,
  })  : _videoQAService = videoQAService,
        _interval = interval,
        _timeout = timeout;

  final VideoQAService _videoQAService;
  final Duration _interval;
  final Duration _timeout;

  /// 轮询 Video QA 直到 answer_content 非 null。
  Future<VideoSummaryChatReplyData> waitForAnswer({
    required String taskId,
    required String qaId,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (true) {
      if (stopwatch.elapsed > _timeout) {
        throw QAPollingTimeoutException(qaId, stopwatch.elapsed);
      }

      final resp = await _videoQAService.getQA(taskId, qaId);
      final dto = resp.data;
      if (dto != null && dto.answerContent != null && dto.answerContent!.isNotEmpty) {
        return VideoSummaryChatReplyData(text: dto.answerContent!);
      }

      await Future<void>.delayed(_interval);
    }
  }
}
