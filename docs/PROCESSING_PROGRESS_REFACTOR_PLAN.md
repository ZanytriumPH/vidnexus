# 初稿生成进度条页重构方案

> **状态**: 方案设计完成，待评审
> **日期**: 2026-06-02
> **范围**: 仅 Flutter 前端（`VidNexus/lib/features/home/`），不动后端代码
> **对标**: Streamlit `app.py` 分片进度面板

---

## 1. 问题诊断

### 1.1 当前 Flutter 进度条架构

当前 Flutter 使用 **3 阶段串行进度**模型：

```
┌─────────────────────────────────────┐
│  HeroCard: 总体进度条 + 百分比        │  ← 单一条形
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│  详细处理信息                        │
│  ┌ 素材预处理    [████████░░] 80%   │
│  ├ 分片并行分析  [████░░░░░░] 40%   │  ← 三个子进度条
│  └ 融合输出      [░░░░░░░░░░]  0%   │
└─────────────────────────────────────┘
```

子进度条的计算逻辑位于 `http_video_summary_repository.dart:_buildWSSteps()`，根据当前 `WSStage` 做粗略的三段映射：

```
WSStage.extraction/transcribing/extractingKeyframes → preprocessing=progress, analysis=0, synthesis=0
WSStage.ragRetrieval/llmReasoning/analysis           → preprocessing=100, analysis=progress, synthesis=0
WSStage.synthesis/cleanup                            → preprocessing=100, analysis=100, synthesis=progress
```

### 1.2 核心问题：子进度条与父进度条映射失真

根因链路如下：

```
后端 analyze_video()
  └─ _emit_chunk_progress() 产生富数据:
       {total_chunks:5, audio_done:3, vision_done:2,
        synthesis_done:1, overall_done:5, overall_total:10,
        overall_percent:50}
       ↓
  └─ status_callback("[[PROGRESS]]{...}")
       ↓
后端 WorkflowOrchestrationService._build_workflow_callback()
  └─ 解析 [[PROGRESS]] JSON 后丢弃全部字段，仅保留:
       progress = overall_percent  (50)
       message = "Chunk processing: 5/10"
       ↓  ← ★ 分片数据在此处被截断
  └─ publish_progress(progress=50, message="Chunk processing: 5/10")
       ↓
Redis Pub/Sub → WebSocket → Flutter
       ↓
Flutter WSEventEnvelope {progress: 50, stage: ANALYSIS, message: "Chunk processing: 5/10"}
       ↓
Flutter _buildWSSteps(WSStage.ANALYSIS, 50)
  → preprocessing=100%, analysis=50%, synthesis=0%
```

**问题本质**：后端 WorkflowOrchestrationService 把 `[[PROGRESS]]` 的 8 个字段压成 1 个数字（`overall_percent`）+ 1 条截断消息。Flutter 端拿不到 `total_chunks`、`audio_done`、`vision_done`、`synthesis_done` 等分片粒度的数据，只能用单值进度粗暴映射成三段串行，导致子进度条与实际并行处理进度脱节。

### 1.3 Streamlit 对照：正确的多轨并行进度

Streamlit `app.py` 直接消费 `[[PROGRESS]]` 原始 JSON，渲染 **4 条并行进度条**：

```python
audio_percent    = int((audio_done / total_chunks) * 100)    # 音频分片
vision_percent   = int((vision_done / total_chunks) * 100)   # 视觉分片
synthesis_percent = int((synthesis_done / total_chunks) * 100) # 融合分片
overall_percent  = int((overall_done / overall_total) * 100) # 总体 = (audio+vision)/(total*2)
```

4 条进度条**同源同频**更新——每次 `_emit_chunk_progress` 触发，4 条一起刷新。这就是用户感觉"进度很自然"的关键：**子进度条反映真实并行度，而非串行猜测**。

---

## 2. 重构目标

1. **抛弃现有的 3 段串行进度模型**（`ProcessingStep` × 3），改用 Streamlit 同款 **4 轨并行进度**。
2. **在 Flutter 端自行解析/模拟 `[[PROGRESS]]` 分片数据**，不再依赖后端 WebSocket 已丢失的信息。
3. **保留 Mock 能力**，确保无后端时也能演示完整进度动画。
4. **不修改后端任何代码**。

---

## 3. 方案设计

### 3.1 新 UI 布局

