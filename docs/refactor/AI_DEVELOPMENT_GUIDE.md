# VidNexus AI 开发指南

## 1. 文档目的

本文档面向后续继续参与本仓库开发的 AI 助手。

目标不是解释“概念上什么是分层”，而是提供一份可执行的工程约束说明，让 AI 在继续改代码时：

- 能快速理解当前重构后的架构边界
- 知道新增代码应该落在哪里
- 知道哪些写法会破坏当前重构成果
- 知道在什么情况下应该继续沿用当前模式，而不是自行升级到另一种架构

本文档默认 AI 已具备 Dart、Flutter、Riverpod 的基础能力，但不假设 AI 已了解本仓库的历史重构过程。

## 2. 当前项目所处阶段

当前仓库已经完成的重构主线：

- Phase 3：将 `HomeScreen` 从上帝页面收敛为页面壳与装配入口
- Phase 4：建立 domain data / presentation model 分层，并让 repository 只返回稳定数据
- Phase 5：建立当前自定义路由层，完成命名路由、typed arguments、统一导航入口、显式路由错误处理

当前判断：

- Phase 3 已完成
- Phase 4 已完成
- Phase 5 已达到可停点

当前默认策略：

- 继续沿用 `AppRoutes + AppRouteArguments + AppRouter + AppNavigator`
- 当前不主动引入 `go_router`
- 继续维护现有 application / domain / widgets 边界

## 3. AI 必须先建立的整体认知

AI 在修改本项目时，必须先把代码按以下几类理解，而不是把整个 `features/home` 看成一个平面目录。

### 3.1 页面壳与视图层

主要位置：

- [lib/features/home/home_screen.dart](lib/features/home/home_screen.dart)
- [lib/features/home/widgets](lib/features/home/widgets)
- [lib/features/knowledge_base](lib/features/knowledge_base)

职责：

- 页面结构装配
- 组件展示
- 用户交互回调发起

约束：

- 视图层不应直接承担 repository 调用
- 视图层不应直接产出 presentation model
- 视图层不应重新内联复杂弹层和重复的导航细节

### 3.2 应用编排层

主要位置：

- [lib/features/home/application](lib/features/home/application)

职责：

- 管理状态切片
- 编排主流程
- 协调 session、text editing、settings
- 连接 repository 与 presentation

约束：

- application 层可以决定状态如何迁移
- application 层不应承担具体布局与视觉结构

### 3.3 领域数据层

主要位置：

- [lib/features/home/domain](lib/features/home/domain)

职责：

- 表达稳定业务结果数据
- 承担跨 controller / repository 共享的业务规则工具

约束：

- domain 模型必须避免混入页面级展示文案
- domain 工具不应依赖 widget 层

### 3.4 路由层

主要位置：

- [lib/app/routing](lib/app/routing)

职责：

- 路由常量
- 参数化入参类型
- 路由分发
- 统一导航 helper
- 路由错误显式处理

约束：

- 新导航规则优先收口到这一层
- 页面侧不应重新散写 `Navigator.push` 作为常规入口

## 4. 关键架构规则

以下规则是强约束，不是建议。

### 4.1 repository 只能返回 domain/raw data

允许：

- `VideoSummaryProcessingData`
- `VideoSummaryDraftData`
- `VideoSummaryFinalResultData`
- `VideoSummaryChatReplyData`

不允许：

- `ProcessingSnapshot`
- `DraftResult`
- `FinalSummaryData`
- `ChatMessage`

原因：

- 这些 UI-facing 模型属于 presentation 层，必须由 mapper 产出。

### 4.2 presentation model 只能由 mapper 产出

主要文件：

- [lib/features/home/application/video_summary_result_mapper.dart](lib/features/home/application/video_summary_result_mapper.dart)

约束：

- 新增 UI 结果字段时，优先改 mapper 与 presentation model
- 不要为了某个标签或文案直接修改 repository 返回结构

### 4.3 页面壳只做装配与触发

主要文件：

- [lib/features/home/home_screen.dart](lib/features/home/home_screen.dart)

允许：

- watch provider
- read notifier
- 组装 widgets
- 触发 controller 回调

不鼓励：

- 新增复杂业务推导
- 新增成组的格式化逻辑
- 直接处理流程型状态迁移

### 4.4 TextEditingController 统一管理

主要文件：

- [lib/features/home/application/video_summary_text_editing_controller.dart](lib/features/home/application/video_summary_text_editing_controller.dart)

约束：

- 如果新增输入框属于视频总结主流程，优先放入该控制器统一管理
- 不要在页面或 stage workspace 内随意创建平行 text controller

### 4.5 路由错误必须显式暴露

主要文件：

- [lib/app/routing/app_router.dart](lib/app/routing/app_router.dart)
- [lib/app/routing/app_route_error_screen.dart](lib/app/routing/app_route_error_screen.dart)

约束：

