## 1. SSE 数据模型层

- [x] 1.1 `SSEEventType` 枚举新增 `progress` 值
- [x] 1.2 新增 `GlobalQAProgressData` 类（`phase`、`message` 字段），含 `fromJson` 工厂方法

## 2. SSE 客户端分发

- [x] 2.1 `SseClient._dispatch()` 新增 `case 'progress': type = SSEEventType.progress;`

## 3. 知识库消息模型

- [x] 3.1 新增 `KnowledgeProgressStep` 类（`phase`、`message`、`timestamp` 字段）
- [x] 3.2 `KnowledgeChatMessage` 新增 `List<KnowledgeProgressStep>? progressSteps` 可选字段

## 4. 聊天控制器

- [x] 4.1 `_sendChatMessage()` 中处理 `SSEEventType.progress` 事件：解析载荷、累加 `KnowledgeProgressStep` 到当前系统消息、emit 新状态

## 5. 等待指示器改造

- [x] 5.1 `AppTypingIndicator` 新增 `String? message` 可选参数，非 null 时显示传入文案，null 时回退默认"AI 正在思考"

## 6. 思考过程组件

- [x] 6.1 新建 `lib/app/widgets/thinking_process_section.dart`，实现 `ThinkingProcessSection` 可折叠组件
- [x] 6.2 组件包含折叠标题栏（"思考过程 (N 步)"，带旋转箭头动画）、展开后的步骤列表
- [x] 6.3 每个步骤显示 phase 对应图标 + message 文案 + 相对耗时
- [x] 6.4 phase 图标映射：`thinking`→psychology, `searching`→search, `retrieved`→check_circle_outline, `loading`→hourglass_bottom, `generating`→auto_awesome, 未知→info_outline

## 7. 聊天 UI 集成

- [x] 7.1 `KnowledgeBaseChatScreen` 等待区传入最新 progress message 到 `AppTypingIndicator`
- [x] 7.2 `_KnowledgeChatBubble` 系统消息气泡中：当 `progressSteps` 非空时，在 `AppMarkdownBody` 上方渲染 `ThinkingProcessSection`

## 8. 验证

- [x] 8.1 确认无 progress 事件时，SSE 流行为与现状完全一致（向后兼容）
- [x] 8.2 确认 progress 事件正确更新等待指示器文案
- [x] 8.3 确认答案完成后思考过程以折叠态保留在气泡中
- [x] 8.4 确认思考过程可展开/收起，动画流畅