```
┌──────────────────────────────────────────┐
│  HeroCard (保持不变)                      │
│  ┌──────────────────────────────────┐    │
│  │ 正在生成结构化初稿                 │    │
│  │ 音频 3/5 · 视觉 2/5 · 融合 1/5    │    │
│  │ [████████████░░░░░░░░░░░░]  50%  │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  分片进度面板                    ▲ 收起   │
│  ─────────────────────────────────       │
│  📊 实时 fan-out/fan-in                  │
│                                          │
│  🎧 音频分片  ▓▓▓▓▓▓▓▓▓▓▓░░░░  3/5  60% │
│  📸 视觉分片  ▓▓▓▓▓▓▓▓░░░░░░  2/5  40% │
│  🧩 融合分片  ▓▓▓▓░░░░░░░░░░  1/5  20% │
│  📦 总体进度  ▓▓▓▓▓▓▓▓▓▓▓░░░  5/10 50% │
│                                          │
│  ─────────────────────────────────       │
│  状态日志:                               │
│  ⚡ 引擎点火 第一阶段启动...               │
│  📋 Plan Checker: 正在分片...             │
│  🎧 Chunk Audio Worker: 分片3/5 完成     │
│  ...                                     │
└──────────────────────────────────────────┘
```

### 3.2 新数据模型

#### 3.2.1 新增 `ChunkProgressSnapshot`（展示层）

```dart
// video_summary_presentation_models.dart

class ChunkProgressBar {
  const ChunkProgressBar({
    required this.label,
    required this.icon,
    required this.done,
    required this.total,
    required this.percent,
  });

  final String label;   // "音频分片"
  final String icon;    // "🎧"
  final int done;
  final int total;
  final int percent;    // 0-100
}

class ChunkProgressSnapshot {
  const ChunkProgressSnapshot({
    required this.audioBar,
    required this.visionBar,
    required this.synthesisBar,
    required this.overallBar,
    required this.statusLog,
  });

  final ChunkProgressBar audioBar;
  final ChunkProgressBar visionBar;
  final ChunkProgressBar synthesisBar;
  final ChunkProgressBar overallBar;
  final List<String> statusLog;  // 最近 N 条状态日志
}
```

#### 3.2.2 增强 `ProcessingSnapshot`

```dart
class ProcessingSnapshot {
  const ProcessingSnapshot({
    required this.progress,        // 整体 0.0-1.0（保留兼容）
    required this.statusLabel,
    required this.etaLabel,
    required this.steps,           // 保留兼容旧 widget
    this.chunkProgress,            // ★ 新增：分片并行进度
    this.statusLog = const [],     // ★ 新增：状态日志流
  });

  final double progress;
  final String statusLabel;
  final String etaLabel;
  final List<ProcessingStep> steps;           // 保留但不再主导 UI
  final ChunkProgressSnapshot? chunkProgress; // 新 UI 主要数据源
  final List<String> statusLog;
}
```

#### 3.2.3 增强 `VideoSummaryChunkProgressData`（领域层）

```dart
// video_summary_domain_models.dart

class VideoSummaryChunkProgressData {
  // ... 现有字段保持不变 ...
  
  // ★ 新增工厂：从 WS 消息 + progress 估算分片进度
  factory VideoSummaryChunkProgressData.estimateFromWS({
    required int wsProgress,       // 0-100
    required String? wsMessage,
    int? previousTotalChunks,
    int? previousAudioDone,
    int? previousVisionDone,
    int? previousSynthesisDone,
  }) { ... }
  
  // ★ 新增工厂：生成纯 Mock 数据（用于演示/测试）
  factory VideoSummaryChunkProgressData.mock({
    required int totalChunks,
    required int audioDone,
    required int visionDone,
    required int synthesisDone,
    VideoSummaryChunkProgressStage stage = VideoSummaryChunkProgressStage.running,
  }) { ... }
}
```

### 3.3 数据流重构

