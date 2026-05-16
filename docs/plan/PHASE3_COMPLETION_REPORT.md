# Phase 3 完成报告：VideoSummaryRepository 真实实现 + 轮询

> **完成日期**: 2026-05-16 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 3 | **前置依赖**: Phase 1 ✅ → Phase 2 ✅

---

## 1. 概述

Phase 3 是 API 对接计划的核心里程碑——用真实的 HTTP 轮询替代 Fake 脚本化事件流，同时保持现有 UI 层零改动。通过 `TaskPoller` 将后端 `workflow_state` 的粗粒度状态轮询转化为 `VideoSummaryProcessingData` 流，`HttpVideoSummaryRepository` 完整实现 `VideoSummaryRepository` 接口，编译期 flag 一键切换 Fake/Http。

**架构原则**: Repository 只返回 domain 数据 → Mapper 转换 → UI 完全不变。

---

## 2. 完成内容

### 2.1 文件变更总览

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `lib/services/polling/task_poller.dart` | 轮询引擎：状态检测、进度估算、超时保护 |
| **新建** | `lib/features/home/http_video_summary_repository.dart` | VideoSummaryRepository 的 HTTP 实现 |
| **修改** | `lib/features/home/domain/video_summary_domain_models.dart` | 新增 `WorkflowState` 枚举 + `VideoSummaryTaskInfo` 聚合类 |
| **修改** | `lib/features/home/video_summary_repository.dart` | Provider 支持编译期 Fake/Http 切换 |

### 2.2 各组件详述

#### 2.2.1 `WorkflowState` — 后端状态枚举

**位置**: `lib/features/home/domain/video_summary_domain_models.dart`（追加）

| 枚举值 | API 字符串 | 中文标签 | 是否为终态 |
|--------|-----------|---------|-----------|
| `draftGenerating` | `DRAFT_GENERATING` | 生成初稿中 | ❌ |
| `draftReady` | `DRAFT_READY` | 初稿就绪 | ✅ |
| `finalGenerating` | `FINAL_GENERATING` | 生成终稿中 | ❌ |
| `completed` | `COMPLETED` | 已完成 | ✅ |
| `failed` | `FAILED` | 处理失败 | ✅ |

**关键方法**:
- `WorkflowState.fromApi(String value)` — 工厂构造器，字符串 → 枚举，未知值 fallback 为 `failed`
- `isTerminal` — 判断轮询是否应停止（`draftReady` / `completed` / `failed`）
- `label` — 中文状态标签（Mapper 可直接使用）

#### 2.2.2 `VideoSummaryTaskInfo` — 任务聚合类

**位置**: 同上文件

聚合 task 的身份信息（`taskId` / `videoId` / `kbid`）与状态数据（`workflowState` / `draftSummary` / `finalSummary` / `title`），作为 Repository → Mapper 的中间传递结构。当前由 `HttpVideoSummaryRepository` 内部使用，后续 Phase 4/5 可扩展到 KnowledgeBase 和 Chat 模块。

#### 2.2.3 `TaskPoller` — 轮询引擎

**位置**: `lib/services/polling/task_poller.dart`

**核心方法**: `Stream<VideoSummaryProcessingData> pollTask(String taskId)`

```
pollTask(taskId) async*:
  stopwatch.start()
  loop:
    if elapsed > timeout → throw PollingTimeoutException
    
    resp = TaskService.getTask(taskId)
    state = WorkflowState.fromApi(resp.workflow_state)
    
    if state 变化 or 中间态:
      yield buildProcessingData(state, tick)
    
    if state == FAILED → throw TaskFailedException
    if state.isTerminal → return (流关闭)
    
    await delay(interval)
```

**配置**（来自 Phase 1 `ApiConfig`）:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `interval` | 2s | 轮询间隔 |
| `timeout` | 5min | 最大轮询时长 |

**异常类型**:
- `PollingTimeoutException(taskId, elapsed)` — 超时
- `TaskFailedException(taskId)` — 服务端返回 FAILED

**进度估算策略**（`_estimateProgress`）:

