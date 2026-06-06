# 最终稿生成 — 进度反馈与等待态 UI 开发计划

> 版本：v2.0（简化版，取消 SSE 流式输出）
> 日期：2026-06-06
> 目标：用户点击"生成最终稿"后，进入 finalChat 阶段的等待态，HeroCard 展示后端实时进度日志，生成完毕后一次性展示最终稿结果。

---

## 一、需求概述

```
用户点击 [生成最终稿]
  → 页面从 draft 阶段切换到 finalChat 阶段（isGenerating=true）
  → HeroCard 标题变为 "最终稿生成中..."
  → HeroCard 小字轮播 WebSocket 推送的中文进度消息
  → HeroCard 以下区域不显示任何内容（无正文卡片、无追问输入框）
  → 后端 WebSocket completed 事件到达后
      → HeroCard 恢复为正常 finalChat 样式
      → 最终稿卡片（FinalSummaryBubble）一次性出现
      → "加入知识库" 按钮可点击
      → 追问对话输入框出现
```

### 设计决策

| 维度 | 决策 |
|------|------|
| 数据通道 | **复用现有 WebSocket + approveAndFinalize API**，后端零改动 |
| 页面阶段 | **finalChat 子状态**：`isGenerating=true` 时显示等待态 UI |
| 进度日志 | WS `progress` 事件的 `message` 字段，HeroCard 小字展示 |
| 生成中正文区域 | **不显示任何内容** |
| 完成后页面 | 恢复现有 finalChat 完整样式 |

---

## 二、后端改动

**无。** 完全复用现有链：

- `POST /api/v1/tasks/{task_id}/approve-and-finalize` → 202
- `WS /ws/progress` → 已有完整的 progress 事件推送：

```
status_update: "Phase-2 finalization started"
progress:      "🧵 [Session] 当前会话 thread_id: xxx"
progress:      "🚀 [Finalization] 审批通过，进入第二阶段..."
progress:      "🧩 [Synthesizer Agent] 正在根据人类审批稿生成全篇总结..."
progress:      "⚖️ [Hallucination Guard] 正在进行事实一致性审查..."
progress:      "🎯 [Usefulness Guard] 正在进行需求命中审查..."
completed:     { final_summary: "...", workflow_state: "COMPLETED" }
```

---

## 三、前端改动

### 3.1 状态模型扩展

**文件**: `lib/features/home/application/video_summary_flow_controller.dart`

```dart
class VideoSummaryFlowState {
  // ... 现有字段 ...

  /// 最终稿生成期间的 WS 进度日志（最新在前，最多保留 20 条）
  final List<String> finalDraftProgressLogs;

  // copyWith() 同步新增
}
```

### 3.2 generateFinalSummary() 重写

```dart
Future<void> generateFinalSummary({
  required String guidance,
  required String draftBodyText,
}) async {
  final draft = state.draftResult;
  if (state.isGenerating || draft == null) return;

  final editedParagraphs = draftBodyText
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final effectiveDraft = DraftResult(
    paragraphs: editedParagraphs.isEmpty ? draft.paragraphs : editedParagraphs,
    suggestionHint: draft.suggestionHint,
  );

  final owningSessionKey = _activeSessionKey;

  // ★ 立即进入 finalChat 阶段
  state = state.copyWith(
    stage: VideoSummaryStage.finalChat,
    isGenerating: true,
    finalDraftProgressLogs: [],
    draftResult: effectiveDraft,
    finalSummaryData: null,
    chatMessages: const [],
  );

  try {
    _listenFinalDraftProgress();

    final summary = await _repository.generateFinalSummary(
      guidance: guidance,
      draftParagraphs: effectiveDraft.paragraphs,
    );

    if (_activeSessionKey != owningSessionKey) return;

    final summaryData = mapFinalResultDataToSummary(summary);
    final seededRange = _buildRangeFromSummary(summaryData);

    state = state.copyWith(
      isGenerating: false,
      finalSummaryData: summaryData,
      chatMessages: List<ChatMessage>.from(summaryData.messages),
      selectedTimestampStartSeconds: seededRange.startSeconds,
      selectedTimestampEndSeconds: seededRange.endSeconds,
    );
  } finally {
    if (_activeSessionKey == owningSessionKey) {
      _cancelFinalDraftProgress();
      state = state.copyWith(isGenerating: false);
    }
  }
}
```

### 3.3 WS Progress 日志监听