```
WSEventEnvelope
  {progress:50, stage:ANALYSIS, message:"Chunk processing: 5/10", substage:"chunk_processing"}
       │
       ▼
┌──────────────────────────────────────────────────────┐
│ HttpVideoSummaryRepository.startDraftGeneration()    │
│                                                      │
│  1. 从 message 提取 overall_done/overall_total       │
│     正则: /Chunk processing: (\d+)\/(\d+)/           │
│                                                      │
│  2. 估算 total_chunks:                               │
│     total_chunks = overall_total ~/ 2  或  保持上次值  │
│                                                      │
│  3. 调用 ChunkProgressEstimator 生成 4 轨进度:        │
│     - 音频 = progress 加权领先                         │
│     - 视觉 = 音频 × 0.6~0.8                           │
│     - 融合 = 视觉 × 0.4~0.6                           │
│     - 总体 = (audio+vision) / (total*2) * 100        │
│                                                      │
│  4. 非 chunk_processing 消息 → 追加到 statusLog       │
│                                                      │
│  5. 产出 VideoSummaryProcessingData (含 chunkProgress) │
└──────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│ mapProcessingDataToSnapshot()                        │
│                                                      │
│  - chunkProgress 非空 → 生成 ChunkProgressSnapshot    │
│  - 追加当前 message 到 statusLog (保留最近 20 条)     │
│  - steps 保留但不作为主数据源                          │
└──────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│ StreamlitStyleProcessingCard (新 Widget)              │
│                                                      │
│  4 条 ChunkProgressBarTile + 状态日志区               │
└──────────────────────────────────────────────────────┘
```

### 3.4 Chunk 进度估算器 (`ChunkProgressEstimator`)

由于后端 WebSocket 不会下发完整的 `audio_done/vision_done/synthesis_done`，我们在 Flutter 端做一个**本地估算器**，基于以下输入推断 4 轨进度：

**输入**：
- `wsProgress` (int, 0-100)：WS 的 overall_percent
- `wsMessage` (String?)：消息文本，可能包含 "Chunk processing: X/Y"
- `stage` (WSStage)：当前阶段
- `previousState`：上次估算的快照

**估算规则**：

| 阶段 | 音频 | 视觉 | 融合 | 总体 |
|---|---|---|---|---|
| extraction/transcribing/extractingKeyframes | progress | 0 | 0 | progress |
| ragRetrieval/llmReasoning/analysis | 100 | progress×0.7 | progress×0.1 | progress |
| synthesis | 100 | 100 | progress | progress |
| cleanup | 100 | 100 | 100 | 100 |

**平滑策略**：
- 每个子进度条只在值增加时更新（不回退）
- 使用 `AnimatedContainer` 实现 420ms 缓动
- 如果 WS 长时间不发 `[[PROGRESS]]`（>5s），自动以微小增量前进（心跳模拟）

### 3.5 Mock 模式

为满足无后端联调场景，新增 `ChunkProgressMock` 工具类：

```dart
class ChunkProgressMock {
  /// 生成一条模拟的 [[PROGRESS]] 消息 payload
  static Map<String, dynamic> generateProgressPayload({
    required int totalChunks,
    required int tick,
    int? audioDone,
    int? visionDone,
    int? synthesisDone,
  }) { ... }

  /// 生成 20 步模拟进度序列，模拟完整的 5 分片处理
  static List<VideoSummaryProcessingData> generateMockSequence({
    int totalChunks = 5,
    Duration stepInterval = const Duration(milliseconds: 800),
  }) { ... }
}
```

Mock 序列模拟真实的分片处理节奏：
```
Tick 1:  audio=1, vision=0, synthesis=0, overall=1/10 (10%)
Tick 2:  audio=1, vision=1, synthesis=0, overall=2/10 (20%)
Tick 3:  audio=2, vision=1, synthesis=0, overall=3/10 (30%)
Tick 4:  audio=2, vision=2, synthesis=0, overall=4/10 (40%)
Tick 5:  audio=2, vision=2, synthesis=1, overall=4/10 (40%)  ← 融合开始
...
Tick 20: audio=5, vision=5, synthesis=5, overall=10/10 (100%)
```

---

## 4. 文件级修改清单

### 4.1 新增文件

| # | 文件路径 | 说明 |
|---|---|---|
| 1 | `lib/features/home/domain/chunk_progress_estimator.dart` | Chunk 进度估算器：从 WS 单值 + 阶段 + 历史推导 4 轨进度 |
| 2 | `lib/features/home/domain/chunk_progress_mock.dart` | Mock 数据生成器：模拟完整分片处理序列 |
| 3 | `lib/features/home/widgets/streamlit_progress_card.dart` | 新进度卡片组件：4 轨并行进度条 + 状态日志 |

### 4.2 修改文件