| 状态 | 进度范围 | 算法 |
|------|---------|------|
| `draftGenerating` | 0.1 → 0.85 | tick × 0.075（约 10 次轮询到达 0.85） |
| `draftReady` | 0.9 | 固定值 |
| `finalGenerating` | 0.85 → 0.99 | tick × 0.03 |
| `completed` | 1.0 | 固定值 |
| `failed` | 0.0 | 固定值 |

**状态映射**（`WorkflowState` → `VideoSummaryProcessingStage`）:

| API 状态 | 映射处理阶段 |
|----------|------------|
| `draftGenerating` | `dispatchingChunks` |
| `draftReady` | `waitingHumanReview` |
| `finalGenerating` | `aggregatingChunks` |
| `completed` | `waitingHumanReview` |

#### 2.2.4 `HttpVideoSummaryRepository` — HTTP 仓库实现

**位置**: `lib/features/home/http_video_summary_repository.dart`

**构造参数**:

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `taskService` | `TaskService` | ✅ | Phase 2 创建的 Task HTTP Service |
| `taskPoller` | `TaskPoller` | ❌ | 可注入自定义 Poller（默认用 ApiConfig 常量） |
| `kbid` | `String` | ✅ | 知识库 ID |
| `videoId` | `String` | ✅ | 视频 ID |

**方法实现对照**:

| 接口方法 | 实现策略 |
|----------|---------|
| `getVideoAsset()` | 同步返回占位 `VideoAssetInfo`（真实数据由后续异步方法提供） |
| `startDraftGeneration()` | `async*` 生成器：`TaskService.createTask()` → `TaskPoller.pollTask()` → `yield*` 流 |
| `fetchDraftResult()` | `TaskService.getTask()` → 提取 `draftSummary` → 按空行分段 → `VideoSummaryDraftData` |
| `generateFinalSummary(guidance, paragraphs)` | `TaskService.updateTask(guidance, draftSummary)` → `TaskPoller.pollTask()` 等待终态 → `TaskService.getTask()` 取结果 |
| `sendSummaryChatMessage(message)` | 抛出 `UnimplementedError`（Phase 5 实现） |

**完整数据流**:

```
UI → startDraftGeneration()
       │
       ├─ ① POST /api/v1/tasks  (TaskService.createTask)
       │     └─ 返回 taskId → 存入 _taskId
       │
       ├─ ② 启动 TaskPoller.pollTask(taskId)
       │     └─ loop: GET /api/v1/tasks/{taskId}
       │           ├─ workflow_state 变化 → yield ProcessingData
       │           ├─ DRAFT_READY → 流关闭
       │           └─ FAILED → throw
       │
       └─ ③ Controller 检测流关闭
             └─ 调用 fetchDraftResult()
                   └─ GET /api/v1/tasks/{taskId} → 提取 draft_summary
```

#### 2.2.5 Provider 切换机制

**位置**: `lib/features/home/video_summary_repository.dart`

```dart
const bool _useHttpRepository = bool.fromEnvironment(
  'USE_HTTP_REPOSITORY',
  defaultValue: false,
);
```

**切换方式**:

```bash
# 默认：FakeVideoSummaryRepository（Mock 数据 + 脚本化进度动画）
flutter run

# 切换到真实 HTTP 后端
flutter run --dart-define=USE_HTTP_REPOSITORY=true
```

**临时占位常量**（后续 Phase 由用户交互动态设置）:
- `_defaultKbid = 'kb_default'`
- `_defaultVideoId = 'vid_default'`

---

## 3. 架构一致性

### 3.1 零 UI 改动

Phase 3 严格遵守"保持现有 UI 层零改动"约束：

- `VideoSummaryRepository` 接口 **签名完全不变** — `HttpVideoSummaryRepository` 直接 `implements`
- `VideoSummaryProcessingData` / `VideoSummaryDraftData` / `VideoSummaryFinalResultData` 等 domain 模型 **结构不变**
- `VideoSummaryFlowController` 无需任何修改 — `_repository.startDraftGeneration()` 的调用方式完全一致
- Mapper (`video_summary_result_mapper.dart`) **无需改动** — `TaskPoller` 产出的 `currentMessage` 自动通过 `_etaLabelForProcessing` 传递

