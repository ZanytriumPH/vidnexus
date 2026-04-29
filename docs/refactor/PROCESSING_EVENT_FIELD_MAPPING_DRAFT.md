# 视频总结处理态字段级接口草案

## 1. 文档目的

本文档用于把 VidNexus Flutter 端当前 processing raw data 与未来 `video_summarizer` 后端事件字段逐项对照，形成一份可用于联调讨论的接口草案。

它解决的问题不是“页面上显示什么”，而是：

- 后端第一阶段应该透传哪些处理事件。
- Flutter repository 层应该把这些事件整理成什么 raw data。
- mapper 层如何从 raw data 生成当前移动端 processing UI。

本文档默认遵守当前仓库既有边界：

- repository 只返回 domain/raw data。
- mapper 负责 UI-facing 文案和展示结构。
- widget 不直接消费后端原始事件。

## 2. 对齐范围

本草案只覆盖第一阶段，也就是 `analyze_video` / `analyze_uploaded_video` 对应的“处理中”链路。

本草案不覆盖：

- 第二阶段 `finalize_summary`
- 时间旅行 `ask_at_timestamp`
- 最终 summary 正文协议
- chat message 协议

## 3. 当前 Flutter raw data

当前 Flutter processing raw data 位于 [lib/features/home/domain/video_summary_domain_models.dart](lib/features/home/domain/video_summary_domain_models.dart)，核心结构如下：

### 3.1 顶层 processing 数据

`VideoSummaryProcessingData`

| Flutter 字段 | 类型 | 必填 | 语义 |
|---|---|---:|---|
| `progress` | `double` | 是 | 当前移动端的统一进度值，范围 `0.0 ~ 1.0` |
| `currentStage` | `VideoSummaryProcessingStage` | 是 | 当前稳定处理阶段 |
| `currentMessage` | `String` | 是 | 当前处理主消息，保留原始处理语义，不做 UI 文案拼装 |
| `steps` | `List<VideoSummaryProcessingStepData>` | 是 | 当前移动端三段 processing 展示所需的阶段性聚合数据 |
| `chunkProgress` | `VideoSummaryChunkProgressData?` | 否 | 分片并行处理统计，适用于 send_api 并发模式 |

### 3.2 分片统计数据

`VideoSummaryChunkProgressData`

| Flutter 字段 | 类型 | 必填 | 语义 |
|---|---|---:|---|
| `stage` | `VideoSummaryChunkProgressStage` | 是 | 分片统计是否处于进行中或已结束 |
| `totalChunks` | `int` | 是 | 当前第一阶段总分片数 |
| `audioDone` | `int` | 是 | 已完成音频分析的 chunk 数 |
| `visionDone` | `int` | 是 | 已完成视觉分析的 chunk 数 |
| `synthesisDone` | `int` | 是 | 已完成融合摘要的 chunk 数 |
| `overallDone` | `int` | 是 | 当前 send_api 总完成项数，通常为三条维度之和 |
| `overallTotal` | `int` | 是 | 当前 send_api 总分母，通常为 `totalChunks * 3` |
| `overallPercent` | `int` | 是 | 当前 send_api 总体进度百分比，范围 `0 ~ 100` |

### 3.3 三段聚合步骤数据

`VideoSummaryProcessingStepData`

| Flutter 字段 | 类型 | 必填 | 语义 |
|---|---|---:|---|
| `phase` | `VideoSummaryProcessingPhase` | 是 | 当前移动端保留的三段 processing 聚合轨道 |
| `progress` | `int` | 是 | 当前聚合轨道的百分比，范围 `0 ~ 100` |
| `completedUnits` | `int` | 是 | 当前聚合轨道已完成单元数 |
| `totalUnits` | `int` | 是 | 当前聚合轨道总单元数 |

## 4. 后端已知处理态来源

根据上游仓库当前实现，第一阶段处理态主要来自三条来源。

### 4.1 生命周期文本事件

来源：

