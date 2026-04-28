import 'dart:async';

import 'video_summary_models.dart';
import 'video_summary_repository.dart';

class FakeVideoSummaryRepository extends VideoSummaryRepository {
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
  Stream<ProcessingSnapshot> startDraftGeneration() async* {
    const totalFrames = 11;

    for (var frame = 0; frame <= totalFrames; frame++) {
      final progress = frame / totalFrames;
      final stepOneProgress = (progress * 160).round().clamp(0, 100);
      final stepTwoProgress = ((progress - 0.18) * 145).round().clamp(0, 100);
      final stepThreeProgress = ((progress - 0.42) * 175).round().clamp(0, 100);

      yield ProcessingSnapshot(
        progress: progress,
        statusLabel: progress >= 1 ? '处理完成' : '处理中',
        headline: '正在生成结构化初稿',
        etaLabel: progress >= 1
            ? '全部处理步骤已完成，准备进入草稿整理。'
            : '当前主步骤：融合语音、关键词和版面信息，准备输出第一版结构梳理。',
        badges: [
          ProcessingBadge(label: '语音转写 已完成', active: stepOneProgress >= 100),
          ProcessingBadge(
            label: stepTwoProgress >= 100 ? '多轮融合 已完成' : '多轮融合 进行中',
            active: stepTwoProgress > 0 && stepTwoProgress < 100,
          ),
          ProcessingBadge(
            label: stepThreeProgress >= 100 ? '总结卡片可视化 已完成' : '总结卡片可视化 处理中',
            active: stepThreeProgress > 0 && stepThreeProgress < 100,
          ),
        ],
        steps: [
          ProcessingStep(
            label: '语音转写与切片',
            detail: stepOneProgress >= 100
                ? '142 秒文本已完成校准。'
                : '正在抽取片段并比对字幕断点。',
            progress: stepOneProgress,
          ),
          ProcessingStep(
            label: '关键词归因与对齐',
            detail: stepTwoProgress >= 100
                ? '96 处关键点已归入片段，质检线已完成。'
                : '96 处关键点正在归入片段，质检线继续进行中。',
            progress: stepTwoProgress,
          ),
          ProcessingStep(
            label: '章节整合与摘要初稿',
            detail: stepThreeProgress >= 100
                ? '章节总括与首版摘要已整理完毕。'
                : '正在组织段间跳转语句与第一版总括。',
            progress: stepThreeProgress,
          ),
        ],
      );

      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
  }

  @override
  Future<DraftResult> fetchDraftResult() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const DraftResult(
      overview: '初稿已生成，处理详情已自动折叠',
      paragraphs: [
        '《视频总结》这次结构化内容初稿，系统共检出并修订了 Agent 结构的核心概念和底层细节。讲解者结合 LangChain 框架，详细分析了 Agent 的工作流程，包括用户输入、查询循环和工具调用等模块。',
        '综合总结：该视频分片通过音频与页面结合，深入探讨了技术路线化的重要意义及其在面对初行之复杂中的应用价值。',
      ],
      suggestionHint: '例如：请先给我按行业、声线和行动建议展开，重点扩充已结构化结论。',
    );
  }

  @override
  Future<FinalSummaryData> generateFinalSummary({
    required String guidance,
    required DraftResult draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return FinalSummaryData(
      summaryTitle: '最终稿',
      summaryBody:
          '该视频通过文档内容和图示，系统性地讲解了 Agent 机制的核心概念和应用框架。讲解者结合 LangChain 框架，详细分析了 Agent 的工作流程，包括用户输入、查询循环和工具调用等模块。${guidance.isEmpty ? '' : ' 当前版本额外吸收了你的要求：$guidance'}',
      summaryTimestampLabel: '汇总片段 00:12:30 - 00:14:00',
      timestampChips: const [
        TimestampChipData(label: '00:12:30 - 00:14:00', note: '核心机制与工作流'),
        TimestampChipData(label: '00:08:20 - 00:10:40', note: '工具调用与循环'),
      ],
      messages: const [
        ChatMessage(
          sender: SummaryChatSender.system,
          text: '如果用户使用时间范围，那么发送消息出去的时候应该也会显示这个时间范围',
        ),
        ChatMessage(
          sender: SummaryChatSender.system,
          text: '如果你点回转的视频模块，我会继续帮你同步话题窗口直到被证实，再回答你的问题。',
        ),
      ],
    );
  }

  @override
  Future<ChatMessage> sendSummaryChatMessage(String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    return ChatMessage(
      sender: SummaryChatSender.system,
      text: '已根据“$message”补了一轮解释。我会优先围绕该片段的前后文、调用链和潜在限制继续展开。',
      timestampLabel: '00:12:30 - 00:14:00',
    );
  }
}
