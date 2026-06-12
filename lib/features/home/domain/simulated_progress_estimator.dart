import 'dart:math' as math;

/// 虚假模拟进度估算器。
///
/// 解决用户点击"开始生成初稿"后进度条长时间卡在 0 的体验问题。
///
/// 策略：
/// 1. 进入页面后立即开始模拟，前 ~20% 为预处理阶段的虚假进度
///    （模拟后端分片处理前的准备阶段，如转录、关键帧提取等）。
/// 2. 收到后端第一条真实分片进度事件后，将剩余 80% 按分片数均匀分配，
///    真实进度映射到 [simulatedPreProcessingPercent, 100] 区间。
/// 3. 进度永不回退。
class SimulatedProgressEstimator {
  /// 预处理阶段目标百分比（真实分片进度到达前的模拟上限）。
  static const double _preProcessingTarget = 20.0;

  /// 模拟进度的每次 tick 增量（百分比）。
  static const double _tickIncrement = 2.0;

  DateTime? _startTime;
  bool _hasReceivedRealProgress = false;
  double _fakeProgress = 0;
  int _lastEmittedPercent = 0;

  /// 是否已收到后端真实分片进度事件。
  bool get hasReceivedRealProgress => _hasReceivedRealProgress;

  /// 当前模拟进度百分比 (0-100)，供 UI 驱动主进度条。
  int get currentPercent => _lastEmittedPercent;

  /// 重置内部状态（新任务开始时调用）。
  void reset() {
    _startTime = null;
    _hasReceivedRealProgress = false;
    _fakeProgress = 0;
    _lastEmittedPercent = 0;
  }

  /// 定时 tick：在收到真实后端事件前，缓慢推进模拟进度。
  ///
  /// 每次调用返回当前模拟百分比 (0-100)。
  /// 收到真实进度后此方法不再推进进度（但返回当前映射后的值）。
  int tick() {
    _startTime ??= DateTime.now();

    if (!_hasReceivedRealProgress) {
      // 模拟预处理阶段：缓慢增长到 _preProcessingTarget
      _fakeProgress =
          math.min(_fakeProgress + _tickIncrement, _preProcessingTarget);
      _lastEmittedPercent = _fakeProgress.round();
    }

    return _lastEmittedPercent;
  }

  /// 输入后端真实分片进度，返回映射后的模拟百分比。
  ///
  /// - [realPercent]: 后端真实进度 0-100（来自 ChunkProgressEstimator）。
  /// - [isCompleted]: 任务是否已完成。
  ///
  /// 映射规则：
  /// - 首次收到真实进度时，从当前模拟值平滑过渡。
  /// - 真实 0-100% 映射到 [max(当前模拟值, 20), 100]。
  /// - 进度永不回退。
  int feedRealProgress(int realPercent, {bool isCompleted = false}) {
    if (!_hasReceivedRealProgress) {
      // 首次收到真实进度：确保至少达到预处理目标
      _fakeProgress = math.max(_fakeProgress, _preProcessingTarget.toDouble());
      _hasReceivedRealProgress = true;
    }

    if (isCompleted) {
      _lastEmittedPercent = 100;
      return 100;
    }

    // 将真实进度 [0, 100] 映射到 [preProcessingTarget, 100]
    final mappedPercent =
        _preProcessingTarget + (realPercent / 100.0) * (100 - _preProcessingTarget);

    // 非回归
    _lastEmittedPercent = math.max(_lastEmittedPercent, mappedPercent.round().clamp(0, 100));
    return _lastEmittedPercent;
  }
}
