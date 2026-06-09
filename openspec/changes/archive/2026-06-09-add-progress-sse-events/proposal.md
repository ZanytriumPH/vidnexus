## Why

Knowledge base QA 后端使用 ReAct agent 范式，在用户提问到首个回答 token 之间有 5–30 秒的黑盒等待期。当前前端只显示泛化的"AI 正在思考..."呼吸动画，用户无法得知后端处于哪个阶段（思考、检索、分析、生成），产生等待焦虑。引入中间 SSE 进度事件后，前端可以展示具体状态文案，消除不确定性，提升体验。

## What Changes

- 新增 `SSEEventType.progress` 事件类型，对应后端 `event: progress` SSE 消息
- 新增 `GlobalQAProgressData` 载荷模型，解析 `phase` 和 `message` 字段
- `KnowledgeChatMessage` 新增 `progressSteps` 可选字段，在聊天记录中持久化代理思考过程
- 聊天控制器处理 `progress` 事件，实时累加进度步骤到系统消息
- 等待指示器 `AppTypingIndicator` 支持动态状态文案，替代固定"AI 正在思考"
- 新增可折叠 `ThinkingProcessSection` 组件，在答案气泡中展示思考过程历史

所有改动均为增量添加，不影响现有 `start` / `delta` / `done` / `error` 事件的处理逻辑。后端不发送 `progress` 事件时，前端行为与现在完全一致。

## Capabilities

### New Capabilities

- `knowledge-qa-progress-streaming`: 在知识库 QA 对话中，接收并展示后端的 ReAct agent 进度事件。前端将进度文案实时展示在等待指示器中，并在答案完成后以可折叠形式保留在聊天记录中。

### Modified Capabilities

_无。本改动不修改任何已有能力的规格级行为，仅为增量添加。_

## Impact

- **Affected code**: SSE 模型层、SSE 客户端、知识库消息模型、聊天控制器、聊天 UI 屏幕、新组件
- **Affected APIs**: `POST /api/v1/kbs/{kbid}/chats/{chat_id}/qa/stream` — 新增 `event: progress` 响应（前端兼容，后端不需改前端也能正常工作）
- **Dependencies**: 无新增依赖
- **Breaking changes**: 无