- 未知路由不要静默跳回首页
- 参数错误不要 silent fallback

## 5. 当前关键文件职责图

## 5.1 app 层

### [lib/app/app.dart](lib/app/app.dart)

职责：

- 配置 `MaterialApp`
- 连接 `AppRouter.onGenerateRoute`
- 连接 `AppRouter.onUnknownRoute`

AI 修改原则：

- 不要把 feature 逻辑塞回这里
- 不要新增局部业务判断型路由分支

### [lib/app/routing/app_routes.dart](lib/app/routing/app_routes.dart)

职责：

- 统一管理全局路由名

AI 修改原则：

- 新页面先加路由常量，再继续下一步
- 不要把路由常量重新分散回页面类

### [lib/app/routing/app_route_arguments.dart](lib/app/routing/app_route_arguments.dart)

职责：

- 定义参数化页面的 typed arguments

AI 修改原则：

- 新参数化页面优先新增 arguments 类
- 不要在 `AppNavigator` 和页面调用点之间散传多个裸参数

### [lib/app/routing/app_router.dart](lib/app/routing/app_router.dart)

职责：

- 路由分发
- 参数检查
- 导航 helper

AI 修改原则：

- 页面导航能力优先加到 `AppNavigator`
- 不要把业务规则塞到 `AppNavigator`
- 当前阶段不要自行替换为 `go_router`

## 5.2 home 模块

### [lib/features/home/home_screen.dart](lib/features/home/home_screen.dart)

职责：

- 页面壳
- 监听 provider
- 装配 drawer、header、workspace
- 在少量入口处协调 controller

AI 修改原则：

- 若需求属于“流程推进”，优先找 controller
- 若需求属于“显示结构”，优先找 widgets
- 若需求属于“时间/文案/映射”，优先找 mapper 或 utils

### [lib/features/home/video_summary_repository.dart](lib/features/home/video_summary_repository.dart)

职责：

- 定义数据源 contract

AI 修改原则：

- 接真实 API 时，优先保持 contract 稳定
- 若确需扩展字段，优先从 domain model 角度扩展，不要先从 UI model 角度扩展

### [lib/features/home/fake_video_summary_repository.dart](lib/features/home/fake_video_summary_repository.dart)

职责：

- 当前 fake 数据实现

AI 修改原则：

- 可以调整 mock 数据与节奏模拟
- 不要让 fake repository 直接返回 presentation model

### [lib/features/home/video_summary_models.dart](lib/features/home/video_summary_models.dart)

职责：

- 中性基础共享模型

AI 修改原则：

- 只放跨层共享且稳定的基础模型
- 不要把 UI 结构模型加回这里

### [lib/features/home/video_summary_presentation_models.dart](lib/features/home/video_summary_presentation_models.dart)

职责：

- UI-facing 结果模型

AI 修改原则：

- 该文件只服务 presentation 层
- 若新字段只为 UI 服务，应优先加在这里而不是 domain model

## 5.3 application 层

### [lib/features/home/application/video_summary_flow_controller.dart](lib/features/home/application/video_summary_flow_controller.dart)

职责：

- 主流程状态机
- processing / draft / final chat 状态推进
- 时间范围控制
- chat 发送与 summary 生成

AI 修改原则：

- 新增流程分支前，先判断是否属于现有 flow controller 的自然职责
- 避免把临时 UI 行为揉进 flow state

### [lib/features/home/application/video_summary_session_history_controller.dart](lib/features/home/application/video_summary_session_history_controller.dart)

职责：

- session 列表与 active session
- snapshot 管理
- seeded session 生成

AI 修改原则：

- seeded 数据仍须走正式映射链路
- 不要把 demo 数据当成可以随意绕边界的临时代码

### [lib/features/home/application/video_summary_text_editing_controller.dart](lib/features/home/application/video_summary_text_editing_controller.dart)

职责：

- 统一文本控制器
- 文本快照同步
- draft 结果注入

AI 修改原则：

- 新增可编辑文本域时，先看是否应该纳入此控制器

### [lib/features/home/application/video_summary_settings_controller.dart](lib/features/home/application/video_summary_settings_controller.dart)

职责：

- 默认设置状态

AI 修改原则：

- 保持轻量，不要将流程状态塞入 settings

### [lib/features/home/application/video_summary_result_mapper.dart](lib/features/home/application/video_summary_result_mapper.dart)

职责：

- domain/raw data 到 UI model 的转换

AI 修改原则：

- UI 文案、badge 文案、阶段标签、展示组合优先在这里处理

## 5.4 domain 层

### [lib/features/home/domain/video_summary_domain_models.dart](lib/features/home/domain/video_summary_domain_models.dart)

职责：

- 稳定业务结果模型

AI 修改原则：

- 字段扩展前先判断它是否代表稳定业务含义

