# VidNexus 前后端 API 对接实施计划

> **创建日期**: 2026-05-16 | **依据**: `docs/plan/FRONTEND_BACKEND_API_INTERFACE_CN.md`（35 个端点，8 组路由）

**TL;DR** — 基于已完备的 DTO 层（7 个 DTO 文件覆盖全部 35 个端点）和 API 端点常量，按"视频总结 → 知识库 → 全局聊天 → 视频QA"的优先级，逐步建立 Service 层 → 用 `HttpVideoSummaryRepository` 替换 `FakeVideoSummaryRepository` → 轮询接入 Processing 进度 → 完善认证流程。严格遵循现有架构分层：Repository 只返回 domain 数据，UI 经 Mapper 转换，HomeScreen 保持壳角色。

---

## Phase 1: 基础设施增强

> ⏱ 预计 1-2 天 | 后续所有 Phase 的前置依赖

**目标**: 为 Service 层提供可切换环境、统一错误处理、分页封装。

**Steps**

1. **API 配置可运行化**
   - 新建 `lib/services/api/api_config.dart` — 提供运行时 `baseUrl`（默认 `http://10.0.2.2:8000`），支持从 SecureStorage 或调试面板覆盖
   - 修改 `ApiClient._create()` 从 `ApiConfig` 读取 baseUrl，保留 `String.fromEnvironment` 作编译期兜底
   - *目的：方便切换开发/测试/生产环境，无需重新编译*

2. **统一错误拦截器**
   - 新建 `lib/services/api/error_interceptor.dart`
   - 将 `DioException` 统一映射为 `ApiError`：识别 401（未授权）/404（不存在）/409（冲突）/422（校验失败）/500（服务端错误）
   - 对非 401 错误，按 `ApiError.userMessage` 产出中文提示
   - 注册到 Dio 拦截器链（在 LogInterceptor 之后、AuthInterceptor 之前）

3. **分页请求封装**
   - 在 `common_dto.dart` 中新增 `PageParams` 类（page, pageSize, fields, sort, cursor）
   - 提供 `Future<ApiListResponse<T>> getPaginated(...)` 通用方法，避免手写 query 拼接

4. **Dio Transformer 增强（可选）**
   - 验证当前 JSON 编解码对 `snake_case` 字段的兼容性（现有 DTO 已手动 toJson/fromJson，无需自动转换）
   - 确认 `Content-Type: application/json` 在所有 POST/PATCH 请求中生效

**验证**

- `flutter analyze` 零错误
- 切换 `ApiConfig.baseUrl` 后 ApiClient 使用新地址
- 模拟 401/404/409/422/500 响应，ErrorInterceptor 产出正确的 `ApiError`

**相关文件**

| 操作 | 文件 |
|------|------|
| 新建 | `lib/services/api/api_config.dart` |
| 新建 | `lib/services/api/error_interceptor.dart` |
| 修改 | `lib/services/api/api_client.dart` |
| 修改 | `lib/services/models/common_dto.dart` |

---

## Phase 2: 核心 Service 层 — 视频总结链路

> ⏱ 预计 2-3 天 | 依赖 Phase 1

**目标**: 建立覆盖"视频资源 → 总结任务"完整链路的 Service 类，为 Repository 真实实现提供 HTTP 调用能力。

**Steps**

1. **VideoService**（`lib/services/video_service.dart`）
   - `createVideo(fileName)` → POST `/api/v1/videos` → `ApiResponse<VideoResourceResponseData>`
   - `getVideo(videoId)` → GET `/api/v1/videos/{videoId}`
   - `listVideos({page, pageSize})` → GET `/api/v1/videos` → `ApiListResponse<VideoResourceResponseData>`
   - `updateVideo(videoId, fileName)` → PATCH `/api/v1/videos/{videoId}`
   - `deleteVideo(videoId)` → DELETE `/api/v1/videos/{videoId}`（注意 202 受理语义）
   - *复用现有 DTO：`VideoResourceCreateRequest`, `VideoResourceUpdateRequest`, `VideoResourceResponseData`, `VideoResourceDeleteResponseData`*

