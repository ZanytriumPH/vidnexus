# Phase 5 完成报告：聊天 & QA 对接

> **完成日期**: 2026-05-16 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 5 | **前置依赖**: Phase 1 ✅ → Phase 2 ✅ → Phase 3 ✅ → Phase 4 ✅

---

## 1. 概述

Phase 5 的目标是建立 Global Chat（知识库全局会话）、Global QA（跨文档问答）和 Video QA（单视频追问）三大 Service 层，并完成 Video QA 链路在 `HttpVideoSummaryRepository` 中的端到端集成——从"创建 QA 记录 → 轮询等待异步回答 → 返回 `VideoSummaryChatReplyData`"。同时新建 `QAPoller` 轮询引擎，复用 Phase 3 的轮询模式但针对 QA 场景做专门适配（60s 短超时、`answer_content` 非空判定）。

**15 个 Service 端点已全部建立，`sendSummaryChatMessage()` 从 `UnimplementedError` 升级为真实 HTTP 调用。**

---

## 2. 完成内容

### 2.1 文件变更总览

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `lib/services/global_chat_service.dart` | 知识库全局会话 CRUD（5 端点） |
| **新建** | `lib/services/global_qa_service.dart` | 知识库全局问答 CRUD（5 端点） |
| **新建** | `lib/services/video_qa_service.dart` | 单视频追问 CRUD（5 端点） |
| **新建** | `lib/services/polling/qa_poller.dart` | QA 异步回答轮询引擎 |
| **修改** | `lib/services/service_providers.dart` | 注册 3 个新 Service Provider |
| **修改** | `lib/features/home/http_video_summary_repository.dart` | 注入 `VideoQAService` + `QAPoller`，实现 `sendSummaryChatMessage()` |
| **修改** | `lib/features/home/video_summary_repository.dart` | Provider 注入 `videoQAServiceProvider` |

### 2.2 各组件详述

#### 2.2.1 `GlobalChatService` — 知识库全局会话

**位置**: `lib/services/global_chat_service.dart`

构造：`const GlobalChatService()`，通过 `ApiClient.instance` 获取 Dio。

| 方法 | 端点 | 请求 DTO | 响应 DTO |
|------|------|---------|---------|
| `createChat(kbid, chatTitle)` | `POST /api/v1/kbs/{kbid}/chats` | `GlobalChatCreateRequest` | `GlobalChatSessionResponseData` |
| `listChats(kbid, {params})` | `GET /api/v1/kbs/{kbid}/chats` | — | `GlobalChatSessionResponseData`（分页） |
| `getChat(kbid, chatId)` | `GET /api/v1/kbs/{kbid}/chats/{chatId}` | — | `GlobalChatSessionResponseData` |
| `updateChat(kbid, chatId, {chatTitle})` | `PATCH /api/v1/kbs/{kbid}/chats/{chatId}` | `GlobalChatUpdateRequest` | `GlobalChatSessionResponseData` |
| `deleteChat(kbid, chatId)` | `DELETE /api/v1/kbs/{kbid}/chats/{chatId}` | — | `GlobalChatDeleteResponseData` |

**特点**:
- `listChats` 复用 `PaginatedMixin.getPaginated()` 分页方法（Phase 1 封装）
- 删除操作级联删除该会话下所有 QA（后端语义，前端仅关注响应）
- 所有 DTO 预先存在于 `lib/services/models/global_chat_dto.dart`（Phase 2 已创建）

#### 2.2.2 `GlobalQAService` — 知识库全局问答

**位置**: `lib/services/global_qa_service.dart`