| # | 文件路径 | 改动点 |
|---|---|---|
| 4 | `lib/features/home/domain/video_summary_domain_models.dart` | `VideoSummaryChunkProgressData` 新增 `estimateFromWS()` 和 `mock()` 工厂 |
| 5 | `lib/features/home/video_summary_presentation_models.dart` | 新增 `ChunkProgressBar`、`ChunkProgressSnapshot`；`ProcessingSnapshot` 新增 `chunkProgress`、`statusLog` |
| 6 | `lib/features/home/application/video_summary_result_mapper.dart` | 新增 `mapChunkProgressToSnapshot()`；`mapProcessingDataToSnapshot()` 改为产出含 `chunkProgress` 的 snapshot |
| 7 | `lib/features/home/http_video_summary_repository.dart` | `startDraftGeneration()` 中调用 `ChunkProgressEstimator`；`_buildWSSteps()` 保留兼容但不再主导 |
| 8 | `lib/features/home/widgets/video_summary_processing_widgets.dart` | 新增 `ChunkProgressBarTile` widget；`ProcessingDetailCard` 改为渲染新 4 轨布局 |
| 9 | `lib/features/home/widgets/video_summary_processing_stage_workspace.dart` | `ProcessingStageWorkspace` 切换为新卡片 |
| 10 | `lib/features/home/application/video_summary_flow_controller.dart` | `buildInitialProcessingSnapshot()` 初始化 `chunkProgress` + `statusLog` |

### 4.3 不改动文件

- 所有 `video_summarizer/` 后端代码：**不动**
- `video_summary_models.dart`：**不动**（`VideoSummaryStage` 枚举等不变）
- `video_summary_repository.dart`：**不动**（接口签名不变）
- Draft/FinalChat 相关 widget：**不动**（仅 processing 阶段改动）

---

## 5. 详细实施步骤

### Step 1: 扩展领域模型

**文件**: `video_summary_domain_models.dart`

在 `VideoSummaryChunkProgressData` 中新增两个工厂构造函数：

```dart
/// 从 WS 消息估算分片进度（不依赖后端下发完整 chunk_progress）
factory VideoSummaryChunkProgressData.estimateFromWS({
  required int wsProgress,
  required String? wsMessage,
  required WSStage? wsStage,
  VideoSummaryChunkProgressData? previous,
}) {
  // 1. 尝试从 message 提取 overall_done/overall_total
  int? extractedOverallDone;
  int? extractedOverallTotal;
  if (wsMessage != null) {
    final match = RegExp(r'Chunk processing: (\d+)/(\d+)')
        .firstMatch(wsMessage);
    if (match != null) {
      extractedOverallDone = int.tryParse(match.group(1)!);
      extractedOverallTotal = int.tryParse(match.group(2)!);
    }
  }

  // 2. 估算 total_chunks
  final totalChunks = extractedOverallTotal != null
      ? extractedOverallTotal ~/ 2
      : (previous?.totalChunks ?? 5);

  // 3. 根据 WS stage 推导各轨进度（详见估算规则表）
  final stage = wsStage;
  int audioDone, visionDone, synthesisDone;

  if (stage == WSStage.extraction ||
      stage == WSStage.transcribing ||
      stage == WSStage.extractingKeyframes) {
    // 预处理阶段：仅音频就绪
    audioDone = (wsProgress / 100 * totalChunks).round().clamp(0, totalChunks);
    visionDone = 0;
    synthesisDone = 0;
  } else if (stage == WSStage.analysis ||
             stage == WSStage.ragRetrieval ||
             stage == WSStage.llmReasoning) {
    // 分析阶段：音频领先，视觉跟随
    audioDone = totalChunks;
    visionDone = ((wsProgress / 100 * totalChunks) * 0.85)
        .round().clamp(0, totalChunks);
    synthesisDone = ((wsProgress / 100 * totalChunks) * 0.3)
        .round().clamp(0, totalChunks);
  } else if (stage == WSStage.synthesis) {
    audioDone = totalChunks;
    visionDone = totalChunks;
    synthesisDone = (wsProgress / 100 * totalChunks)
        .round().clamp(0, totalChunks);
  } else {
    // cleanup / null: 全部完成
    audioDone = totalChunks;
    visionDone = totalChunks;
    synthesisDone = totalChunks;
  }

  // 4. 不回退
  if (previous != null) {
    audioDone = max(audioDone, previous.audioDone);
    visionDone = max(visionDone, previous.visionDone);
    synthesisDone = max(synthesisDone, previous.synthesisDone);
  }

  final overallTotal = totalChunks * 2;
  final overallDone = (audioDone + visionDone).clamp(0, overallTotal);
  final overallPercent = overallTotal > 0
      ? (overallDone / overallTotal * 100).round()
      : 0;

  return VideoSummaryChunkProgressData(
    stage: wsProgress >= 100
        ? VideoSummaryChunkProgressStage.finished
        : VideoSummaryChunkProgressStage.running,
    totalChunks: totalChunks,
    audioDone: audioDone,
    visionDone: visionDone,
    synthesisDone: synthesisDone,
    overallDone: overallDone,
    overallTotal: overallTotal,
    overallPercent: overallPercent,
  );
}
```