2. **TaskService**（`lib/services/task_service.dart`）
   - `createTask(kbid, videoId, userInitialPreference?)` → POST `/api/v1/tasks` → `ApiResponse<VideoSummaryTaskResponseData>`
   - `getTask(taskId)` → GET `/api/v1/tasks/{taskId}`
   - `listTasks({page, pageSize})` → GET `/api/v1/tasks` → `ApiListResponse<VideoSummaryTaskResponseData>`
   - `updateTask(taskId, {draftSummary, userGuidance, title})` → PATCH `/api/v1/tasks/{taskId}`
   - `deleteTask(taskId)` → DELETE `/api/v1/tasks/{taskId}`
   - *复用现有 DTO：`TaskCreateRequest`, `TaskUpdateRequest`, `VideoSummaryTaskResponseData`, `TaskDeleteResponseData`*

3. **KnowledgeBaseService**（`lib/services/knowledge_base_service.dart`）
   - `createKB(...)` / `listKBs(...)` / `getKB(kbid)` / `updateKB(...)` / `deleteKB(kbid)`
   - `bindVideo(kbid, videoId)` / `listVideos(kbid, ...)` / `unbindVideo(kbid, videoId)`
   - *复用现有 DTO：`KnowledgeBaseCreateRequest`, `KnowledgeBaseUpdateRequest`, `KnowledgeBaseResponseData`, `KBVideoBindRequest`, `KBVideoBindResponseData`*

4. **Provider 注册**
   - 新建 `lib/services/service_providers.dart`，将所有 Service 注册为 Riverpod Provider
   - 所有 Service 为 const 构造函数 + 通过 Provider 注入 Dio 实例

**验证**

- 每个 Service 方法单元测试验证路径/方法/请求体正确
- `flutter analyze` 零错误

**相关文件**

| 操作 | 文件 |
|------|------|
| 新建 | `lib/services/video_service.dart` |
| 新建 | `lib/services/task_service.dart` |
| 新建 | `lib/services/knowledge_base_service.dart` |
| 新建 | `lib/services/service_providers.dart` |

---

## Phase 3: VideoSummaryRepository 真实实现 + 轮询

> ⏱ 预计 3-4 天 | 依赖 Phase 2 | 🔥 核心难点

**目标**: 用 `HttpVideoSummaryRepository` 替换 `FakeVideoSummaryRepository`，UI 层零改动。

**Steps**

1. **Domain 模型扩展**
   - 在 `video_summary_domain_models.dart` 中新增 `VideoSummaryTaskInfo`（聚合 taskId/videoId/workflowState/draft/final 文本），作为 Repository 返回给 Mapper 的中间结构
   - 定义 `WorkflowState` 枚举：`DRAFT_GENERATING` / `DRAFT_READY` / `FINAL_GENERATING` / `COMPLETED` / `FAILED`（对齐 API `workflow_state` 字段）

2. **HttpVideoSummaryRepository**
   - 新建 `lib/features/home/http_video_summary_repository.dart`，`implements VideoSummaryRepository`
   - 注入 VideoService + TaskService + KnowledgeBaseService
   - 各方法映射：
     - `getVideoAsset()` → `VideoService.getVideo()` → `VideoAssetInfo`
     - `startDraftGeneration()` → `TaskService.createTask()` + 启动轮询 → `Stream<VideoSummaryProcessingData>`
     - `fetchDraftResult()` → `TaskService.getTask()` → 提取 `draft_summary` → `VideoSummaryDraftData`
     - `generateFinalSummary()` → `TaskService.updateTask(userGuidance)` + 轮询等待状态流转 → `VideoSummaryFinalResultData`
     - `sendSummaryChatMessage()` → 调用 VideoQAService（Phase 5 实现），初版可抛 `UnimplementedError`

