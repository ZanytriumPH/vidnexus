## Context

知识库 QA 后端采用 ReAct agent 范式。在一次 QA 请求中，agent 循环执行"思考→检索→观察→生成"步骤。当前 SSE 流仅向客户端发送 `start` / `delta` / `done` / `error` 四种事件，`start` 到第一个 `delta` 之间可能存在 5–30 秒的静默期，前端在此期间只能展示泛化的"AI 正在思考..."指示器。

后端已新增 `progress` 事件类型，在每个 ReAct 步骤完成时广播当前阶段和可读文案。本设计描述前端如何消费和展示这些事件。

### 约束

- Flutter 移动端，使用 Riverpod + ChangeNotifier 状态管理
- SSE 客户端基于 Dio `ResponseType.stream`
- 聊天 UI 使用 `ListView` + `KnowledgeChatMessage` 模型
- 所有改动必须向后兼容（后端不发送 `progress` 时行为与现状一致）

## Goals / Non-Goals

**Goals:**
- 接收并解析 `event: progress` SSE 消息
- 在等待期间将当前进度文案实时展示给用户
- 答案完成后，将完整思考过程以可折叠形式保留在聊天记录中
- 支持 5 种后端定义的 phase：`thinking`、`searching`、`retrieved`、`loading`、`generating`
- 增量兼容：不修改任何已有事件的处理逻辑

**Non-Goals:**
- 不做步骤进度条或百分比（后端不承诺步骤总数）
- 不修改视频 QA 的 SSE 流（本次仅作用于知识库全局 QA）
- 不改变消息持久化格式（progressSteps 仅在内存中，不落盘）
- 不做思考过程的搜索或跨会话复用

## Decisions

### Decision 1: progressSteps 挂载在 KnowledgeChatMessage 上

**选择**: 在 `KnowledgeChatMessage` 上增加 `List<KnowledgeProgressStep>? progressSteps` 可选字段。

**备选方案**:
- A) 独立的进度消息类型 — 需要修改消息列表类型、增加渲染分支、影响历史加载逻辑
- B) 全局状态字段（`statusMessage`）— 思考过程在答案完成后丢失，不符合"保留在聊天记录"的需求

**理由**: 挂载在现有消息上最小化模型改动，且自然满足"折叠在气泡内"的 UI 需求。`null` 时渲染行为完全不变。

### Decision 2: Progress 事件与 Delta 事件共享同一个系统消息

**选择**: `progress` 事件将步骤追加到 Controller 创建的空系统消息上，`delta` 事件向同一条消息追加文本。

**理由**: 避免在消息列表中创建多条碎片消息（一个 progress 一条消息会导致列表抖动）。用户感知到的是一条"AI 回答"，思考过程是这条回答的元数据。

### Decision 3: ThinkingProcessSection 复用 CitationCards 的折叠模式

**选择**: 新建 `ThinkingProcessSection` 组件，折叠交互与 `CitationCards` 一致（点击标题栏切换，`AnimatedCrossFade` 过渡）。

**理由**: 保持 UI 一致性，减少学习成本。用户已经熟悉引用来源的折叠交互，"思考过程"的折叠方式完全一致。

### Decision 4: Phase → 图标映射写在前端

**选择**: 前端维护静态映射表 `{thinking: psychology, searching: search, retrieved: check_circle, loading: hourglass_bottom, generating: auto_awesome}`。

**备选方案**: 后端在 `progress` 事件中传图标名 — 增加后端职责，且限制前端设计自由。

**理由**: 图标属于展示层决策，不应由后端控制。前端可以随时调整映射而不需要后端配合。

### Decision 5: AppTypingIndicator 增加可选 message 参数

**选择**: 给 `AppTypingIndicator` 增加 `String? message` 参数，`null` 时默认"AI 正在思考"。

**理由**: 最小化 API 变更。所有现有调用点无需修改。

### Decision 6: SSE 事件分发采用"未知事件静默跳过"策略

**选择**: `SseClient._dispatch()` 对未知 event 字段返回 `null`，调用方通过 `if (event == null) continue` 跳过。

**理由**: 天然向后兼容。后端新增事件类型不需要前端同步升级，前端新增事件类型不需要后端保证一定发送。双方独立演进。

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   SSE Stream                            │
│  event: start / progress / delta / done / error        │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  SseClient._dispatch()                                  │
│  event="progress" → SSEEventType.progress               │
│  未知 event → return null（静默跳过）                    │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  KnowledgeBaseChatController._sendChatMessage()         │
│                                                          │
│  progress: 累加 KnowledgeProgressStep 到系统消息         │
│  delta:    追加 chunk 到系统消息文本                     │
│  done:     最终化答案 + citedSources                    │
│                                                          │
│  所有处理 → _emit() → notifyListeners()                 │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  KnowledgeBaseChatScreen UI                             │
│                                                          │
│  等待中: AppTypingIndicator(message: latestProgress)     │
│  有文本: _KnowledgeChatBubble →                         │
│           ├─ ThinkingProcessSection (if has steps)       │
│           ├─ AppMarkdownBody (answer text)               │
│           └─ CitationCards (if has sources)              │
└──────────────────────────────────────────────────────────┘
```

## Data Flow (Timeline)

```
  Controller                          UI
  ──────────                        ──────
  sendMessage("...")
  │ _emit(isWaiting=true,
  │       emptySysMsg)
  │                                 AppTypingIndicator("AI正在思考...")  ← 默认文案
  │
  │ SSE: progress(thinking,"正在分析...")
  │ _emit(sysMsg.progressSteps=[step1])
  │                                 AppTypingIndicator("正在分析你的问题...") ← 动态文案
  │
  │ SSE: progress(searching,"正在检索...")
  │ _emit(sysMsg.progressSteps=[step1, step2])
  │                                 AppTypingIndicator("正在从知识库检索...")
  │
  │ SSE: delta("根据视频...")
  │ _emit(sysMsg.text="根据视频...")
  │                                 第一个 delta → typing indicator 消失
  │                                 系统气泡出现，含 ThinkingProcessSection(折叠)
  │                                 "根据视频..." 流式追加
  │
  │ SSE: done(citedSources=[...])
  │ _emit(isWaiting=false)
  │                                 最终答案展示，折叠的思考过程 + 引用来源
```

## Risks / Trade-offs

- **[低] 高频 progress 导致过多重建**: 后端在 ReAct 循环中可能为一个长任务发送 10+ 个 progress 事件，每次触发 `notifyListeners()` → UI `setState`。**缓解**: progress 事件频率远低于 delta（秒级 vs 毫秒级），对帧率无影响。
- **[低] 思考过程仅内存保留**: `progressSteps` 在 Controller 销毁后丢失，不会持久化到后端。**缓解**: 这是设计选择——思考过程属于临时调试信息，不需要跨会话持久化。后续如有需要可在后端存储。
- **[低] 单消息多步骤的内存开销**: 每个 `KnowledgeProgressStep` 持有 phase/message/timestamp，典型 ReAct 循环 5–10 步，总计 < 2KB。**缓解**: 无需优化。

## Open Questions

- 无。后端 phase 枚举已确认，前端全部支持。
