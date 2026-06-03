import 'dart:math' as math;

import 'video_summary_domain_models.dart';

/// 分片进度估算器。
///
/// 后端 WebSocket 下发的是单一 overall_percent + stage，
/// 不含 total_chunks / audio_done / vision_done / synthesis_done
/// 等分片粒度数据。本估算器基于阶段语义 + 历史快照推导 4 轨进度，
/// 使前端可以渲染对标 Streamlit 的并行进度条。
///
/// **关键设计**：估算器**永不返回 null**。
/// 即使后端尚未发送任何 [[PROGRESS]] 分片消息（例如 Celery 仍在
/// LangGraph 初始化阶段），也会基于已收到的纯文本状态消息数量
/// 生成一个缓慢增长的保守进度，确保新 4 轨 UI 从点击"开始生成初稿"
/// 的第一秒就激活显示。
class ChunkProgressEstimator {
  VideoSummaryChunkProgressData? _previous;

  /// 已收到的纯文本状态消息数量（用于无 [[PROGRESS]] 时的粗粒度模拟）。
  int _statusMessageCount = 0;

  /// 是否已经收到过 [[PROGRESS]] 分片消息。
  bool _hasReceivedChunkProgress = false;

  /// 最近一次输入的原始进度值 (0-100)，来自 WS 的 progress 字段或模拟值。
  /// 此值与后端 overall_percent 一一对应，供 HeroCard 总体进度条使用。
  int _lastRawProgress = 0;

  /// HeroCard 总体进度条应使用的百分比 (0-100)。
  int get lastDrivingProgress => _lastRawProgress;

  /// 尝试从 WS message 文本中提取 "Chunk processing: X/Y" 信息。
  ///
  /// 返回 `(overallDone, overallTotal)`，解析失败返回 null。
  static (int, int)? _tryParseMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    final match =
        RegExp(r'Chunk processing:\s*(\d+)\s*/\s*(\d+)').firstMatch(message);
    if (match == null) return null;
    final done = int.tryParse(match.group(1)!);
    final total = int.tryParse(match.group(2)!);
    if (done == null || total == null) return null;
    return (done, total);
  }

  /// 输入一条 WS 事件，输出估算的分片进度（永不返回 null）。
  ///
  /// - [wsProgress]: WS 的 `progress` 字段 (0-100)，可能为 null。
  /// - [wsMessage]: WS 的 `message` 字段。
  /// - [wsStageLabel]: WS 的 `stage` 枚举名（如 "analysis"）。
  /// - [substage]: WS 的 `substage` 字段。
  VideoSummaryChunkProgressData estimate({
    required int? wsProgress,
    required String? wsMessage,
    required String? wsStageLabel,
    required String? substage,
  }) {
    final isChunkProgress = substage == 'chunk_processing';

    // ── 收到 [[PROGRESS]] 分片消息：使用真实 progress 值 ──
    if (isChunkProgress && wsProgress != null) {
      _hasReceivedChunkProgress = true;
      _lastRawProgress = wsProgress;
      return _estimateFromRealProgress(
        wsProgress: wsProgress,
        wsMessage: wsMessage,
        wsStageLabel: wsStageLabel,
      );
    }

    // ── 收到其他带 progress 的消息（如视频预处理阶段）──
    if (wsProgress != null) {
      _lastRawProgress = wsProgress;
      return _estimateFromRealProgress(
        wsProgress: wsProgress,
        wsMessage: wsMessage,
        wsStageLabel: wsStageLabel,
      );
    }

    // ── 纯文本状态消息（无 progress）：用消息数模拟缓慢增长 ──
    _statusMessageCount++;

    // 如果之前已经收到过真实分片进度，则保持上次值不变
    if (_hasReceivedChunkProgress && _previous != null) {
      return _previous!;
    }

    // 在收到第一条 [[PROGRESS]] 之前，基于消息数生成保守的初始化进度。
    final simulatedPercent =
        math.min(15, (_statusMessageCount * 2.5).round());
    _lastRawProgress = simulatedPercent;

    return _buildSimulatedProgress(simulatedPercent);
  }

  /// 使用后端下发的真实 progress 值估算 4 轨进度。
  VideoSummaryChunkProgressData _estimateFromRealProgress({
    required int wsProgress,
    required String? wsMessage,
    required String? wsStageLabel,
  }) {
    // 尝试从 message 提取 overall_done/overall_total，用于校准 totalChunks
    final parsed = _tryParseMessage(wsMessage);
    int? resolvedTotalChunks;
    if (parsed != null) {
      final (_, overallTotal) = parsed;
      resolvedTotalChunks = overallTotal ~/ 2;
    }

    final effectiveTotalChunks =
        resolvedTotalChunks ?? _previous?.totalChunks ?? 5;

    final fresh = VideoSummaryChunkProgressData.estimate(
      wsProgress: wsProgress,
      wsStageLabel: wsStageLabel,
      previous: null,
    );

    // 不回退合并
    final merged = VideoSummaryChunkProgressData(
      stage: wsProgress >= 100
          ? VideoSummaryChunkProgressStage.finished
          : VideoSummaryChunkProgressStage.running,
      totalChunks: effectiveTotalChunks,
      audioDone: math.max(
        fresh.audioDone.clamp(0, effectiveTotalChunks),
        _previous?.audioDone ?? 0,
      ),
      visionDone: math.max(
        fresh.visionDone.clamp(0, effectiveTotalChunks),
        _previous?.visionDone ?? 0,
      ),
      synthesisDone: math.max(
        fresh.synthesisDone.clamp(0, effectiveTotalChunks),
        _previous?.synthesisDone ?? 0,
      ),
      overallDone: math.max(
        fresh.overallDone,
        _previous?.overallDone ?? 0,
      ),
      overallTotal: effectiveTotalChunks * 2,
      overallPercent: math.max(
        fresh.overallPercent,
        _previous?.overallPercent ?? 0,
      ),
    );

    _previous = merged;
    return merged;
  }

  /// 在收到真实分片进度前，基于模拟百分比构建保守进度。
  VideoSummaryChunkProgressData _buildSimulatedProgress(
    int simulatedPercent,
  ) {
    const defaultChunks = 5;
    final totalChunks = _previous?.totalChunks ?? defaultChunks;

    // 初始化阶段：音频先有一点点进展，视觉和融合为 0
    final audioDone =
        (simulatedPercent / 100 * totalChunks * 1.5).round().clamp(0, totalChunks);
    final visionDone =
        (simulatedPercent / 100 * totalChunks * 0.3).round().clamp(0, totalChunks);
    final synthesisDone = 0;

    final overallTotal = totalChunks * 2;
    final overallDone = (audioDone + visionDone).clamp(0, overallTotal);
    final overallPercent = overallTotal > 0
        ? (overallDone / overallTotal * 100).round()
        : 0;

    final result = VideoSummaryChunkProgressData(
      stage: VideoSummaryChunkProgressStage.running,
      totalChunks: totalChunks,
      audioDone: audioDone,
      visionDone: visionDone,
      synthesisDone: synthesisDone,
      overallDone: overallDone,
      overallTotal: overallTotal,
      overallPercent: overallPercent,
    );

    _previous = result;
    return result;
  }

  /// 重置内部状态（新任务开始时调用）。
  void reset() {
    _previous = null;
    _statusMessageCount = 0;
    _hasReceivedChunkProgress = false;
    _lastRawProgress = 0;
  }
}