3. **轮询策略**（`lib/services/polling/task_poller.dart`）
   - `Timer.periodic` 默认 2 秒间隔，可配置
   - 轮询 `GET /api/v1/tasks/{taskId}`，检测 `workflow_state` 变化
   - 将状态变化转化为 `Stream<VideoSummaryProcessingData>` 事件
   - 超时 5 分钟 → `PollingTimeoutException`
   - 状态映射：

     | API workflow_state | 前端阶段 | 说明 |
     |---|---|---|
     | `DRAFT_GENERATING` | Processing | progress 从 draft_summary 长度/时间估算 |
     | `DRAFT_READY` | Draft | 初稿就绪 |
     | `FINAL_GENERATING` | Processing | 二次处理动画 |
     | `COMPLETED` | Final Chat | 终稿就绪 |
     | `FAILED` | 错误 | 提示用户重试 |

4. **Provider 切换**
   - 修改 `video_summary_repository.dart` 中的 Provider，通过 flag 切换 Fake/Http 实现
   - 保留 `FakeVideoSummaryRepository` 用于测试和 Demo

5. **Mapper 适配**
   - 修改 `video_summary_result_mapper.dart`，新增 `WorkflowState` → 中文状态标签映射
   - 确保 API DTO（snake_case）能正确映射到 Presentation Models

**验证**

- HttpVideoSummaryRepository 通过 Mock Service 单元测试
- 轮询逻辑在 Task 状态变化时正确推送事件
- 现有 4 个 stage UI 无需改动即可运行
- `flutter analyze` 零错误
- 现有 Widget 测试继续通过（Fake Repository 保留用于测试）

**相关文件**

| 操作 | 文件 |
|------|------|
| 新建 | `lib/features/home/http_video_summary_repository.dart` |
| 新建 | `lib/services/polling/task_poller.dart` |
| 修改 | `lib/features/home/domain/video_summary_domain_models.dart` |
| 修改 | `lib/features/home/video_summary_repository.dart` |
| 修改 | `lib/features/home/application/video_summary_result_mapper.dart` |

---

## Phase 4: 知识库真实对接

> ⏱ 预计 2-3 天 | 依赖 Phase 2 & 3

**目标**: 替换知识库模块的 demo 数据，接入真实 API，适度调整 UI。

**Steps**

1. **KnowledgeBase Repository**
   - 新建抽象接口：`listKBs()`, `getKB()`, `createKB()`, `updateKB()`, `deleteKB()`, `listVideos()`, `bindVideo()`, `unbindVideo()`
   - 新建 `HttpKnowledgeBaseRepository` 真实实现

2. **KnowledgeBase Controller**
   - 新建 `lib/features/knowledge_base/application/knowledge_base_controller.dart`
   - Riverpod `Notifier` 管理知识库列表、当前选中、视频列表状态
   - 替换现有页面中的硬编码 demo 数据

3. **UI 适度调整**
   - `KnowledgeBaseHomeScreen` — 列表从 Controller 读取，支持下拉刷新
   - `KnowledgeBaseSessionScreen` — 从 API 拉取当前 KB 下的视频列表
   - `KnowledgeBaseChatScreen` — 为 Phase 5 GlobalChat API 预留接口
   - `KnowledgeBaseSourcesScreen` — 从 API 获取引用来源数据

4. **路由参数对齐**
   - 确保 `kbid` 等参数通过 `AppRouteArguments` 正确传递
   - 当前路由为 `/knowledge-base`、`/knowledge-base/session` 等，可能需扩展为带参数路由

**验证**

- 创建/查看/编辑/删除知识库全流程可用
- 知识库绑定/解绑视频功能可用
- `flutter analyze` 零错误

**相关文件**

| 操作 | 文件 |
|------|------|
| 新建 | `lib/features/knowledge_base/knowledge_base_repository.dart` |
| 新建 | `lib/features/knowledge_base/http_knowledge_base_repository.dart` |
| 新建 | `lib/features/knowledge_base/application/knowledge_base_controller.dart` |
| 修改 | `lib/features/knowledge_base/knowledge_base_home_screen.dart` |
| 修改 | `lib/features/knowledge_base/knowledge_base_session_screen.dart` |
| 修改 | `lib/features/knowledge_base/knowledge_base_chat_screen.dart` |
| 修改 | `lib/features/knowledge_base/knowledge_base_sources_screen.dart` |