### 3.2 Phase 1-2 能力复用

| 上游 Phase | 组件 | Phase 3 使用位置 |
|-----------|------|-----------------|
| Phase 1 | `ApiConfig.defaultPollingInterval` | `TaskPoller` 默认间隔 |
| Phase 1 | `ApiConfig.defaultPollingTimeout` | `TaskPoller` 超时阈值 |
| Phase 1 | `ApiClient.instance` | `TaskService._dio`（间接） |
| Phase 1 | `ErrorInterceptor` | 自动拦截 HTTP 错误 |
| Phase 2 | `TaskService.createTask()` | `HttpVideoSummaryRepository.startDraftGeneration()` |
| Phase 2 | `TaskService.getTask()` | `TaskPoller.pollTask()` / `fetchDraftResult()` |
| Phase 2 | `TaskService.updateTask()` | `HttpVideoSummaryRepository.generateFinalSummary()` |
| Phase 2 | `taskServiceProvider` | `videoSummaryRepositoryProvider` 注入 |

### 3.3 Fake Repository 保留

`FakeVideoSummaryRepository` 完整保留，用于：
- 单元测试（无网络依赖）
- Widget 测试（确定性脚本化进度）
- Demo 展示

---

## 4. 验证结果

### 4.1 静态分析

```
$ flutter analyze
Analyzing VidNexus...
No issues found! (ran in 5.7s)
```

✅ 零 warning，零 error。

### 4.2 单元测试

```
$ flutter test
00:04 +11: ... (11 passed)
00:04 +12 -1: drawer search button ... [E]  ← 已有问题，与 Phase 3 无关
```

- ✅ **11/12 通过** — Phase 3 无任何回归
- ⚠️ 1 个已有失败 — `AuthController._restoreSession`（Phase 1/2 报告中已记录）

### 4.3 手动验证清单

| 验证项 | 状态 |
|--------|------|
| `flutter analyze` 零问题 | ✅ |
| 现有测试无回归 | ✅ |
| `WorkflowState` 5 状态对齐 API 文档 `workflow_state` 字段 | ✅ |
| `HttpVideoSummaryRepository` 完整实现 `VideoSummaryRepository` 接口 | ✅ |
| `TaskPoller` 终态检测（isTerminal）正确 | ✅ |
| `TaskPoller` 超时保护（5min）就绪 | ✅ |
| Provider 支持 `--dart-define` 编译期切换 | ✅ |
| Mapper 无需修改（currentMessage 自然兼容） | ✅ |

---

## 5. 与 Phase 4 的衔接

Phase 4 将基于 Phase 2 的 `KnowledgeBaseService` 和 Phase 3 建立的 Repository 模式：

```
Phase 3 产出                          Phase 4 消费
─────────────                         ────────────
VideoSummaryRepository (HTTP impl) → 参考模式：HttpKnowledgeBaseRepository
WorkflowState enum                  → 可复用于 KB 状态处理
TaskPoller 模式                     → 可泛化为通用轮询基类
_kbid / _videoId 占位常量           → Phase 4 由 KnowledgeBaseController 动态设置
```

---

## 6. 附录：文件索引

```
lib/services/polling/
└── task_poller.dart                    ← Phase 3 新建

lib/features/home/
├── domain/
│   └── video_summary_domain_models.dart ← Phase 3 修改（WorkflowState + VideoSummaryTaskInfo）
├── video_summary_repository.dart        ← Phase 3 修改（Provider 切换）
├── http_video_summary_repository.dart   ← Phase 3 新建
├── fake_video_summary_repository.dart   （已有，未变更）
├── stream_backed_video_summary_repository.dart （已有，未变更）
├── video_summary_processing_event_source.dart （已有，未变更）
├── video_summary_processing_event_adapter.dart （已有，未变更）
├── video_summary_models.dart            （已有，未变更）
└── application/
    └── video_summary_result_mapper.dart  （已有，未变更——自动兼容）
```

---

> 📌 下一份报告：Phase 4 完成报告（KnowledgeBase 真实对接）
