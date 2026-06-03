import 'dart:math' as math;

import 'video_summary_domain_models.dart';

/// 分片进度估算器。
///
/// 新后端 WebSocket 下发：
/// - `progress` (envelope 层): 0-100 总体百分比（现在准确）
/// - `payload`: `{total_chunks, done_count, overall_percent, stage}`
///
/// 本估算器的职责简化为：
/// 1. 从 payload 读取 honest 数据
/// 2. payload 为空时用 wsProgress 近似
/// 3. 与历史快照做非回归合并
///
/// 不再需要 3 轨伪造、message 解析、或模拟进度。
class ChunkProgressEstimator {
  VideoSummaryChunkProgressData? _previous;

  /// 最近一次输入的原始进度值 (0-100)，供 HeroCard 总体进度条使用。
  int _lastRawProgress = 0;

  /// HeroCard 总体进度条应使用的百分比 (0-100)。
  int get lastDrivingProgress => _lastRawProgress;

  /// 输入一条 WS 事件，输出估算的分片进度（永不返回 null）。
  ///
  /// - [wsProgress]: WS 的 `progress` 字段 (0-100)，可能为 null。
  /// - [wsMessage]: WS 的 `message` 字段（保留以备后续使用）。
  /// - [wsStageLabel]: WS 的 `stage` 枚举名。
  /// - [substage]: WS 的 `substage` 字段。
  /// - [payload]: WS 的 `payload` 字段（新后端主数据源）。
  VideoSummaryChunkProgressData estimate({
    required int? wsProgress,
    required String? wsMessage,
    required String? wsStageLabel,
    required String? substage,
    Map<String, dynamic>? payload,
  }) {
    // ── 1. 从 payload（优先）或 wsProgress（降级）构建新鲜数据 ──
    final VideoSummaryChunkProgressData fresh;

    if (payload != null && payload.isNotEmpty) {
      // 主路径：后端 payload 有 honest 数据
      fresh = VideoSummaryChunkProgressData.fromPayload(
        payload,
        fallbackTotalChunks: _previous?.totalChunks ?? 5,
      );
    } else if (wsProgress != null) {
      // 降级：payload 为空但有 progress 值（非分片进度事件）
      final totalChunks = _previous?.totalChunks ?? 5;
      fresh = VideoSummaryChunkProgressData(
        stage: wsProgress >= 100
            ? VideoSummaryChunkProgressStage.finished
            : VideoSummaryChunkProgressStage.running,
        totalChunks: totalChunks,
        doneCount: totalChunks > 0
            ? ((wsProgress / 100) * totalChunks).round().clamp(0, totalChunks)
            : 0,
        overallPercent: wsProgress.clamp(0, 100),
      );
    } else {
      // 纯文本状态消息：保持上次进度不变
      return _previous ??
          VideoSummaryChunkProgressData.fromPayload(null,
              fallbackTotalChunks: 5);
    }

    // ── 2. 更新 driving progress ──
    _lastRawProgress = wsProgress ?? fresh.overallPercent;

    // ── 3. 与历史快照做非回归合并 ──
    final merged = VideoSummaryChunkProgressData(
      stage: fresh.overallPercent >= 100 ||
              fresh.stage == VideoSummaryChunkProgressStage.finished
          ? VideoSummaryChunkProgressStage.finished
          : VideoSummaryChunkProgressStage.running,
      totalChunks: fresh.totalChunks,
      doneCount: math.max(fresh.doneCount, _previous?.doneCount ?? 0),
      overallPercent:
          math.max(fresh.overallPercent, _previous?.overallPercent ?? 0),
    );

    _previous = merged;
    return merged;
  }

  /// 重置内部状态（新任务开始时调用）。
  void reset() {
    _previous = null;
    _lastRawProgress = 0;
  }
}
