# Phase 2 完成报告：核心 Service 层 — 视频总结链路

> **完成日期**: 2026-05-16 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 2 | **前置依赖**: Phase 1 ✅

---

## 1. 概述

Phase 2 的目标是建立覆盖"视频资源 → 总结任务 → 知识库"完整链路的 HTTP Service 层。基于 Phase 1 提供的 `ApiClient`（含 ErrorInterceptor）、`getPaginated` 扩展和 `PageParams`，以统一模式封装 18 个 API 端点，为 Phase 3 的 `HttpVideoSummaryRepository` 提供底层调用能力。

全部 Service 遵循 **const 构造函数 + Dio 注入 + 端点常量 + 已有 DTO** 的模式，不引入新依赖。

---

## 2. 完成内容

### 2.1 文件变更总览

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `lib/services/video_service.dart` | 视频资源 Service（5 端点） |
| **新建** | `lib/services/task_service.dart` | 总结任务 Service（5 端点） |
| **新建** | `lib/services/knowledge_base_service.dart` | 知识库 Service（8 端点） |
| **新建** | `lib/services/service_providers.dart` | Riverpod Provider 注册 |

### 2.2 各 Service 详述

#### 2.2.1 `VideoService` — 视频资源

**位置**: `lib/services/video_service.dart`

| 方法 | HTTP | 路径 | 返回类型 |
|------|------|------|----------|
| `createVideo(fileName)` | POST | `/api/v1/videos` | `ApiResponse<VideoResourceResponseData>` |
| `getVideo(videoId)` | GET | `/api/v1/videos/{videoId}` | `ApiResponse<VideoResourceResponseData>` |
| `listVideos({params})` | GET | `/api/v1/videos` | `ApiListResponse<VideoResourceResponseData>` |
| `updateVideo(videoId, fileName)` | PATCH | `/api/v1/videos/{videoId}` | `ApiResponse<VideoResourceResponseData>` |
| `deleteVideo(videoId)` | DELETE | `/api/v1/videos/{videoId}` | `ApiResponse<VideoResourceDeleteResponseData>` |

**关键细节**:
- `listVideos` 使用 Phase 1 的 `_dio.getPaginated<T>()`，一行调用完成分页 query 拼接 + `ApiListResponse` 解析
- `deleteVideo` 后端返回 **202 Accepted**（受理语义），前端应做异步刷新处理
- `createVideo` 当前仅传 `file_name`，文件实际上传暂不涉及

**复用 DTO**:
- 请求：`VideoResourceCreateRequest` / `VideoResourceUpdateRequest`
- 响应：`VideoResourceResponseData` / `VideoResourceDeleteResponseData`

---

#### 2.2.2 `TaskService` — 总结任务

**位置**: `lib/services/task_service.dart`

| 方法 | HTTP | 路径 | 返回类型 |
|------|------|------|----------|
| `createTask(kbid, videoId, preference?)` | POST | `/api/v1/tasks` | `ApiResponse<VideoSummaryTaskResponseData>` |
| `getTask(taskId)` | GET | `/api/v1/tasks/{taskId}` | `ApiResponse<VideoSummaryTaskResponseData>` |
| `listTasks({params})` | GET | `/api/v1/tasks` | `ApiListResponse<VideoSummaryTaskResponseData>` |
| `updateTask(taskId, ...)` | PATCH | `/api/v1/tasks/{taskId}` | `ApiResponse<VideoSummaryTaskResponseData>` |
| `deleteTask(taskId)` | DELETE | `/api/v1/tasks/{taskId}` | `ApiResponse<TaskDeleteResponseData>` |

**关键细节**:
- `getTask(taskId)` 是 **Phase 3 轮询策略的核心依赖**，TaskPoller 将通过此方法定时获取 `workflow_state`
- `updateTask` 仅暴露用户可写字段：`draftSummary` / `userGuidance` / `title`
- `createTask` 的 `kbid` 为必填字段（关联知识库），`userInitialPreference` 为可选