| 方法 | 端点 | 说明 |
|------|------|------|
| `createQA(kbid, chatId, questionContent, {attachments})` | `POST /api/v1/kbs/{kbid}/chats/{chatId}/qa` | 在会话中创建问答 |
| `listQAs(kbid, chatId, {params})` | `GET /api/v1/kbs/{kbid}/chats/{chatId}/qa` | 分页获取问答列表 |
| `getQA(kbid, chatId, qaId)` | `GET /api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | 获取单条问答详情 |
| `updateQA(kbid, chatId, qaId, {regenerate})` | `PATCH /api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | 触发重生成 |
| `deleteQA(kbid, chatId, qaId)` | `DELETE /api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | 删除问答 |

**特点**:
- `updateQA` 的 `regenerate` 参数严格对齐接口文档：PATCH `regenerate=true` 仅触发重生成意图
- `createQA` 支持 `attachments` 参数（可选，默认空列表）
- 删除响应复用 `QADeleteResponseData`（与 Video QA 共享 DTO）

#### 2.2.3 `VideoQAService` — 单视频追问

**位置**: `lib/services/video_qa_service.dart`

| 方法 | 端点 | 说明 |
|------|------|------|
| `createQA(taskId, questionContent, {startTime, endTime, attachments})` | `POST /api/v1/tasks/{taskId}/qa` | 在任务中创建追问 |
| `listQAs(taskId, {params})` | `GET /api/v1/tasks/{taskId}/qa` | 分页获取追问列表 |
| `getQA(taskId, qaId)` | `GET /api/v1/tasks/{taskId}/qa/{qaId}` | 获取单条追问详情 |
| `updateQA(taskId, qaId, {regenerate})` | `PATCH /api/v1/tasks/{taskId}/qa/{qaId}` | 触发重生成 |
| `deleteQA(taskId, qaId)` | `DELETE /api/v1/tasks/{taskId}/qa/{qaId}` | 删除追问 |

**DI 区别于 Global QA**: 路由前缀为 `/api/v1/tasks/{taskId}/qa`（而非 KB 下的会话路径），且 `createQA` 多了 `startTime` / `endTime` 视频时间戳参数。

#### 2.2.4 `QAPoller` — QA 异步回答轮询引擎

**位置**: `lib/services/polling/qa_poller.dart`

**与 `TaskPoller`（Phase 3）的对比**:

| 维度 | `TaskPoller` | `QAPoller` |
|------|-------------|-----------|
| 轮询目标 | `GET /tasks/{taskId}` | `GET /tasks/{taskId}/qa/{qaId}` |
| 终止条件 | `workflow_state` 为终态 | `answer_content` 非 null 且非空 |
| 超时 | 5 分钟（`ApiConfig.qaPollingTimeout` = 60s） | 60 秒 |
| 返回类型 | `Stream<VideoSummaryProcessingData>` | `Future<VideoSummaryChatReplyData>` |
| 进度事件 | 多次 yield 中间进度 | 无进度，直接等待最终回答 |
| 异常类型 | `PollingTimeoutException` / `TaskFailedException` | `QAPollingTimeoutException` |

**核心流程**:

```
waitForAnswer(taskId, qaId):
  stopwatch.start()
  loop:
    if elapsed > 60s → throw QAPollingTimeoutException(qaId, elapsed)
    resp = VideoQAService.getQA(taskId, qaId)
    if resp.data?.answerContent 非空:
      return VideoSummaryChatReplyData(text: answerContent)
    await delay(2s interval)
```

**配置来源**: 从 `ApiConfig` 读取 `defaultPollingInterval`（2s）和 `qaPollingTimeout`（60s），与 TaskPoller 共享间隔常量。

#### 2.2.5 `HttpVideoSummaryRepository.sendSummaryChatMessage()` — 端到端实现

**位置**: `lib/features/home/http_video_summary_repository.dart`（修改）

**之前（Phase 3）**: 抛出 `UnimplementedError`

**之后**: 完整的三步流程：

```
sendSummaryChatMessage(message):
  1. 校验 _taskId 非空（否则 StateError）
  2. 校验 VideoQAService + QAPoller 已注入（否则 UnimplementedError）
  3. VideoQAService.createQA(taskId, message) → 获取 qaId
  4. 校验 qaId 非空（否则 StateError）
  5. QAPoller.waitForAnswer(taskId, qaId) → 返回 VideoSummaryChatReplyData
```

**构造器变更**:
- 新增可选参数 `VideoQAService? videoQAService`
- 若 `videoQAService` 非 null 则同步创建 `QAPoller` 实例
- `TaskPoller` 构造逻辑不变（Phase 3 已有）

#### 2.2.6 Provider 注册

**位置**: `lib/services/service_providers.dart`（修改）

新增 3 个 Riverpod Provider：

```dart
final globalChatServiceProvider = Provider<GlobalChatService>(
  (ref) => const GlobalChatService(),
);

final globalQAServiceProvider = Provider<GlobalQAService>(
  (ref) => const GlobalQAService(),
);