- `core/extraction/base.py`
- `core/workflow/api.py`
- `services/workflow_service.py`

特点：

- 通过 `status_callback(msg)` 透传。
- 本质是字符串消息。
- 包含处理阶段语义，但不保证机器可直接消费。

### 4.2 结构化分片进度事件

来源：

- `core/workflow/api.py` 中的 `[[PROGRESS]]{...}` payload

特点：

- 是字符串包裹的 JSON。
- 当前 `type` 固定为 `chunk_progress`。
- 已知字段稳定性高，适合作为 Flutter raw contract 的主要数据源之一。

### 4.3 第一阶段完成返回包

来源：

- `core/workflow/api.py` 返回的 `review_package`

特点：

- 不是 processing 中间事件。
- 但它标志着 processing 的完成态和后续草稿阶段的衔接点。
- `thread_id`、`stage`、`human_gate_status`、`human_gate_reason`、`chunk_count` 对移动端后续联调很重要。

## 5. 建议的后端事件模型

虽然上游当前是“字符串消息 + `[[PROGRESS]]` JSON”混合模式，但为了移动端长期稳定接入，建议后端对外最终统一成事件流模型。

推荐事件类型：

1. `status_message`
2. `chunk_progress`
3. `phase_completed`
4. `review_package_ready`

其中当前 Flutter 第一阶段至少需要前两类；第四类可在后续真实接入时用于明确“处理中结束”。

## 6. 字段级对照

### 6.1 生命周期文本事件 → Flutter 顶层字段

| 后端来源 | 当前上游形态 | 推荐后端字段 | Flutter 字段 | 转换规则 | 备注 |
|---|---|---|---|---|---|
| 预处理消息 | 纯字符串 | `message` | `currentMessage` | 原样透传或轻度清洗 | 不建议在 repository 内做 UI 汉化 |
| 节点名称 | 隐含于 node message | `node_name` | `currentStage` | 通过映射表转成枚举 | 推荐后端显式给出，减少移动端猜测 |
| 会话标识 | 某些消息中带 thread_id | `thread_id` | 暂不进入 `VideoSummaryProcessingData` | 当前阶段可不入 Flutter raw model | 若后续要展示恢复态，可新增字段 |
| 事件时间 | 当前无统一字段 | `event_at` | 暂无 | 可选 | 用于日志流排序，不是当前 UI 必需 |

### 6.2 `chunk_progress` → Flutter 分片统计字段

| 后端字段 | 类型 | Flutter 字段 | 类型 | 是否一对一 | 说明 |
|---|---|---|---|---:|---|
| `type` | `string` | 无 | 无 | 否 | Flutter repository 用于判别事件类型，通常不进 raw model |
| `stage` | `string` | `chunkProgress.stage` | `VideoSummaryChunkProgressStage` | 是 | `running` → `running`，`finished` → `finished` |
| `total_chunks` | `int` | `chunkProgress.totalChunks` | `int` | 是 | 直接映射 |
| `audio_done` | `int` | `chunkProgress.audioDone` | `int` | 是 | 直接映射 |
| `vision_done` | `int` | `chunkProgress.visionDone` | `int` | 是 | 直接映射 |
| `synthesis_done` | `int` | `chunkProgress.synthesisDone` | `int` | 是 | 直接映射 |
| `overall_done` | `int` | `chunkProgress.overallDone` | `int` | 是 | 直接映射 |
| `overall_total` | `int` | `chunkProgress.overallTotal` | `int` | 是 | 直接映射 |
| `overall_percent` | `int` | `chunkProgress.overallPercent` | `int` | 是 | 直接映射 |

### 6.3 review package 完成态 → Flutter 后续可扩展字段