### Step 2: 新增展示层模型

**文件**: `video_summary_presentation_models.dart`

新增：

```dart
class ChunkProgressBar {
  const ChunkProgressBar({
    required this.label,
    required this.icon,
    required this.done,
    required this.total,
    required this.percent,
  });

  final String label;
  final String icon;
  final int done;
  final int total;
  final int percent;
}

class ChunkProgressSnapshot {
  const ChunkProgressSnapshot({
    required this.audioBar,
    required this.visionBar,
    required this.synthesisBar,
    required this.overallBar,
    required this.statusLog,
  });

  final ChunkProgressBar audioBar;
  final ChunkProgressBar visionBar;
  final ChunkProgressBar synthesisBar;
  final ChunkProgressBar overallBar;
  final List<String> statusLog;
}
```

`ProcessingSnapshot` 扩展：

```dart
class ProcessingSnapshot {
  const ProcessingSnapshot({
    required this.progress,
    required this.statusLabel,
    required this.etaLabel,
    required this.steps,
    this.chunkProgress,    // ★ 新增
    this.statusLog = const [], // ★ 新增
  });
  // ... existing fields ...
  final ChunkProgressSnapshot? chunkProgress;
  final List<String> statusLog;
}
```

### Step 3: 新增 ChunkProgressEstimator

**文件**: `lib/features/home/domain/chunk_progress_estimator.dart`（新文件）

核心逻辑类：

```dart
class ChunkProgressEstimator {
  VideoSummaryChunkProgressData? _previous;

  /// 输入一条 WS 事件，输出估算的分片进度。
  /// 当 wsProgress 为 null 时（纯状态消息），返回 null。
  VideoSummaryChunkProgressData? estimate({
    required int? wsProgress,
    required String? wsMessage,
    required WSStage? wsStage,
    required String? substage,
  }) {
    // 非 chunk_processing 子阶段不产生 chunk 进度
    if (substage != 'chunk_processing' && wsProgress == null) {
      return null;
    }

    final progress = wsProgress ?? (_previous?.overallPercent ?? 0);
    final result = VideoSummaryChunkProgressData.estimateFromWS(
      wsProgress: progress,
      wsMessage: wsMessage,
      wsStage: wsStage,
      previous: _previous,
    );

    _previous = result;
    return result;
  }

  void reset() {
    _previous = null;
  }
}
```

### Step 4: 新增 Mock 生成器

**文件**: `lib/features/home/domain/chunk_progress_mock.dart`（新文件）

```dart
class ChunkProgressMock {
  /// 生成模拟的完整分片处理序列（20 步）
  static List<VideoSummaryProcessingData> generateMockSequence({
    int totalChunks = 5,
  }) {
    // 模拟 5 个分片顺序完成 audio → vision → synthesis
    // 返回 20 个 VideoSummaryProcessingData，每个带完整 chunkProgress
    ...
  }
}
```

### Step 5: 更新 Mapper

**文件**: `video_summary_result_mapper.dart`

核心改动：`mapProcessingDataToSnapshot()` 产出新字段：

