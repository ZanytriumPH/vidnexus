# API 对齐与实时通信集成计划 (v2026-05-23)

本计划旨在将项目的视频上传逻辑与实时通信（WebSocket 进度推送及 SSE 流式问答）与后端 FastAPI 接口进行深度对齐重写，提升用户体验并消除冗余代码。

## User Review Required

> [!IMPORTANT]
> - **文件选择与上传集成**：我们将引入 `file_picker` 并接管“本地上传”卡片的 onTap 事件。选定视频后，将通过 `UploadService` 执行固定 10 MiB 的分片上传，上传成功后注册视频并自动使用新 `videoId` 启动分析。
> - **流式问答重构**：我们将把视频追问 QA 与知识库聊天 QA 统一重构为 **SSE (Server-Sent Events) 流式打字机效果**，页面将不再在转圈后一次性呈现文本，而是实时逐字显示回答，极大地提升交互的流畅感。
> - **WebSocket 进度监听**：视频总结任务的进度将不再使用 HTTP 2秒轮询，而是实时订阅 WebSocket 端口，在任务完成或报错时自动推进状态。

## Open Questions

> [!WARNING]
> 1. **上传进度 UI 展示**：建议在“本地上传”卡片中央直接显示上传进度（例如：“正在上传: 45%”），并且在上传期间禁用“开始生成初稿”按钮。
> 2. **WebSocket 容灾备份**：若 WebSocket 连接失败或网络受限，是否需要保留轻量级 HTTP 轮询作为自动降级（Fallback）方案？（计划中默认保留，防止 WebSocket 断连导致页面无限卡在“处理中”状态）。

---

## Proposed Changes

### [Component: UI & Flow Control]

#### [MODIFY] [video_summary_flow_controller.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/home/application/video_summary_flow_controller.dart)
- 在 `VideoSummaryFlowState` 中增加 `isUploading` (bool) 与 `uploadProgress` (double) 状态。
- 新增 `pickAndUploadVideo` 异步方法：
  - 调用 `FilePicker.platform.pickFiles(type: FileType.video)` 选择本地视频。
  - 读取文件大小，通过 `UploadService` 初始化并分片上传（每片 10 MiB）。
  - 上传中实时更新 `uploadProgress`；上传完成后调用 `VideoService.createVideo` 注册视频资源。
  - 注册成功后，调用 repository 的 `updateVideoId` 方法，并更新 `videoAsset`。
- 修改 `sendChatMessage`：
  - 将 repository 返回值改为 Stream，循环监听流中产出的回答 delta，动态拼装并更新 `chatMessages` 的最新一条系统回复。

#### [MODIFY] [home_screen.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/home/home_screen.dart)
- 将 `onUploadCardPressed` 对应的回调修改为 `flowController.pickAndUploadVideo`。

#### [MODIFY] [video_summary_ready_stage_workspace.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/home/widgets/video_summary_ready_stage_workspace.dart)
- 传入并读取 `isUploading` 与 `uploadProgress`。
- 上传过程中，在卡片上显示当前进度百分比。
- 上传过程中禁用“开始生成初稿”按钮。

---

### [Component: Repository & Services]

#### [MODIFY] [video_summary_repository.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/home/video_summary_repository.dart)
- 在 `VideoSummaryRepository` 抽象类中声明：
  - `void updateVideoId(String newId);`
  - `Stream<VideoSummaryChatReplyData> sendSummaryChatMessage(String message, {required String timestamp, int? windowSeconds});`

#### [MODIFY] [http_video_summary_repository.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/home/http_video_summary_repository.dart)
- 接受 `Stream<WSEventEnvelope?> wsEventStream` 作为构造参数。
- 移除 `videoId` 的 `final` 关键字，实现 `updateVideoId` 方法以支持动态更换视频 ID。
- 重构 `startDraftGeneration`：
  - 调用 `taskService.createTask` 和 `startAnalysis` 启动分析。
  - 核心变更为：订阅传入的 `wsEventStream`，过滤 `scope == WSScope.videoSummaryTask && scopeId == taskId` 的事件。
  - 提取 WS 事件中的 `progress`、`stage` 和 `message`，转换并 yield `VideoSummaryProcessingData`。
  - 收到 `WSEventType.completed` 事件或 `stage == WSStage.cleanup` 时关闭流，或者在 WebSocket 异常断开时降级使用原本的 `TaskPoller` 轮询。
- 重构 `sendSummaryChatMessage`：
  - 返回 `Stream<VideoSummaryChatReplyData>`。
  - 内部调用 `videoQAService.createTimeTravelQAStream`，解析 `SSEEventType.delta` 追加拼接，直至 `SSEEventType.done`。

#### [MODIFY] [knowledge_base_chat_controller.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/features/knowledge_base/application/knowledge_base_chat_controller.dart)
- 重构 `_sendChatMessage` 内部逻辑：
  - 废弃 `_pollForAnswer` 轮询方法。
  - 改为调用 `_qaService.createQAStream` 建立 SSE 连接，并向 `messages` 列表追加一个空的系统回答。
  - 监听流事件：当收到 `delta` 时，将文本拼接并更新列表最后一条消息；当收到 `done` 时完成，收到 `error` 时显示错误提示。

---

### [Component: WebSocket Client]

#### [MODIFY] [ws_client.dart](file:///c:/Users/36076/Desktop/VidNexus/lib/services/websocket/ws_client.dart)
- **修复 Scheme Bug**：如果解析出的 `baseUrl` 带有 `http://` 或 `https://`，自动在 `connect` 方法中将其转换为 `ws://` / `wss://`，避免 `web_socket_channel` 握手失败。

---

## Verification Plan

### Automated Tests
- 在本地启动 backend FastAPI 服务。
- 运行 Flutter app 并通过开发模式控制台检查：
  - 观察上传文件时的 HTTP PATCH 请求大小（确认是否以 10 MiB 分块发送）。
  - 观察 WebSocket 控制台日志是否正常收到 `progress` 类型的 JSON 数据包。
  - 观察追问时控制台打印出的 SSE text/event-stream `delta` 响应包。

### Manual Verification
- 打开“视频总结”，点击“本地上传”选择一个体积稍大的视频文件，观察卡片是否正确从 0% 更新到 100%。
- 上传完成后，点击“开始生成初稿”，观察三个步骤（Preprocessing、Analysis、Synthesis）的进度条是否跟随 WebSocket 消息丝滑推进。
- 在终稿聊天框内输入任意问题，验证 AI 的回答是否是以**流式打字机效果**逐字显示。
- 进入“知识库会话”，发送问题，验证全局问答是否也支持流式打印。