```dart
StreamSubscription<WSEventEnvelope>? _finalDraftProgressSub;

void _listenFinalDraftProgress() {
  _cancelFinalDraftProgress();

  final taskId = state.taskId;
  if (taskId == null) return;

  final wsStream = ref.read(wsEventProvider).where(
    (env) =>
        env.scope == WSScope.videoSummaryTask &&
        env.scopeId == taskId &&
        (env.eventType == WSEventType.progress ||
         env.eventType == WSEventType.statusUpdate),
  );

  Timer? debounce;
  _finalDraftProgressSub = wsStream.listen((env) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      final message = env.message;
      if (message != null && message.isNotEmpty) {
        state = state.copyWith(
          finalDraftProgressLogs: [
            message,
            ...state.finalDraftProgressLogs.take(19),
          ],
        );
      }
    });
  });
}

void _cancelFinalDraftProgress() {
  _finalDraftProgressSub?.cancel();
  _finalDraftProgressSub = null;
}
```

### 3.4 HeroCard 新增参数

**文件**: `lib/features/home/widgets/video_summary_processing_widgets.dart`

```dart
class HeroCard extends StatelessWidget {
  // ... 现有参数 ...

  final bool isFinalGenerating;
  final String? finalDraftProgressMessage;
}
```

当 `stage == finalChat && isFinalGenerating` 时：

| 元素 | 值 |
|------|-----|
| StatusPill | "生成中" |
| title | "最终稿生成中..."（16px, w800, 深色） |
| subtitle | WS 最新日志 / "正在提交审批..."（12px, #384A59） |
| WhiteButtonBar | "视频回放"（保持） |

### 3.5 FinalChatStageWorkspace 分支

**文件**: `lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart`

```dart
class FinalChatStageWorkspace extends StatefulWidget {
  // ... 现有参数 ...
  final bool isGenerating;
  final String? finalDraftProgressMessage;
}

// build() 方法：
@override
Widget build(BuildContext context) {
  if (widget.isGenerating) {
    // ★ 生成中：只显示 HeroCard，下方完全空白
    return SingleChildScrollView(
      child: HeroCard(
        stage: VideoSummaryStage.finalChat,
        isFinalGenerating: true,
        finalDraftProgressMessage: widget.finalDraftProgressMessage,
        highlighted: widget.highlighted,
        videoAsset: widget.videoAsset,
        processingSnapshot: null,
        processingExpanded: false,
        onTap: widget.onUploadCardPressed,
        onVideoPlayback: widget.onVideoPlayback,
      ),
    );
  }

  // 正常 finalChat 视图（现有逻辑完全不动）
  return Column(/* ... */);
}
```

### 3.6 VideoSummaryWorkspace 传参

```dart
// when 条件放宽：
VideoSummaryStage.finalChat when finalSummaryData != null || isGenerating =>
  FinalChatStageWorkspace(
    // ... 现有参数 ...
    isGenerating: isGenerating,
    finalDraftProgressMessage:
        finalDraftProgressLogs.isNotEmpty ? finalDraftProgressLogs.first : null,
  ),
```

### 3.7 改动文件清单

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `video_summary_flow_controller.dart` | **重写** | `generateFinalSummary()` 立即进入 finalChat |
| `video_summary_flow_controller.dart` | **新增字段** | `finalDraftProgressLogs` |
| `video_summary_flow_controller.dart` | **新增方法** | `_listenFinalDraftProgress()` / `_cancelFinalDraftProgress()` |
| `video_summary_processing_widgets.dart` | **修改** | `HeroCard` 支持 `isFinalGenerating` + `finalDraftProgressMessage` |
| `video_summary_final_chat_stage_workspace.dart` | **修改** | 新增生成中分支 + 新参数 |
| `video_summary_content_widgets.dart` | **修改** | when 条件放宽 + 新字段透传 |
| `home_screen.dart` | **修改** | 透传 `finalDraftProgressLogs` |
| `video_summary_final_chat_widgets.dart` | **无改动** | — |
| `http_video_summary_repository.dart` | **无改动** | — |

---

## 四、数据流图

