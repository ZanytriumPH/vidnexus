import 'domain/video_summary_domain_models.dart';
import 'video_summary_processing_event_source.dart';

class FakeVideoSummaryProcessingEventSource
    extends DelayedVideoSummaryProcessingEventSource {
  FakeVideoSummaryProcessingEventSource()
    : super(_frames);

  static const int _mockChunkCount = 8;

  static final List<DelayedVideoSummaryProcessingEventFrame> _frames = [
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.acquiringVideo,
        message: '正在获取并保存视频文件，准备进入本地预处理。',
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.extractingAudio,
        message: '音轨已识别，正在从视频流中分离音频。',
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.extractingFrames,
        message: '正在抽取关键帧并建立视觉证据索引。',
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.transcribingAudio,
        message: 'Whisper 转录进行中，正在回拼时间戳片段。',
      ),
      delay: Duration(milliseconds: 720),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.bootingWorkflow,
        message: 'LangGraph 状态机已点火，正在装配 thread 与并发模式。',
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.planningChunks,
        message: '正在按时间线规划 8 个分片任务。',
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 0,
          visionDone: 0,
          synthesisDone: 0,
          overallDone: 0,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 0,
        ),
      ),
      delay: Duration(milliseconds: 240),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.dispatchingChunks,
        message: '分片任务已派发，等待音频与视觉 worker 回传。',
      ),
      delay: Duration(milliseconds: 300),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.analyzingAudioChunks,
        message: '音频 worker 正在回收首批结构化洞察。',
      ),
      delay: Duration(milliseconds: 180),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 2,
          visionDone: 0,
          synthesisDone: 0,
          overallDone: 2,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 8,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.analyzingVisionChunks,
        message: '视觉 worker 正在补齐画面证据和关键帧检索结果。',
      ),
      delay: Duration(milliseconds: 180),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 3,
          visionDone: 2,
          synthesisDone: 0,
          overallDone: 5,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 21,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.analyzingAudioChunks,
        message: '音频线索已推进到中段，正在与视觉观察并行汇流。',
      ),
      delay: Duration(milliseconds: 160),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 6,
          visionDone: 4,
          synthesisDone: 0,
          overallDone: 10,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 42,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.analyzingVisionChunks,
        message: '视觉线索已覆盖大部分分片，剩余片段继续补齐。',
      ),
      delay: Duration(milliseconds: 180),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 8,
          visionDone: 6,
          synthesisDone: 0,
          overallDone: 14,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 58,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.synthesizingChunks,
        message: '音视频证据开始融合，正在生成首批分片摘要。',
      ),
      delay: Duration(milliseconds: 180),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 8,
          visionDone: 8,
          synthesisDone: 3,
          overallDone: 19,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 79,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.synthesizingChunks,
        message: '分片融合继续推进，正在组织跨段落跳转语句。',
      ),
      delay: Duration(milliseconds: 180),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.running,
          totalChunks: _mockChunkCount,
          audioDone: 8,
          visionDone: 8,
          synthesisDone: 6,
          overallDone: 22,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 92,
        ),
      ),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingStatusEvent(
        stage: VideoSummaryProcessingStage.aggregatingChunks,
        message: '全部分片已回流，正在按时间线整理统一证据底稿。',
      ),
      delay: Duration(milliseconds: 220),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingChunkProgressEvent(
        progress: VideoSummaryChunkProgressData(
          stage: VideoSummaryChunkProgressStage.finished,
          totalChunks: _mockChunkCount,
          audioDone: 8,
          visionDone: 8,
          synthesisDone: 8,
          overallDone: 24,
          overallTotal: _mockChunkCount * 3,
          overallPercent: 100,
        ),
      ),
      delay: Duration(milliseconds: 200),
    ),
    const DelayedVideoSummaryProcessingEventFrame(
      event: VideoSummaryProcessingReviewReadyEvent(),
      delay: Duration(milliseconds: 320),
    ),
  ];
}