### [lib/features/home/domain/video_summary_time_utils.dart](lib/features/home/domain/video_summary_time_utils.dart)

职责：

- 时间解析与格式化工具

AI 修改原则：

- 时间格式化逻辑不要分散写回 controller 或 widget

## 5.5 widgets 层

### [lib/features/home/widgets/video_summary_content_widgets.dart](lib/features/home/widgets/video_summary_content_widgets.dart)

职责：

- 按 stage 分发 UI 工作区

AI 修改原则：

- 保持其为 stage 分发器，不要回退成业务编排器

### Stage workspaces

主要文件：

- [lib/features/home/widgets/video_summary_ready_stage_workspace.dart](lib/features/home/widgets/video_summary_ready_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_processing_stage_workspace.dart](lib/features/home/widgets/video_summary_processing_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_draft_stage_workspace.dart](lib/features/home/widgets/video_summary_draft_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart](lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart)

AI 修改原则：

- 每个 stage 文件只关心该阶段的 UI 结构与必要交互
- 如 final chat 再次膨胀，优先继续拆组件

### 其他 widgets

主要文件：

- [lib/features/home/widgets/timestamp_interval_picker_sheet.dart](lib/features/home/widgets/timestamp_interval_picker_sheet.dart)
- [lib/features/home/widgets/session_settings_sheet.dart](lib/features/home/widgets/session_settings_sheet.dart)
- [lib/features/home/widgets/video_summary_drawer_widgets.dart](lib/features/home/widgets/video_summary_drawer_widgets.dart)
- [lib/features/home/widgets/video_summary_final_chat_widgets.dart](lib/features/home/widgets/video_summary_final_chat_widgets.dart)

AI 修改原则：

- 独立弹层与复杂局部组件继续保持文件级拆分

## 6. AI 接任务时的决策规则

AI 在接到需求后，可以按下面流程快速判断应改哪里。

### 6.1 如果需求是“改页面样式”

优先改：

- 对应 stage workspace
- 对应 widgets 文件

不要先改：

- controller
- repository

### 6.2 如果需求是“改流程状态或阶段行为”

优先改：

- `video_summary_flow_controller.dart`
- `video_summary_session_history_controller.dart`
- `video_summary_text_editing_controller.dart`

必要时联动：

- `video_summary_result_mapper.dart`
- domain models

### 6.3 如果需求是“改假数据或接接口”

优先改：

- `video_summary_repository.dart`
- `fake_video_summary_repository.dart`

如需扩展结构，再改：

- domain models
- mapper

### 6.4 如果需求是“新增知识库页面或页面跳转”

优先改：

1. `app_routes.dart`
2. `app_route_arguments.dart`
3. `app_router.dart`
4. 页面调用点

### 6.5 如果需求是“增加新的输入框、编辑区或恢复态”

优先改：

- `video_summary_text_editing_controller.dart`
- `video_summary_session_history_controller.dart`

不要只在页面侧临时加 controller。

## 7. AI 绝对不要做的事

1. 不要把 repository 返回值改回 UI-facing model。
2. 不要把复杂流程状态重新塞回 `HomeScreen`。
3. 不要在 feature 页面里重新铺开零散的 `Navigator.push` 和 `MaterialPageRoute`。
4. 不要把时间工具逻辑分散拷贝到多个 widget。
5. 不要把 seeded/demo 数据写成绕过 mapper 的特殊分支。
6. 当前阶段不要自行发起 `go_router` 迁移，除非用户明确要求。

## 8. AI 推荐工作方式

### 8.1 修改前先判断“这是什么问题”

先把需求归类为以下之一：

- 视觉层问题
- 状态流问题
- 数据边界问题
- 路由问题
- 文本编辑与会话同步问题

归类之后再选文件，不要上来直接从页面文件开改。

### 8.2 优先做最小闭环修改

推荐顺序：

1. 找到控制路径
2. 做最小变更
3. 先跑局部验证
4. 再决定是否继续扩展

### 8.3 对文案和模型要分开思考

如果变化只是：

- 展示标题
- badge 标签
- eta 文案
- button 文案

通常优先改 mapper 或 widget，而不是 domain model 或 repository。

### 8.4 对新功能要先判断是否需要新层

只有在现有文件职责明显不适合时，才新增 controller 或新增模型层。

不要因为一个小需求就立刻新建一套并列结构。

## 9. 当前后续开发优先级建议

如果 AI 继续参与这个项目，推荐优先级如下：

1. 继续拆分 final chat 区块，防止该阶段再次膨胀
2. 如果知识库进入真实开发，为知识库建立自己的 application / domain 分层
3. 继续补充路由层能力，但保持当前自定义方案
4. 仅在用户明确要求或场景明确需要时，再评估 `go_router`

## 10. AI 的一句话工作原则

在这个仓库里，AI 的默认目标不是“把代码写得更炫”，而是“守住已经建立的边界，让新需求落到正确层次里”。