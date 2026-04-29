import 'domain/video_summary_domain_models.dart';
import 'fake_video_summary_processing_event_source.dart';
import 'stream_backed_video_summary_repository.dart';
import 'video_summary_models.dart';

class FakeVideoSummaryRepository extends StreamBackedVideoSummaryRepository {
  const FakeVideoSummaryRepository();

  @override
  VideoAssetInfo getVideoAsset() {
    return const VideoAssetInfo(
      title: 'product-review.mp4',
      durationLabel: '18m 24s',
      sourceLabel: '产品源视频',
      fileName: 'product-review.mp4',
    );
  }

  @override
  FakeVideoSummaryProcessingEventSource createProcessingEventSource() {
    return FakeVideoSummaryProcessingEventSource();
  }

  @override
  Future<VideoSummaryDraftData> fetchDraftResult() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const VideoSummaryDraftData(
      paragraphs: [
        '《视频总结》这次结构化内容初稿，系统共检出并修订了 Agent 结构的核心概念和底层细节。讲解者结合 LangChain 框架，详细分析了 Agent 的工作流程，包括用户输入、查询循环和工具调用等模块。',
        '综合总结：该视频分片通过音频与页面结合，深入探讨了技术路线化的重要意义及其在面对初行之复杂中的应用价值。',
      ],
    );
  }

  @override
  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return VideoSummaryFinalResultData(
      body:
          '该视频通过文档内容和图示，系统性地讲解了 Agent 机制的核心概念和应用框架。讲解者结合 LangChain 框架，详细分析了 Agent 的工作流程，包括用户输入、查询循环和工具调用等模块。${guidance.isEmpty ? '' : ' 当前版本额外吸收了你的要求：$guidance'}',
      references: const [
        VideoSummaryReferenceRange(
          startSeconds: 12 * 60 + 30,
          endSeconds: 14 * 60,
          topic: '核心机制与工作流',
        ),
        VideoSummaryReferenceRange(
          startSeconds: 8 * 60 + 20,
          endSeconds: 10 * 60 + 40,
          topic: '工具调用与循环',
        ),
      ],
    );
  }

  @override
  Future<VideoSummaryChatReplyData> sendSummaryChatMessage(String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    return const VideoSummaryChatReplyData(
      text: '已根据你的问题补了一轮解释。我会优先围绕该片段的前后文、调用链和潜在限制继续展开。',
      reference: VideoSummaryReferenceRange(
        startSeconds: 12 * 60 + 30,
        endSeconds: 14 * 60,
        topic: '核心机制与工作流',
      ),
    );
  }
}
