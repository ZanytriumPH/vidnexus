## Plan: 初稿最终稿 Markdown 重构

目标是让“初稿正文”和“最终稿”两张卡片支持 markdown 展示，同时不破坏当前 application / domain / widgets 的边界。推荐方案是：把 markdown 能力收敛成一个 widgets 层的通用渲染组件，初稿继续保留源码编辑态，退出编辑后按 markdown 预览；最终稿作为只读卡片直接复用同一组件。会话计划我已经同步保存好了，后续可以直接按这份执行。

**Steps**
1. 在 pubspec.yaml 引入轻量 markdown 渲染依赖，并限定 markdown 只在 widgets 层消费，不进入 repository、domain 或 mapper。
2. 在 video_summary_draft_stage_workspace.dart 和 video_summary_final_chat_widgets.dart 之外，新增一个通用的 markdown 展示 widget，统一封装标题、段落、列表、引用、代码块、链接等样式。
3. 改造 video_summary_draft_stage_workspace.dart 里的 DraftBodyCard：编辑态继续使用现有 TextField 和 controller，非编辑态从直接 Text 切到 markdown 渲染组件。
4. 改造 video_summary_final_chat_widgets.dart 里的 _FinalSummaryBubble：把 summaryBody 的直接 Text 渲染切到同一个 markdown 渲染组件。
5. 把 summaryContentBody 对应的字体、行高、颜色映射集中收口到新的 markdown 组件里，避免两张卡片各写一套样式。
6. 保持 video_summary_presentation_models.dart 和 video_summary_result_mapper.dart 继续传递原始字符串，不新增“解析后富文本”字段，也不把 markdown 解析逻辑塞进 mapper。
7. 补 widget 级测试，覆盖“初稿编辑态仍显示 markdown 原文”“初稿非编辑态能渲染 markdown”“最终稿能渲染基础 markdown 语法”。

**Relevant files**
- pubspec.yaml：添加依赖。
- video_summary_draft_stage_workspace.dart：初稿卡片改造点。
- video_summary_final_chat_widgets.dart：最终稿卡片改造点。
- video_summary_presentation_models.dart：确认模型继续只存原始文本。
- video_summary_result_mapper.dart：确认 mapper 只透传字符串。
- widget_test.dart：复用现有 app 级 widget 装配方式补渲染断言。
- video_summary_result_mapper_test.dart：作为分层边界回归参考，通常无需因 markdown 改动而扩展解析测试。

**Verification**
1. 运行 flutter pub get。
2. 运行 flutter analyze。
3. 新增或更新 widget tests，至少覆盖初稿编辑态、初稿预览态、最终稿展示态三类场景。
4. 手动走一遍 HomeScreen 流程，确认 markdown 内容不会把卡片高度、滚动和按钮布局撑坏。

**Decisions**
- 已按“只改展示层”对齐，不做所见即所得编辑器。
- markdown 解析能力只放在 widgets 层，不下沉到 repository / domain / application。
- 本次范围只覆盖“初稿正文”和“最终稿”两张卡片，不扩到聊天消息气泡。

如果您认可这份方案，下一步就可以直接按这个计划进入实现。