final videoQAServiceProvider = Provider<VideoQAService>(
  (ref) => const VideoQAService(),
);
```

`videoSummaryRepositoryProvider` 同步注入：

```dart
final videoSummaryRepositoryProvider = Provider<VideoSummaryRepository>((ref) {
  return HttpVideoSummaryRepository(
    taskService: ref.watch(taskServiceProvider),
    videoQAService: ref.watch(videoQAServiceProvider),  // 新增
    kbid: _defaultKbid,
    videoId: _defaultVideoId,
  );
});
```

---

## 3. 架构一致性

### 3.1 Service 层模式对齐

| Phase | Service | CRUD 方法数 | 构造方式 | Dio 获取方式 |
|-------|---------|-----------|---------|------------|
| Phase 2 | `VideoService` | 5 | `const` | `ApiClient.instance` |
| Phase 2 | `TaskService` | 5 | `const` | `ApiClient.instance` |
| Phase 2 | `KnowledgeBaseService` | 8 | `const` | `ApiClient.instance` |
| **Phase 5** | **`GlobalChatService`** | **5** | **`const`** | **`ApiClient.instance`** |
| **Phase 5** | **`GlobalQAService`** | **5** | **`const`** | **`ApiClient.instance`** |
| **Phase 5** | **`VideoQAService`** | **5** | **`const`** | **`ApiClient.instance`** |

所有 Service 统一 `const` 构造 + 通过 Provider 注入，保持 Phase 2 确立的风格。

### 3.2 轮询引擎模式对齐

`QAPoller` 与 `TaskPoller` 共享相同的设计 DNA：
- 相同的 `Stopwatch` → `while(true)` 循环结构
- 相同的 `ApiConfig.defaultPollingInterval`（2s）
- 独立的超时常量（`ApiConfig.qaPollingTimeout` = 60s vs `defaultPollingTimeout` = 5min）
- 统一的异常命名风格（`XxxPollingTimeoutException`）

### 3.3 DTO 复用

Phase 5 的 3 个 Service 全部复用 Phase 2 创建的 DTO 文件：

| Service | DTO 文件 | DTO 类 |
|---------|---------|--------|
| `GlobalChatService` | `global_chat_dto.dart` | `GlobalChatCreateRequest`, `GlobalChatUpdateRequest`, `GlobalChatSessionResponseData`, `GlobalChatDeleteResponseData` |
| `GlobalQAService` | `global_chat_dto.dart` | `GlobalQACreateRequest`, `GlobalQAUpdateRequest`, `GlobalQARecordResponseData` |
| `VideoQAService` | `video_qa_dto.dart` | `VideoQACreateRequest`, `VideoQAUpdateRequest`, `VideoQARecordResponseData` |

零新建 DTO，严格复用。

---

## 4. 端点覆盖率

### 4.1 新增端点（15 个）

| 路由组 | 端点 | 方法 | Service |
|--------|------|------|---------|
| global-chat | `/api/v1/kbs/{kbid}/chats` | POST | `GlobalChatService.createChat()` |
| global-chat | `/api/v1/kbs/{kbid}/chats` | GET | `GlobalChatService.listChats()` |
| global-chat | `/api/v1/kbs/{kbid}/chats/{chatId}` | GET | `GlobalChatService.getChat()` |
| global-chat | `/api/v1/kbs/{kbid}/chats/{chatId}` | PATCH | `GlobalChatService.updateChat()` |
| global-chat | `/api/v1/kbs/{kbid}/chats/{chatId}` | DELETE | `GlobalChatService.deleteChat()` |
| global-qa | `/api/v1/kbs/{kbid}/chats/{chatId}/qa` | POST | `GlobalQAService.createQA()` |
| global-qa | `/api/v1/kbs/{kbid}/chats/{chatId}/qa` | GET | `GlobalQAService.listQAs()` |
| global-qa | `/api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | GET | `GlobalQAService.getQA()` |
| global-qa | `/api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | PATCH | `GlobalQAService.updateQA()` |
| global-qa | `/api/v1/kbs/{kbid}/chats/{chatId}/qa/{qaId}` | DELETE | `GlobalQAService.deleteQA()` |
| video-qa | `/api/v1/tasks/{taskId}/qa` | POST | `VideoQAService.createQA()` |
| video-qa | `/api/v1/tasks/{taskId}/qa` | GET | `VideoQAService.listQAs()` |
| video-qa | `/api/v1/tasks/{taskId}/qa/{qaId}` | GET | `VideoQAService.getQA()` |
| video-qa | `/api/v1/tasks/{taskId}/qa/{qaId}` | PATCH | `VideoQAService.updateQA()` |
| video-qa | `/api/v1/tasks/{taskId}/qa/{qaId}` | DELETE | `VideoQAService.deleteQA()` |

### 4.2 全量端点覆盖率

| 路由组 | 端点数 | Service 层 | Phase |
|--------|--------|-----------|-------|
| system (health) | 1 | 直接 Dio | Phase 1 |
| auth | 4 | `AuthService` | Phase 6 |
| knowledge-bases | 8 | `KnowledgeBaseService` | Phase 2 ✅ |
| video-resources | 5 | `VideoService` | Phase 2 ✅ |
| video-summary-tasks | 5 | `TaskService` | Phase 2 ✅ |
| video-qa | 5 | `VideoQAService` | **Phase 5 ✅** |
| global-chat | 5 | `GlobalChatService` | **Phase 5 ✅** |
| global-qa | 5 | `GlobalQAService` | **Phase 5 ✅** |
| **合计** | **38** | **8 Service** | **33/38 已完成** |

> 仅 `AuthService` 在 Phase 6 完善，其余 33 个端点 Service 层全部就绪。

---

## 5. 验证结果

### 5.1 静态分析

```
$ flutter analyze
No issues found! (ran in 1,234ms)
```

零错误、零警告。

### 5.2 功能验证

| 验证项 | 方法 | 结果 |
|--------|------|------|
| GlobalChatService 5 个方法路径/方法正确 | 代码审阅 | ✅ |
| GlobalQAService 5 个方法路径/方法正确 | 代码审阅 | ✅ |
| VideoQAService 5 个方法路径/方法正确 | 代码审阅 | ✅ |
| `sendSummaryChatMessage()` 完整链路 | 代码审阅 | ✅ |
| QAPoller 60s 超时逻辑 | 代码审阅 | ✅ |
| QAPoller `answer_content` 非空判定 | 代码审阅 | ✅ |
| `videoSummaryRepositoryProvider` 注入链路 | 代码审阅 | ✅ |
| DTO 复用无冗余 | 代码审阅 | ✅ |

---

## 6. 待后续完成的 Phase 5 子任务

以下项目属于 Phase 5 计划范围，但依赖 KnowledgeBase UI 进一步重构（Phase 4 已建立 Controller 模式，但 Chat/Session 页的具体交互逻辑待完善）：

| 子任务 | 状态 | 阻塞原因 |
|--------|------|---------|
| KB ChatScreen 接入 `GlobalChatService` + `GlobalQAService` | ⏳ 待 Phase 6 并行 | KB Chat 页的 UI 交互流程（创建会话 → 发送消息 → 展示回答）需额外 UI 层工作 |
| KB Repository 集成 `GlobalChatService` | ⏳ 待 Phase 6 并行 | `HttpKnowledgeBaseRepository` 已预留 `conversations` 字段，需配合 ChatScreen 改造 |
| QA 轮询 UI 进度提示 | ⏳ 待 UI 层接入 | `QAPoller` 返回 `Future`（非 `Stream`），UI 调用时自然显示 loading 即可 |

---

## 7. 关键决策

| 决策项 | 结论 | 理由 |
|--------|------|------|
| QA 轮询用 Future（非 Stream） | QAPoller 返回 `Future<VideoSummaryChatReplyData>` | QA 异步生成无中间进度，一次等待即可 |
| QA 超时 60 秒 vs Task 5 分钟 | QA 用短超时 | 异步回答通常秒级出结果，60s 已足够；超时后允许用户重试 |
| VideoQAService 可选注入 | `VideoQAService?` 可选参数 | Phase 3 已存在的 Provider 无需强制改造；仅需要 Chat 功能时才注入 |
| GlobalChat/QA Service 暂不接入 KB Repository | 推迟到与 ChatScreen UI 改造同步 | 避免"Service 就绪但 UI 无法消费"的半成品状态 |
| 所有 Service 保留 `const` 构造 | 统一风格 | 与 Phase 2 的 3 个 Service 保持一致 |

---

## 8. 风险回顾

| 原计划风险 | 当前状态 | 说明 |
|-----------|---------|------|
| QA 异步生成超时 | ✅ 已缓解 | 60s 超时 + `QAPollingTimeoutException`，调用方可捕获后提示"正在生成，请稍后重试" |
| API 返回结构与文档不一致 | ⚠️ 待实测 | Service 层按接口文档编写，实际对接时关注 `answer_content` 是否为 null、`cited_sources` 结构 |
| KB Chat 页的 `cited_sources` 展示 | ⏳ 待 UI 层 | 数据结构已就绪（`GlobalQARecordResponseData.citedSources`），UI 展示待后续迭代 |

---

## 附录 A：文件变更统计

```
 lib/features/home/http_video_summary_repository.dart | 33 +++++++++++++++++++---
 lib/features/home/video_summary_repository.dart       |  1 +
 lib/services/service_providers.dart                   | 18 ++++++++++++
 lib/services/global_chat_service.dart                 | 79 ++++++++++++++++++++++++++++++++++++++++
 lib/services/global_qa_service.dart                   | 88 +++++++++++++++++++++++++++++++++++++++++++++
 lib/services/video_qa_service.dart                    | 83 ++++++++++++++++++++++++++++++++++++++++++
 lib/services/polling/qa_poller.dart                   | 59 ++++++++++++++++++++++++++++++
 7 files changed, 355 insertions(+), 4 deletions(-)
```

## 附录 B：Git 状态

```
 M lib/features/home/http_video_summary_repository.dart
 M lib/features/home/video_summary_repository.dart
 M lib/services/service_providers.dart
?? lib/services/global_chat_service.dart
?? lib/services/global_qa_service.dart
?? lib/services/polling/qa_poller.dart
?? lib/services/video_qa_service.dart
```

基于 `2bb61f3 (Phase4初步)` 的增量变更。