```dart
ProcessingSnapshot mapProcessingDataToSnapshot(VideoSummaryProcessingData data) {
  final chunkData = data.chunkProgress;
  final snapshot = ProcessingSnapshot(
    progress: data.progress,
    statusLabel: _statusLabelForProcessing(data),
    etaLabel: _etaLabelForProcessingV2(data),
    steps: data.steps.map((s) => mapProcessingStepToUiStep(s, data)).toList(),
    chunkProgress: chunkData != null
        ? ChunkProgressSnapshot(
            audioBar: ChunkProgressBar(
              label: '音频分片',
              icon: '🎧',
              done: chunkData.audioDone,
              total: chunkData.totalChunks,
              percent: _safePercent(chunkData.audioDone, chunkData.totalChunks),
            ),
            visionBar: ChunkProgressBar(
              label: '视觉分片',
              icon: '📸',
              done: chunkData.visionDone,
              total: chunkData.totalChunks,
              percent: _safePercent(chunkData.visionDone, chunkData.totalChunks),
            ),
            synthesisBar: ChunkProgressBar(
              label: '融合分片',
              icon: '🧩',
              done: chunkData.synthesisDone,
              total: chunkData.totalChunks,
              percent: _safePercent(chunkData.synthesisDone, chunkData.totalChunks),
            ),
            overallBar: ChunkProgressBar(
              label: '总体进度',
              icon: '📦',
              done: chunkData.overallDone,
              total: chunkData.overallTotal,
              percent: chunkData.overallPercent,
            ),
            statusLog: data.currentMessage.isNotEmpty
                ? [data.currentMessage]
                : const [],
          )
        : null,
  );
  return snapshot;
}

int _safePercent(int done, int total) {
  if (total <= 0) return 0;
  return ((done / total) * 100).round().clamp(0, 100);
}
```

### Step 6: 更新 Repository

**文件**: `http_video_summary_repository.dart`

在 `startDraftGeneration()` 中集成 `ChunkProgressEstimator`：

```dart
final _estimator = ChunkProgressEstimator();
final _statusLog = <String>[];

// WS 事件处理中:
wsSubscription = wsStream.listen((env) {
  // ... 现有去重/超时逻辑不变 ...

  // 非 chunk_processing 消息追加到状态日志
  if (env.substage != 'chunk_processing' &&
      env.message != null &&
      env.message!.isNotEmpty) {
    _statusLog.add(env.message!);
    if (_statusLog.length > 20) _statusLog.removeAt(0);
  }

  // 估算分片进度
  final chunkProgress = _estimator.estimate(
    wsProgress: env.progress,
    wsMessage: env.message,
    wsStage: env.stage,
    substage: env.substage,
  );

  final progressVal = env.progress != null
      ? env.progress! / 100.0
      : _lastProgress;
  _lastProgress = progressVal;

  controller.add(VideoSummaryProcessingData(
    progress: progressVal,
    currentStage: _mapWSStage(env.stage),
    currentMessage: env.message ?? '',
    steps: _buildWSSteps(env.stage, env.progress ?? (_lastProgress * 100).round()),
    chunkProgress: chunkProgress,  // ★ 新增
  ));
});
```

### Step 7: 新增 StreamlitProgressCard Widget

**文件**: `lib/features/home/widgets/streamlit_progress_card.dart`（新文件）

```dart
class StreamlitProgressCard extends StatelessWidget {
  const StreamlitProgressCard({
    required this.snapshot,
    this.onTap,
    super.key,
  });

  final ProcessingSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chunk = snapshot.chunkProgress;
    if (chunk == null) {
      // fallback: 无分片数据时显示旧版 3 步布局
      return ProcessingDetailCard(snapshot: snapshot, onTap: onTap);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：标题 + 收起按钮
            _buildHeader(context),
            const SizedBox(height: 8),
            // 分片面板状态提示
            Text(
              '📊 实时 fan-out/fan-in',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // 4 条并行进度条
            ChunkProgressBarTile(bar: chunk.audioBar),
            const SizedBox(height: 8),
            ChunkProgressBarTile(bar: chunk.visionBar),
            const SizedBox(height: 8),
            ChunkProgressBarTile(bar: chunk.synthesisBar),
            const SizedBox(height: 8),
            ChunkProgressBarTile(bar: chunk.overallBar, isOverall: true),
            // 状态日志
            if (snapshot.statusLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildStatusLog(context),
            ],
          ],
        ),
      ),
    );
  }
}

class ChunkProgressBarTile extends StatelessWidget {
  const ChunkProgressBarTile({
    required this.bar,
    this.isOverall = false,
    super.key,
  });

  final ChunkProgressBar bar;
  final bool isOverall;

  @override
  Widget build(BuildContext context) {
    final progressValue = bar.percent / 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOverall
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: isOverall
            ? Border.all(color: const Color(0xFFC7D2FE), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(bar.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${bar.label}：${bar.done}/${bar.total}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isOverall ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${bar.percent}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isOverall
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: progressValue,
            minHeight: isOverall ? 6 : 4,
            backgroundColor: const Color(0xFFE3E9EF),
          ),
        ],
      ),
    );
  }
}
```