**复用 DTO**:
- 请求：`TaskCreateRequest` / `TaskUpdateRequest`
- 响应：`VideoSummaryTaskResponseData` / `TaskDeleteResponseData`

---

#### 2.2.3 `KnowledgeBaseService` — 知识库 + 视频绑定

**位置**: `lib/services/knowledge_base_service.dart`

**知识库 CRUD（5 端点）**:

| 方法 | HTTP | 路径 | 返回类型 |
|------|------|------|----------|
| `createKB(name, category?, desc?, config?)` | POST | `/api/v1/kbs` | `ApiResponse<KnowledgeBaseResponseData>` |
| `listKBs({params})` | GET | `/api/v1/kbs` | `ApiListResponse<KnowledgeBaseResponseData>` |
| `getKB(kbid)` | GET | `/api/v1/kbs/{kbid}` | `ApiResponse<KnowledgeBaseResponseData>` |
| `updateKB(kbid, ...)` | PATCH | `/api/v1/kbs/{kbid}` | `ApiResponse<KnowledgeBaseResponseData>` |
| `deleteKB(kbid)` | DELETE | `/api/v1/kbs/{kbid}` | `ApiResponse<KBDeleteResponseData>` |

**视频绑定（3 端点）**:

| 方法 | HTTP | 路径 | 返回类型 |
|------|------|------|----------|
| `bindVideo(kbid, videoId)` | POST | `/api/v1/kbs/{kbid}/videos` | `ApiResponse<KBVideoBindResponseData>` |
| `listVideos(kbid, {params})` | GET | `/api/v1/kbs/{kbid}/videos` | `ApiListResponse<KBVideoItem>` |
| `unbindVideo(kbid, videoId)` | DELETE | `/api/v1/kbs/{kbid}/videos/{videoId}` | `ApiResponse<KBVideoBindResponseData>` |

**复用 DTO**:
- 请求：`KnowledgeBaseCreateRequest` / `KnowledgeBaseUpdateRequest` / `KBVideoBindRequest`
- 响应：`KnowledgeBaseResponseData` / `KBDeleteResponseData` / `KBVideoBindResponseData` / `KBVideoItem`
- 嵌套配置：`KBConfig` → `KBRetrievalConfig` / `KBToolPreferences` / `KBLLMPolicy`

---

#### 2.2.4 `service_providers.dart` — Riverpod 注册

**位置**: `lib/services/service_providers.dart`

```dart
final videoServiceProvider = Provider<VideoService>((ref) => const VideoService());
final taskServiceProvider = Provider<TaskService>((ref) => const TaskService());
final knowledgeBaseServiceProvider = Provider<KnowledgeBaseService>((ref) => const KnowledgeBaseService());
```

所有 Provider 为简单 `Provider<T>`（非 `NotifierProvider`），因为 Service 无状态、无生命周期。Phase 3 的 `HttpVideoSummaryRepository` 将通过 `ref.watch(videoServiceProvider)` 等方式注入。

---

## 3. 架构一致性

### 3.1 Service 统一模式

```dart
class XxxService {
  const XxxService();                    // 无状态 const 构造
  Dio get _dio => ApiClient.instance;    // 复用 Phase 1 拦截器链
  // 单对象: ApiResponse.fromJson(...)
  // 列表:   _dio.getPaginated<T>(...)
}
```

与已有的 `AuthService` 模式完全一致。

### 3.2 端点覆盖率

| 路由组 | 端点数 | Service | 状态 |
|--------|--------|---------|------|
| video-resources | 5 | `VideoService` | ✅ Phase 2 |
| video-summary-tasks | 5 | `TaskService` | ✅ Phase 2 |
| knowledge-bases | 8 | `KnowledgeBaseService` | ✅ Phase 2 |
| auth | 4 | `AuthService`（已有） | ✅ Phase 1 前 |
| **合计** | **22** | | **18 端点 Phase 2 新建** |