| 后端返回包字段 | 当前位置 | 当前 Flutter 是否承载 | 建议 | 备注 |
|---|---|---:|---|---|
| `thread_id` | `review_package` | 否 | 后续建议在 session/history 恢复链路使用 | 当前 processing UI 不直接需要 |
| `stage` | `review_package` | 否 | 后续可映射到 processing 完成态或 flow 迁移条件 | 当前值为 `pending_human_review` |
| `human_gate_status` | `review_package` | 否 | 建议保留到 draft 入口阶段 | 典型值为 `pending` |
| `human_gate_reason` | `review_package` | 否 | 建议保留 | 典型值为 `human_review_required` |
| `aggregated_chunk_insights` | `review_package` | 否 | 不属于 processing raw data | 进入 draft/finalize 流程时使用 |
| `editable_aggregated_chunk_insights` | `review_package` | 否 | 不属于 processing raw data | 后续审批编辑态需要 |
| `human_guidance` | `review_package` | 否 | 不属于 processing raw data | draft/finalize 需要 |
| `chunk_count` | `review_package` | 间接承载 | 可用于校验 `chunkProgress.totalChunks` | 当前 processing mock 已有等价值 |

## 7. `currentStage` 枚举映射草案

当前 Flutter `VideoSummaryProcessingStage` 是移动端稳定枚举，不要求与后端 node 名称完全一致，但应能一对一归类。

### 7.1 后端事件到 Flutter stage

| 后端事件来源 | 后端值示例 | Flutter `currentStage` | 说明 |
|---|---|---|---|
| 预处理消息 | 获取视频文件 | `acquiringVideo` | 本地或远程视频就绪 |
| 预处理消息 | 提取音频 | `extractingAudio` | 音轨分离 |
| 预处理消息 | 提取关键帧 | `extractingFrames` | 场景检测与抽帧 |
| 预处理消息 | Whisper 转录 | `transcribingAudio` | 文本转录 |
| 系统消息 | LangGraph 初始化 | `bootingWorkflow` | 第一阶段图启动 |
| `node_name` | `chunk_planner_node` | `planningChunks` | 分片规划 |
| `node_name` | `map_dispatch_node` | `dispatchingChunks` | 分发波次任务 |
| `node_name` | `chunk_audio_worker_node` | `analyzingAudioChunks` | 音频 worker 回传 |
| `node_name` | `chunk_vision_worker_node` | `analyzingVisionChunks` | 视觉 worker 回传 |
| `node_name` | `chunk_synthesizer_worker_node` / `chunk_synthesizer_node` | `synthesizingChunks` | 分片融合与阶段性汇聚 |
| `node_name` | `chunk_aggregator_node` | `aggregatingChunks` | 聚合统一证据底稿 |
| `node_name` 或 review package ready | `human_gate_node` / `pending_human_review` | `waitingHumanReview` | 第一阶段结束，等待审批 |

### 7.2 需要后端未来显式补齐的字段

当前移动端如果只拿到“纯字符串消息”，仍然需要用本地规则猜测 `currentStage`。这是可以工作的，但不够稳定。

建议后端未来显式输出：

| 建议后端字段 | 类型 | 目的 |
|---|---|---|
| `event_type` | `string` | 区分 status/progress/review package |
| `node_name` | `string?` | 稳定映射 Flutter `currentStage` |
| `stage_key` | `string?` | 若不想暴露 node_name，可直接提供语义阶段键 |
| `message` | `string` | 作为 `currentMessage` 来源 |

## 8. `steps` 三段聚合规则草案

Flutter 当前 UI 不直接显示后端所有节点，而是汇总成三段 processing 轨道。因此 `steps` 不是后端直接返回字段，而是 repository 或 mapper 聚合后的稳定 raw data。

### 8.1 phase 聚合关系

| Flutter phase | 聚合哪些后端阶段 | 说明 |
|---|---|---|
| `preprocessing` | 获取视频、提取音频、提取关键帧、Whisper 转录 | 素材准备完成后应进入 100% |
| `analysis` | LangGraph 初始化、分片规划、分发、音频分析、视觉分析 | send_api 并行过程的主阶段 |
| `synthesis` | 分片融合、聚合证据、人类审批关口前整理 | 第一阶段输出收口 |