---

## Phase 5: 聊天 & QA 对接

> ⏱ 预计 2-3 天 | 依赖 Phase 4

**目标**: 接入 Global Chat（知识库全局会话）+ Global QA（跨文档问答）+ Video QA（单视频追问）。

**Steps**

1. **GlobalChatService**（`lib/services/global_chat_service.dart`）
   - CRUD 5 个端点：`createChat` / `listChats` / `getChat` / `updateChat` / `deleteChat`
   - 复用已有 DTO：`GlobalChatCreateRequest`, `GlobalChatUpdateRequest`, `GlobalChatSessionResponseData`, `GlobalChatDeleteResponseData`

2. **GlobalQAService**（`lib/services/global_qa_service.dart`）
   - CRUD 5 个端点：`createQA` / `listQAs` / `getQA` / `updateQA` / `deleteQA`
   - 复用已有 DTO：`GlobalQACreateRequest`, `GlobalQAUpdateRequest`, `GlobalQARecordResponseData`

3. **VideoQAService**（`lib/services/video_qa_service.dart`）
   - CRUD 5 个端点：`createQA(taskId, ...)` / `listQAs` / `getQA` / `updateQA` / `deleteQA`
   - 复用已有 DTO：`VideoQACreateRequest`, `VideoQAUpdateRequest`, `VideoQARecordResponseData`

4. **Repository 集成**
   - `HttpVideoSummaryRepository.sendSummaryChatMessage()` 接入 `VideoQAService`
   - KnowledgeBase Repository 接入 `GlobalChatService` + `GlobalQAService`

5. **QA 轮询策略**
   - QA 创建后 `answer_content` 为 null（异步生成中）
   - 复用 `TaskPoller` 或新建 `QAPoller`，轮询单个 QA 直到 `answer_content` 非 null
   - 超时 60 秒

6. **Regenerate 语义处理**
   - PATCH regenerate=true 仅触发重生成意图（对齐接口文档差异说明）
   - 前端在 PATCH 后开始轮询，直到 `answer_content` 更新

**验证**

- 知识库下创建/切换/删除全局会话
- 在全局会话中提问并收到回答（含 `cited_sources` 展示）
- 在视频总结 Final Chat 阶段提问并收到回答
- `flutter analyze` 零错误

**相关文件**

| 操作 | 文件 |
|------|------|
| 新建 | `lib/services/global_chat_service.dart` |
| 新建 | `lib/services/global_qa_service.dart` |
| 新建 | `lib/services/video_qa_service.dart` |
| 修改 | `lib/features/home/http_video_summary_repository.dart` |
| 修改 | `lib/features/knowledge_base/http_knowledge_base_repository.dart` |

---

## Phase 6: 认证流程完善

> ⏱ 预计 1-2 天 | 可与 Phase 3-5 并行

**目标**: 完成登录/注册之外的认证体验闭环。

**Steps**

1. **启动会话恢复**
   - AuthController 初始化时检查 SecureStorage 中是否有有效 token
   - 若有 → 调用 `GET /api/v1/auth/me` 验证
   - 有效 → 直接进入主页（跳过登录页）
   - 若 401 → 尝试 refresh → 成功则进主页，失败则清除 token 进登录页

2. **登出功能**
   - `AuthController.logout()` — 清除 SecureStorage 中的 access/refresh token + deviceId
   - 清除 Dio AuthInterceptor 中的 token 缓存
   - Navigator 重置到登录页
   - 在 HomeScreen 设置中提供登出入口

3. **Token 过期用户提示**
   - refresh 失败时（AuthInterceptor 调用 `onRefreshFailed`）
   - 弹出 SnackBar/Dialog 提示"登录已过期，请重新登录"
   - 自动跳转登录页

4. **Request ID 追踪**
   - 完善 `x-request-id` header：使用 UUID 格式
   - 在 ErrorInterceptor 中记录 request ID 到日志

**验证**

- 登录后关闭 App 再打开，自动恢复会话
- 登出后 token 被清除，无法访问需鉴权接口
- Token 过期后自动跳转登录页
- `flutter analyze` 零错误

