import 'dart:async';

import 'domain/video_summary_domain_models.dart';

/// 后端处理事件的防腐层定义。
///
/// repository 不直接把这层事件暴露给页面；它只在数据源与 raw data 适配器之间流动，
/// 用来为未来的 SSE / WebSocket / 轮询实现预留统一入口。
sealed class VideoSummaryProcessingBackendEvent {
  const VideoSummaryProcessingBackendEvent();
}

class VideoSummaryProcessingStatusEvent
    extends VideoSummaryProcessingBackendEvent {
  const VideoSummaryProcessingStatusEvent({
    required this.stage,
    required this.message,
  });

  final VideoSummaryProcessingStage stage;
  final String message;
}

class VideoSummaryProcessingChunkProgressEvent
    extends VideoSummaryProcessingBackendEvent {
  const VideoSummaryProcessingChunkProgressEvent({required this.progress});

  final VideoSummaryChunkProgressData progress;
}

class VideoSummaryProcessingReviewReadyEvent
    extends VideoSummaryProcessingBackendEvent {
  const VideoSummaryProcessingReviewReadyEvent({
    this.message = '待审稿已封装完成，准备切换到移动端初稿编辑态。',
  });

  final String message;
}

abstract class VideoSummaryProcessingEventSource {
  const VideoSummaryProcessingEventSource();

  Stream<VideoSummaryProcessingBackendEvent> connect();
}

class DelayedVideoSummaryProcessingEventSource
    extends VideoSummaryProcessingEventSource {
  const DelayedVideoSummaryProcessingEventSource(this.frames);

  final List<DelayedVideoSummaryProcessingEventFrame> frames;

  @override
  Stream<VideoSummaryProcessingBackendEvent> connect() async* {
    for (final frame in frames) {
      yield frame.event;
      await Future<void>.delayed(frame.delay);
    }
  }
}

class DelayedVideoSummaryProcessingEventFrame {
  const DelayedVideoSummaryProcessingEventFrame({
    required this.event,
    this.delay = const Duration(milliseconds: 520),
  });

  final VideoSummaryProcessingBackendEvent event;
  final Duration delay;
}