```
┌──────────┐   点击 [生成最终稿]    ┌──────────────────────────┐
│  draft   │ ──────────────────→  │  finalChat stage          │
│  stage   │                      │  isGenerating = true       │
└──────────┘                      └──────────┬───────────────┘
                                             │
                          ┌──────────────────┘
                          ▼
        ┌─────────────────────────────────────┐
        │  Repository.generateFinalSummary()   │
        │  ├─ approveAndFinalize API           │
        │  └─ 等待 WS completed (900s 超时)     │
        └─────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  Controller._listenFinalDraftProgress│
        │  ├─ 订阅 WS progress/status_update   │
        │  └─ 500ms 防抖 → progressLogs        │
        └──────────┬──────────────────────────┘
                   │
                   ▼
        ┌──────────────────┐
        │  HeroCard         │
        │  "最终稿生成中..." │
        │  WS 中文日志小字   │
        │  下方：无内容      │
        └──────────────────┘

        WS completed 到达后：
        ┌──────────────────────────────────────┐
        │  isGenerating = false                 │
        │  HeroCard → "当前会话已切换为可追问..."  │
        │  FinalSummaryBubble 出现               │
        │  ChatComposer 出现                     │
        └──────────────────────────────────────┘
```

---

## 五、UI 状态对照表

| 状态 | HeroCard 标题 | HeroCard 小字 | 正文区域 | 追问输入框 |
|------|--------------|--------------|---------|-----------|
| 生成中 | "最终稿生成中..." | WS 最新日志 | **无内容** | 隐藏 |
| 生成完毕 | "当前会话已切换为可追问对话窗口" | 无 | FinalSummaryBubble + 对话 | 显示 |

---

## 六、边界情况

| 场景 | 处理方式 |
|------|----------|
| WS 无 progress 事件 | 小字保留默认 "正在提交审批..." |
| 后端 error | `isGenerating=false`，HeroCard 显示错误信息 |
| 用户生成中退出 | `_cancelFinalDraftProgress()`；恢复走 `_resumeFinalGeneration` |
| 超时（900s） | Repository 已有 TimeoutException |
| 切换会话 | `_activeSessionKey` 保护 |

---

## 七、实现顺序

1. **Phase 1** — Controller: `finalDraftProgressLogs` + `generateFinalSummary()` 重写 + WS 监听
2. **Phase 2** — HeroCard: `isFinalGenerating` + `finalDraftProgressMessage`
3. **Phase 3** — FinalChatStageWorkspace: 生成中分支
4. **Phase 4** — VideoSummaryWorkspace + home_screen: 传参透传
5. **Phase 5** — 端到端验证

---

## 八、注意事项

1. **draft 阶段 isGenerating**：点击后立即切换到 finalChat，draft 阶段的 isGenerating 不再需要，但保留设置以防 UI 闪烁。

2. **恢复会话**：`_resumeFinalGeneration` 需同步适配——生成中恢复时应进入 `finalChat` + `isGenerating=true`，而非当前 `draft`。

3. **session_history_controller.dart 的 FINAL_GENERATING 映射**：
   ```dart
   WorkflowState.finalGenerating => VideoSummaryStage.draft,
   ```
   需评估恢复场景：若后端为 FINAL_GENERATING，前端恢复后应进 `finalChat` + `isGenerating=true` 并重订阅 WS。
```

---

## 与旧版的关键差异

| 维度 | v1.0（SSE 流式） | v2.0（当前） |
|------|-----------------|-------------|
| 后端改动 | 4 个文件（新 SSE 端点 + LLM streaming） | **0 个文件** |
| 前端仓库层 | 新增 `streamFinalSummary()` | **0 改动** |
| 前端状态字段 | +`streamingFinalDraftText` | 只需 +`finalDraftProgressLogs` |
| 生成中正文区域 | AI 思考气泡 + 流式 Markdown | **完全空白** |
| Hallucination Guard 重写 | 需 `restart` 事件清空前文 | **无影响** |
| 前端改动文件数 | 11 个 | **7 个** |

方案大幅简化，后端完全不碰，前端也少了近一半的改动量。要我把这个内容写入文件吗？（需要切换到编辑模式）---

## 与旧版的关键差异

| 维度 | v1.0（SSE 流式） | v2.0（当前） |
|------|-----------------|-------------|
| 后端改动 | 4 个文件（新 SSE 端点 + LLM streaming） | **0 个文件** |
| 前端仓库层 | 新增 `streamFinalSummary()` | **0 改动** |
| 前端状态字段 | +`streamingFinalDraftText` | 只需 +`finalDraftProgressLogs` |
| 生成中正文区域 | AI 思考气泡 + 流式 Markdown | **完全空白** |
| Hallucination Guard 重写 | 需 `restart` 事件清空前文 | **无影响** |
| 前端改动文件数 | 11 个 | **7 个** |

方案大幅简化，后端完全不碰，前端也少了近一半的改动量。要我把这个内容写入文件吗？（需要切换到编辑模式）