### 8.2 `completedUnits` 与 `totalUnits` 建议

| Flutter phase | `completedUnits` 建议来源 | `totalUnits` 建议来源 |
|---|---|---|
| `preprocessing` | 已完成的预处理固定步骤数 | 固定为 `4` |
| `analysis` | `audio_done + vision_done` | `total_chunks * 2` |
| `synthesis` | `synthesis_done + 聚合/关口附加步骤数` | `total_chunks + 2` |

这里的 `+2` 代表：

1. `chunk_aggregator_node`
2. `human_gate_node`

该规则属于 Flutter 端过渡期聚合策略，不要求后端直接提供。

## 9. 推荐的未来后端事件协议

若后端后续愿意做一次接口收口，建议处理态事件最终统一为以下 JSON 结构。

### 9.1 status message 事件

```json
{
  "event_type": "status_message",
  "thread_id": "thread-123",
  "stage_key": "planning_chunks",
  "node_name": "chunk_planner_node",
  "message": "正在以时间戳为锚点规划分片任务",
  "event_at": "2026-04-30T10:12:05Z"
}
```

### 9.2 chunk progress 事件

```json
{
  "event_type": "chunk_progress",
  "thread_id": "thread-123",
  "stage": "running",
  "total_chunks": 8,
  "audio_done": 5,
  "vision_done": 3,
  "synthesis_done": 1,
  "overall_done": 9,
  "overall_total": 24,
  "overall_percent": 38,
  "event_at": "2026-04-30T10:12:18Z"
}
```

### 9.3 review package ready 事件

```json
{
  "event_type": "review_package_ready",
  "thread_id": "thread-123",
  "stage": "pending_human_review",
  "human_gate_status": "pending",
  "human_gate_reason": "human_review_required",
  "chunk_count": 8,
  "event_at": "2026-04-30T10:12:31Z"
}
```

## 10. Flutter repository 转换规则草案

未来真实接口接入后，`HttpVideoSummaryRepository.startDraftGeneration()` 建议按如下顺序处理事件：

1. 收到 `status_message`：
   更新 `currentStage` 与 `currentMessage`。

2. 收到 `chunk_progress`：
   更新 `chunkProgress`。
   按当前移动端规则回算 `steps`。
   按当前移动端加权策略回算顶层 `progress`。

3. 收到 `review_package_ready`：
   最后一帧 processing raw data 设置到 `waitingHumanReview`。
   之后结束 processing 流并进入 draft 获取。

## 11. 字段稳定性判断

为了减少未来接口变更对移动端的冲击，建议按稳定性分层。

### 11.1 高稳定字段

这些字段建议直接纳入正式联调契约：

- `thread_id`
- `event_type`
- `stage`
- `total_chunks`
- `audio_done`
- `vision_done`
- `synthesis_done`
- `overall_done`
- `overall_total`
- `overall_percent`
- `human_gate_status`
- `human_gate_reason`
- `chunk_count`

### 11.2 中稳定字段

这些字段建议保留，但允许后端文案调整：

- `message`
- `stage_key`
- `node_name`

### 11.3 低稳定字段

这些字段当前不建议让 Flutter processing UI 直接依赖：

- 节点日志全文
- token usage
- latency 观测数据
- reduce_debug_info
- chunk_retry_count

它们适合未来做诊断面板，不适合当前 processing 主 UI。

## 12. 当前建议结论

当前最稳妥的联调方向是：

1. 后端继续保留现有 `chunk_progress` 核心字段语义。
2. 后端增加 `event_type` 和 `stage_key`，减少移动端通过字符串猜阶段。
3. Flutter repository 负责把事件流整理成 `VideoSummaryProcessingData`。
4. Flutter mapper 继续把 raw data 翻译成移动端当前三段 processing UI。

如果后续要进入真实联调，下一份文档建议直接补“Dart DTO / JSON schema 草案”，把这些字段写成可序列化结构，避免联调时再次口头约定。