**相关文件**

| 操作 | 文件 |
|------|------|
| 修改 | `lib/features/auth/auth_controller.dart` |
| 修改 | `lib/features/auth/auth_state.dart` |
| 修改 | `lib/services/api/auth_interceptor.dart` |
| 修改 | `lib/app/app.dart`（启动时检查登录状态） |

---

## Phase 7: 集成测试与文档

> ⏱ 预计 1-2 天 | 依赖 Phase 3-6

**Steps**

1. **端到端测试**
   - 编写 `test/features/home/video_summary_http_repository_test.dart`
   - Mock Dio 响应，验证 Repository 正确解析 API 数据 + 轮询逻辑

2. **API 对接检查清单**
   - 35 个端点逐条验证 Service 方法覆盖率
   - 每个 Service 方法的请求/响应结构对齐接口文档

3. **文档更新**
   - 创建 `docs/plan/API_INTEGRATION_STATUS.md` 记录对接进度
   - 标注已完成/进行中/待开始模块

**验证**

- 所有新增测试通过
- `flutter analyze` 零错误
- 35 个端点覆盖率 100%

---

## 关键决策

| 决策项 | 结论 | 理由 |
|--------|------|------|
| 视频上传 | 仅创建资源记录，文件上传暂不涉及 | `POST /api/v1/videos` 仅接收 `file_name` |
| Processing 进度 | 轮询 `GET /tasks/{taskId}`，2s 间隔 | API 无 SSE/WebSocket，通过 `workflow_state` 字段推断 |
| 对接优先级 | 视频总结 → 知识库 → 全局聊天 → 视频QA | 按核心链路优先 |
| 知识库 UI | 允许适度调整，路由结构不变 | 匹配 API 数据结构 |
| Fake Repository | 永久保留 | 用于测试和 Demo |
| 环境配置 | 编译期默认 + 运行时可覆盖 | 方便切换环境 |

## 架构边界（严格遵循 `AI_DEVELOPMENT_GUIDE.md` 约束）

- Repository 只返回 domain 数据，不返回 UI 展示模型
- UI 展示模型由 `video_summary_result_mapper.dart` 产出
- HomeScreen 保持页面壳角色（装配 Provider + 组装 Widgets）
- 新增 Service 统一放 `lib/services/`
- 路由变更走 `lib/app/routing/`，使用 `AppNavigator`
- 新输入框/编辑态纳入 `video_summary_text_editing_controller`
- 不主动迁移 `go_router`

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 轮询对服务端压力 | 中 | 低 | 仅中间态轮询，终态立即停止；间隔可配置 |
| API 返回结构与文档不一致 | 中 | 高 | Phase 2 对照文档逐字段验证，差异记录到 `API_INTEGRATION_STATUS.md` |
| Fake → Http 切换影响现有 UI | 低 | 高 | 实现相同接口，Provider 切换对 UI 完全透明 |
| QA 异步生成超时 | 中 | 中 | 60s 超时 + "正在生成"提示，超时后允许重试 |
| Auth 拦截器与启动恢复时序冲突 | 低 | 中 | Phase 6 启动恢复在 AuthInterceptor 注册前独立处理 |

---

## 附录：端点覆盖率目标

| 路由组 | 端点数 | 对应 Service | Phase |
|--------|--------|-------------|-------|
| system (health) | 1 | 直接 Dio 调用 | Phase 1 |
| auth | 4 | AuthService（已有） | Phase 6 完善 |
| knowledge-bases | 8 | KnowledgeBaseService | Phase 2/4 |
| video-resources | 5 | VideoService | Phase 2 |
| video-summary-tasks | 5 | TaskService | Phase 2 |
| video-qa | 5 | VideoQAService | Phase 5 |
| global-chat | 5 | GlobalChatService | Phase 5 |
| global-qa | 5 | GlobalQAService | Phase 5 |
| **合计** | **38** | | |

> 注：接口文档中路由总览表含 35 条记录。上表按路由组统计的 38 条包含 health 端点，实际对接覆盖数与文档严格对齐。
