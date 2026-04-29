# 视频总结处理态真实 Mock 实施文档

## 1. 目标

本次实现的目标不是接入真实后端，而是在不破坏当前 Flutter 分层边界的前提下，把“处理中”阶段从占位式动画升级为更贴近上游 `video_summarizer` 第一阶段处理链路的真实 mock。

当前实现必须满足以下约束：

- repository 继续只返回 domain/raw data，不直接返回 UI 文案结构。
- `HomeScreen` 不回收处理态拼装逻辑。
- processing 相关展示文案继续由 mapper 产出。
- widgets 继续只消费 `ProcessingSnapshot`。

## 2. 上游仓库处理态来源

上游 `video_summarizer` 第一阶段会向前端透传两类状态：

### 2.1 生命周期消息

典型阶段包括：

- 获取视频文件
- 提取音频
- 提取关键帧
- Whisper 转录
- LangGraph 初始化
- 分片规划
- 分片分发
- 音频 worker 分析
- 视觉 worker 分析
- 融合 worker 汇总
- 聚合证据底稿
- 进入 human review

### 2.2 结构化 chunk 进度

上游还会持续发出 `chunk_progress` 负载，核心字段包括：

- `total_chunks`
- `audio_done`
- `vision_done`
- `synthesis_done`
- `overall_done`
- `overall_total`
- `overall_percent`
- `stage`

移动端 mock 现在以这两类语义为基础构造处理态，而不是只生成线性百分比。

## 3. Flutter 端当前实现策略

### 3.1 保留三段移动端展示结构

移动端仍然保留三段 processing 结构：

1. 素材预处理
2. 分片并行分析
3. 融合输出

这样做的原因是：

- 与当前 UI 结构兼容，不需要改动 `HomeScreen` 和 stage workspace。
- 可以吸收上游更细的事件流，又不会把移动端界面做得过于嘈杂。
- 后续真实接口上线时，只需要替换 repository 和 mapper，不需要大改 widgets。

### 3.2 新增 raw data 字段

本次在 `VideoSummaryProcessingData` 中增加了以下字段：

- `currentStage`
- `currentMessage`
- `chunkProgress`

其中：

- `currentStage` 用于表达当前所处的稳定处理阶段。
- `currentMessage` 用于承载当前处理主消息。
- `chunkProgress` 用于表达 chunk 级并行推进状态。

这些字段都属于 domain/raw data，不属于展示层。

## 4. 代码落点

### 4.1 domain 层

文件：`lib/features/home/domain/video_summary_domain_models.dart`

新增内容：

- `VideoSummaryProcessingStage`
- `VideoSummaryChunkProgressStage`
- `VideoSummaryChunkProgressData`

调整内容：

- 将 `VideoSummaryProcessingPhase` 重命名为更贴近后端语义的：
  - `preprocessing`
  - `analysis`
  - `synthesis`

### 4.2 repository fake 实现

文件：`lib/features/home/fake_video_summary_repository.dart`

当前 fake repository 已从“直接产出处理快照”，进一步收口成“事件源 + 事件适配器 + 流式仓储基类”。

当前结构拆分为：

- `video_summary_processing_event_source.dart`：定义后端事件类型与事件源接口
- `video_summary_processing_event_adapter.dart`：把事件流转换为 `VideoSummaryProcessingData`
- `stream_backed_video_summary_repository.dart`：为 Fake / 未来 Http repository 提供统一流式仓储基类
- `fake_video_summary_processing_event_source.dart`：当前脚本化 fake 事件源
- `fake_video_summary_repository.dart`：仅负责组合事件源与其他非 processing mock 能力

脚本化帧序列覆盖：

- 本地视频准备
- 音频提取
- 关键帧提取
- Whisper 转录
- 工作流引擎启动
- chunk 规划
- chunk 分发
- 音频分析推进
- 视觉分析推进
- 分片融合推进
- 聚合底稿
- 进入待审稿

这使 fake 数据在语义上已经能模拟未来真实接口的事件流。

### 4.2.1 第二阶段结构收益

这次重构后，未来真实接口接入时无需再让 `VideoSummaryRepository` 直接理解 SSE 或 WebSocket 细节，只需要：

1. 新增一个真实事件源实现
2. 让真实 repository 继承 `StreamBackedVideoSummaryRepository`
3. 复用现有事件适配器产出 `VideoSummaryProcessingData`

这样页面层、flow controller 和 mapper 都不需要因为通信方式变化而改动。

### 4.3 mapper

文件：`lib/features/home/application/video_summary_result_mapper.dart`

mapper 继续负责：

- `statusLabel`
- `headline`
- `etaLabel`
- badge 文案
- step detail 文案

repository 仍不负责输出这些 UI-facing 文案。

### 4.4 seeded session snapshot

文件：`lib/features/home/application/video_summary_session_history_controller.dart`

seeded processing snapshot 也已同步改为新的 raw data 结构，避免 demo 数据绕过正式 mapper 链路。

## 5. 当前 mock 设计规则

### 5.1 进度条规则

为了让移动端进度变化更符合用户感知，而不是被预处理阶段拖得过慢，当前整体进度采用加权策略：

- 预处理：35%
- 并行分析：40%
- 融合输出：25%

这不是后端协议的一部分，只是当前移动端 mock 的过渡策略。

### 5.2 chunk 总量规则

当前 fake 数据默认使用 `8` 个 chunks 模拟中等长度视频。

后续可扩展为多组场景：

- 1 chunk：短视频
- 6 到 10 chunks：普通视频
- 12+ chunks：长视频

### 5.3 文案分层规则

必须区分两类文案：

- raw message：上游处理事件语义
- UI message：当前移动端 headline / eta / detail / badge

raw message 存在 domain data 中，UI message 由 mapper 输出。

## 6. 后续真实接口替换路径

后续后端接口接入时，建议保持 `startDraftGeneration()` 仍返回流式数据，只替换其内部来源：

### 当前

- `FakeVideoSummaryRepository.startDraftGeneration()`
- 读取本地脚本帧序列
- 产出 `VideoSummaryProcessingData`

### 后续

- `HttpVideoSummaryRepository.startDraftGeneration()`
- 读取 SSE / WebSocket / 轮询接口事件
- 将 message/progress 事件转换为同样的 `VideoSummaryProcessingData`

这样 `VideoSummaryFlowController`、`HomeScreen`、`Processing widgets` 不需要改动。

## 7. 验证要求

第一阶段实现至少验证：

1. processing 卡片 headline 会随着阶段变化。
2. badge 状态会随着 phase 进度变化。
3. 详情文案能体现 chunk 级推进，而不是静态占位文本。
4. seeded session 恢复到 processing 时不会报错。
5. `flutter analyze` 通过。

## 8. 不在本次范围内的内容

以下内容暂不纳入这一轮实现：

- 真实网络接口接入
- draft/final/time travel 的协议改造
- processing 日志流独立面板
- SSE/WebSocket 客户端封装

## 9. 下一步建议

建议按以下顺序继续推进：

1. 增加第二组与第三组 processing mock 场景（短视频 / 长视频）。
2. 为 mapper 补处理态单元测试。
3. 在 presentation model 中考虑增加更显式的 chunk 统计字段。
4. 与后端对齐真实 processing 事件字段名和枚举值。