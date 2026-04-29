import 'domain/video_summary_domain_models.dart';
import 'video_summary_processing_event_adapter.dart';
import 'video_summary_processing_event_source.dart';
import 'video_summary_repository.dart';

/// 基于事件流的数据仓储基类。
///
/// 当前 Fake repository 和未来的 Http/SSE/WebSocket repository 都可以复用这里的
/// 事件适配逻辑：事件源负责接收后端事件，基类负责把事件流转成稳定的 raw data contract。
abstract class StreamBackedVideoSummaryRepository
    extends VideoSummaryRepository {
  const StreamBackedVideoSummaryRepository({
    VideoSummaryProcessingEventAdapter adapter =
        const VideoSummaryProcessingEventAdapter(),
  }) : _adapter = adapter;

  final VideoSummaryProcessingEventAdapter _adapter;

  VideoSummaryProcessingEventSource createProcessingEventSource();

  @override
  Stream<VideoSummaryProcessingData> startDraftGeneration() {
    return _adapter.bind(createProcessingEventSource().connect());
  }
}