### Step 8: 更新 Stage Workspace

**文件**: `video_summary_processing_stage_workspace.dart`

将 `ProcessingDetailCard` 替换为 `StreamlitProgressCard`：

```dart
child: processingExpanded
    ? StreamlitProgressCard(        // ★ 新组件
        key: const ValueKey('expanded'),
        snapshot: processingSnapshot,
        onTap: onProcessingCardPressed,
      )
    : ProcessingCollapsedHintCard(
        key: const ValueKey('collapsed'),
        onTap: onProcessingCardPressed,
      ),
```

### Step 9: 更新 FlowController 初始快照

**文件**: `video_summary_flow_controller.dart`

`buildInitialProcessingSnapshot()` 保持兼容，新字段由 mapper 自动填充。

---

## 6. Mock 模式切换

在 `video_summary_settings_controller.dart` 或调试面板中增加开关：

```dart
// 开发期间强制使用 mock 进度序列
const bool kUseMockProgress = false; // 发布前改为 false

// 在 HttpVideoSummaryRepository.startDraftGeneration() 中:
if (kUseMockProgress) {
  yield* Stream.fromIterable(
    ChunkProgressMock.generateMockSequence(totalChunks: 5),
  );
  return;
}
```

---

## 7. 验收标准

| # | 标准 | 验证方式 |
|---|---|---|
| 1 | 4 轨并行进度条（音频/视觉/融合/总体）同时显示并更新 | 肉眼观察 |
| 2 | 每个子进度条不出现回退（数值单调递增） | 观察断点 |
| 3 | 总体进度与 HeroCard 顶部百分比一致 | 比对数值 |
| 4 | 状态日志区实时追加后端消息（最近 20 条） | 观察滚动 |
| 5 | Mock 模式下完整播放 20 步进度序列 | 开关切换 |
| 6 | 收起/展开卡片动画流畅 | 操作交互 |
| 7 | 不影响 Draft/FinalChat 等下游阶段 | 完整走通流程 |
| 8 | 后端代码零改动 | `git diff video_summarizer/` 为空 |

---

## 8. 风险与缓解

| 风险 | 缓解措施 |
|---|---|
| 估算器推导不准（无真实 audio_done/vision_done） | 估算规则保守（不回退），且 4 条都基于同一 `wsProgress` 源；后续可要求后端在 payload 中补传 |
| 旧 `steps` 字段被其他 widget 引用 | 保留 `steps` 字段不删，仅在新 UI 中优先使用 `chunkProgress` |
| 状态日志过多撑爆内存 | 限制最近 20 条，超出自动清理 |
| 与后端 WS 心跳消息冲突 | `substage != 'chunk_processing'` 且 `progress == null` 的纯状态消息不进 chunk 估算器 |

---

## 9. 文件依赖关系图

```
chunk_progress_mock.dart ─────────────────────┐
chunk_progress_estimator.dart ────────────────┤
                                              ▼
video_summary_domain_models.dart ◄── VideoSummaryChunkProgressData (增强)
       │
       ▼
http_video_summary_repository.dart ◄── 调用 Estimator，产出含 chunkProgress 的 data
       │
       ▼
video_summary_result_mapper.dart ◄── 将 chunkProgress 映射为 ChunkProgressSnapshot
       │
       ▼
video_summary_presentation_models.dart ◄── ProcessingSnapshot (增强)
       │
       ▼
streamlit_progress_card.dart ◄── ChunkProgressBarTile × 4 + 状态日志
       │
       ▼
video_summary_processing_stage_workspace.dart ◄── 切换新卡片
```

---

## 10. 后续演进建议

1. **短期**：要求后端在 `publish_progress` 中增加 `payload` 参数，把完整的 `chunk_progress` JSON 透传到 Flutter，届时可删除 `ChunkProgressEstimator` 估算逻辑。
2. **中期**：在当前页面增加"查看原始聚合稿"入口，减少审批阶段的页面跳转。
3. **长期**：进度条动画增加骨架屏过渡态，进一步提升体感流畅度。