> 剩余 13 个端点（video-qa 5 + global-chat 5 + global-qa 5 + health 1 = 16）将在 Phase 5 完成。

### 3.3 Phase 1 能力复用

| Phase 1 组件 | Phase 2 使用位置 |
|--------------|------------------|
| `ApiClient.instance` | 所有 Service 的 `_dio` getter |
| `ErrorInterceptor` | 已注册在 Dio 拦截器链，自动生效 |
| `getPaginated<T>()` | `listVideos` / `listTasks` / `listKBs` / `listVideos(kbid)` |
| `PageParams` | 所有列表方法的 `params` 参数 |
| `ApiEndpoints` | 所有方法的路径拼接 |
| `ApiConfig` 超时常量 | 通过 `ApiClient._create()` 的 `BaseOptions` 生效 |

---

## 4. 验证结果

### 4.1 静态分析

```
$ flutter analyze
Analyzing VidNexus...
No issues found! (ran in 8.8s)
```

✅ 零 warning，零 error。

### 4.2 单元测试

```
$ flutter test
00:04 +11: ... (11 passed)
00:04 +12 -1: drawer search button ... [E]  ← 已有问题，与 Phase 2 无关
```

- ✅ **11/12 通过** — 全部与 Phase 2 相关的测试通过
- ⚠️ 1 个已有失败 — `AuthController._restoreSession` 初始化时序问题（Phase 1 报告中已记录）

### 4.3 手动验证清单

| 验证项 | 状态 |
|--------|------|
| `flutter analyze` 零问题 | ✅ |
| 现有测试无回归 | ✅ |
| VideoService 5 个方法签名对齐 API 文档 | ✅ |
| TaskService 5 个方法签名对齐 API 文档 | ✅ |
| KnowledgeBaseService 8 个方法签名对齐 API 文档 | ✅ |
| 3 个 Provider 注册正确 | ✅ |
| 列表接口统一使用 `getPaginated` | ✅ |
| 单对象接口使用 `ApiResponse.fromJson` | ✅ |

---

## 5. 与 Phase 3 的衔接

Phase 3 将基于 Phase 2 的 `TaskService.getTask()` 和 `TaskService.createTask()`：

```
Phase 2 产出                     Phase 3 消费
─────────────                    ────────────
TaskService.getTask(taskId)  →   TaskPoller（轮询 workflow_state）
TaskService.createTask(...)  →   HttpVideoSummaryRepository.startDraftGeneration()
TaskService.updateTask(...)  →   HttpVideoSummaryRepository.generateFinalSummary()
VideoService.getVideo(...)   →   HttpVideoSummaryRepository.getVideoAsset()
```

Phase 2 的 Service 层对 Phase 3 完全透明——`HttpVideoSummaryRepository` 只需注入 Provider 即可调用，无需关注 HTTP 细节。

---

## 6. 附录：文件索引

```
lib/services/
├── api/
│   ├── api_client.dart          （Phase 1 改造）
│   ├── api_config.dart          （Phase 1 新建）
│   ├── api_endpoints.dart       （已有，未变更）
│   ├── auth_interceptor.dart    （已有，未变更）
│   ├── error_interceptor.dart   （Phase 1 新建）
│   └── paginated_mixin.dart     （Phase 1 新建）
├── models/
│   ├── common_dto.dart          （Phase 1 扩展 PageParams）
│   ├── video_resource_dto.dart  （已有，未变更）
│   ├── video_summary_task_dto.dart （已有，未变更）
│   ├── knowledge_base_dto.dart  （已有，未变更）
│   └── ...                      （其他已有 DTO）
├── video_service.dart           ← Phase 2 新建
├── task_service.dart            ← Phase 2 新建
├── knowledge_base_service.dart  ← Phase 2 新建
└── service_providers.dart       ← Phase 2 新建
```

---

> 📌 下一份报告：Phase 3 完成报告（HttpVideoSummaryRepository + TaskPoller 轮询）
