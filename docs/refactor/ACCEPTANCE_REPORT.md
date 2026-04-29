# VidNexus 重构验收报告

## 1. 文档目的

本文档用于对当前已完成的重构工作进行阶段性验收，确认以下内容已经成立：

- 当前项目是否已经从“单页集中承载状态与编排”的原型形态，演进到“具备持续维护基础”的工程形态。
- 已完成重构后的架构边界是否清晰。
- 关键文件与目录的职责是否已经收口。
- 后续继续开发时，团队应遵守哪些约束，才能避免重新退回到重构前的耦合状态。

本文档描述的是“当前仓库已经落地并通过验证”的状态，不是理想化目标图。

## 2. 验收结论

截至当前版本，本轮重构已经完成以下阶段性目标：

### 2.1 已完成项

- 完成首页主业务状态的 Riverpod 化切分，不再依赖单页面内大量本地状态变量硬编排。
- 完成视频总结主流程控制器拆分，形成 flow / session history / settings / text editing 多控制器结构。
- 完成时间区间工具与时间区间弹层拆分，减少业务页面与格式化逻辑耦合。
- 完成会话设置弹层拆分，首页主文件不再承载复杂弹层实现细节。
- 完成 processing / draft / final result 的 domain data 与 presentation model 分层。
- 完成 repository 返回 raw/domain data，presentation model 统一由 mapper 产出。
- 完成 seeded session 数据与真实 repository 数据共用一条映射链路。
- 完成知识库主导航与首页切换入口的统一收口。
- 完成当前自定义路由层的第一阶段建设：命名路由、typed arguments、统一导航入口、显式路由错误处理。

### 2.2 当前可确认的阶段性收益

- `HomeScreen` 已明显收敛为页面壳与事件协调入口，而不再承担全部细节状态实现。
- repository 层与 UI 文案层已经建立明确边界，后续接真实接口时不需要直接改 UI 模型定义。
- 知识库页面跳转已经不再依赖零散的 `Navigator` 写法，跨页入口有统一位置可维护。
- 会话恢复、草稿生成、最终稿生成、追问发送、文本编辑同步已经具备清晰控制路径。

### 2.3 阶段判断

- Phase 3：可视为完成。
- Phase 4：可视为完成。
- Phase 5：已达到“可停点”。当前不必立即切 `go_router`。

“可停点”的判定标准如下：

- 主要跨页面导航已统一经过 `AppRoutes`、`AppRouter`、`AppNavigator`。
- 参数化页面已统一走 typed arguments。
- 未知路由与错误参数已经有显式处理，而不是静默 fallback。

## 3. 当前架构设计总览

## 3.1 顶层结构

当前项目已形成如下几层结构：

```text
lib/
  app/
    app.dart
    routing/
    theme/
    widgets/
  features/
    home/
      application/
      domain/
      widgets/
      home_screen.dart
      fake_video_summary_repository.dart
      video_summary_models.dart
      video_summary_presentation_models.dart
      video_summary_repository.dart
    knowledge_base/
      ...
```

其核心思想不是“完全 DDD 化”或“完全按 presentation/application/domain/infrastructure 四层重写”，而是先把最容易失控的部分抽出来，建立能够继续演进的边界。

## 3.2 当前分层职责

### A. app 层

职责：

- 应用级入口
- 全局主题
- 路由注册与跨 feature 导航规则

当前结论：

- `app` 层已成为跨 feature 的公共承载层。
- 路由不再散落到各页面内部自行定义。

### B. features/home/application 层

职责：

- 状态切片管理
- 主流程编排
- 会话快照同步
- 文本输入控制
- domain data 到 presentation model 的映射

当前结论：

- 这是本轮重构最关键的增量层。
- 它把原来堆在页面中的状态切换、副作用、快照恢复逻辑吸走了。

### C. features/home/domain 层

职责：

- 稳定的业务结果模型
- 时间处理工具

当前结论：

- domain 层已经承担“repository 可稳定返回什么”的定义。
- repository 不再直接输出 UI 结构对象。

### D. features/home/widgets 层

职责：

- 按 stage 组织展示组件
- 承接 presentation model 与用户交互回调
- 封装复杂弹层与拆分后的阶段工作区

当前结论：

- widget 层已明显比重构前更接近“纯视图层”。
- 但它仍有继续细拆空间，尤其是 final chat 区块。

### E. repository seam

职责：

- 抽象视频总结数据来源
- 当前使用 fake repository 提供模拟数据

当前结论：

- seam 已建立，后续替换真实接口时有明确接入点。
- 当前 fake repository 已从“直接返回 UI 模型”改为“返回 domain/raw data”。

## 4. 核心数据流与控制流

## 4.1 视频总结主流程

当前主流程如下：

1. `HomeScreen` 负责装配页面壳、监听 provider、绑定交互回调。
2. 用户点击“开始生成”后，进入 `VideoSummaryFlowController.startDraftGeneration()`。
3. controller 从 repository 获取 processing raw data。
4. raw data 经过 `video_summary_result_mapper.dart` 转成 UI 使用的 `ProcessingSnapshot`。
5. processing 完成后，controller 再从 repository 获取 draft raw data，并映射为 `DraftResult`。
6. 用户编辑草稿并生成最终稿后，controller 调用 repository 生成 `VideoSummaryFinalResultData`。
7. raw final result 经过 mapper 转成 `FinalSummaryData`，并驱动 final chat 阶段 UI。

该链路说明：

- repository 只负责“给数据”。
- controller 负责“何时取数据、如何推进状态”。
- mapper 负责“如何把稳定数据转成 UI 结构”。
- widget 负责“如何展示与触发回调”。

## 4.2 文本编辑与会话同步链路

当前文本链路如下：

1. `VideoSummaryTextEditingController` 持有 `preferenceController`、`chatController`、`draftBodyController`。
2. 文本变化时，会触发 active session 的快照同步。
3. 当 flow state 从“无草稿”进入“有草稿”时，draft 文本框会自动写入生成结果。
4. 当用户恢复会话时，文本状态与 flow snapshot 一起恢复。

该链路说明：

- 文本编辑已不再是 `HomeScreen` 自己维护。
- 文本控制与业务状态快照已经统一纳入 session 同步机制。

## 4.3 知识库路由链路

当前路由链路如下：

1. `VidNexusApp` 在 `MaterialApp` 上注册 `onGenerateRoute` 和 `onUnknownRoute`。
2. `AppRoutes` 统一声明路由名。
3. `AppRouteArguments` 统一声明参数化页面入参对象。
4. `AppRouter` 负责路由分发与参数校验。
5. `AppNavigator` 提供页面层直接调用的统一导航 helper。

该链路说明：

- 页面侧不再直接决定 `MaterialPageRoute` 细节。
- 参数化页面不再散传多个参数，而是通过 typed arguments 显式进入路由层。

## 5. 当前项目架构文件定位

以下内容只覆盖本轮重构涉及的关键文件，而不是全仓库逐文件说明。

## 5.1 app 层

### `lib/app/app.dart`

定位：应用入口与 `MaterialApp` 配置文件。

职责：

- 注入主题
- 指定 `initialRoute`
- 接入 `AppRouter.onGenerateRoute`
- 接入 `AppRouter.onUnknownRoute`

注意事项：

- 不要在这里重新塞回 feature 级业务判断。
- 不要在这里直接注册分散的匿名路由表，统一走 `AppRouter`。

### `lib/app/routing/app_routes.dart`

定位：全局路由名常量收口文件。

职责：

- 定义 `home`
- 定义知识库首页与参数化页面路由名

注意事项：

- 新增页面路由时，优先先改这里，再改 router。
- 不要再把 `routeName` 常量写回页面类内部。

### `lib/app/routing/app_route_arguments.dart`

定位：参数化路由入参模型文件。

职责：

- 描述知识库页面路由需要哪些参数
- 让参数化跳转具有显式类型边界

注意事项：

- 这里的对象是“路由参数对象”，不是业务状态对象。
- 若参数很多，优先新建 arguments 类，不要把多段原始参数重新散传到页面侧。

### `lib/app/routing/app_router.dart`

定位：应用路由分发中心与统一导航入口。

职责：

- 根据 `RouteSettings` 分发页面
- 校验参数类型
- 统一处理未知路由与参数错误
- 提供 `AppNavigator` 作为页面层调用入口

注意事项：

- 不要在 feature 页面重新写 `MaterialPageRoute` 作为常规跳转方案。
- 路由错误应继续显式化，不要恢复 silent fallback。
- `AppNavigator` 应保持“薄封装”，只做导航语义收口，不承载业务逻辑。

### `lib/app/routing/app_route_error_screen.dart`

定位：路由异常展示页面。

职责：

- 用于展示未注册路由或错误 arguments

注意事项：

- 它是调试与防错边界，不是业务页面。

## 5.2 视频总结 feature 的核心文件

### `lib/features/home/home_screen.dart`

定位：首页页面壳与主装配入口。

职责：

- 观察 `flow`、`session history`、`text editing` provider
- 装配抽屉、header、workspace
- 绑定导航与弹层入口
- 在少量事件点协调多个 controller

当前状态判断：

- 已从“上帝页面”下降为“页面壳 + 协调器”。
- 仍然存在装配型代码，但这是当前阶段可接受状态。

注意事项：

- 不要把 repository 调用、时间处理、映射逻辑重新塞回这里。
- 新的跨状态行为应优先落到 controller，而不是继续扩写页面方法。

### `lib/features/home/video_summary_repository.dart`

定位：视频总结数据源抽象与 provider 定义。

职责：

- 定义 repository contract
- 暴露 provider 供 controller 使用

注意事项：

- repository 返回值只能是 domain/raw data。
- repository 不应该返回 `ProcessingSnapshot`、`DraftResult`、`FinalSummaryData` 这类 presentation model。

### `lib/features/home/fake_video_summary_repository.dart`

定位：当前的视频总结假数据实现。

职责：

- 提供视频资源、处理中流、草稿结果、最终稿结果、追问回复的 mock 数据

注意事项：

- 可以继续替换文案或模拟行为，但不要绕开 domain model 边界。
- 未来接真实 API 时，应以此 contract 为目标替换，不应把页面直接接到接口层。

### `lib/features/home/video_summary_models.dart`

定位：feature 级基础共享模型。

职责：

- 提供 `VideoSummaryStage`
- 提供 `VideoAssetInfo`
- 提供 `TimestampRangeSelection`

注意事项：

- 这里只放真正跨层共享且稳定的基础模型。
- 不要再把 presentation 结果模型混回这个文件。

### `lib/features/home/video_summary_presentation_models.dart`

定位：UI 专用展示模型定义。

职责：

- 描述 processing、draft、final chat 等 UI 所需数据结构

注意事项：

- 这些模型属于 presentation 层，不应被 repository 直接返回。
- 若展示结构变化，应优先调整 mapper，而不是污染 domain model。

## 5.3 application 层

### `lib/features/home/application/video_summary_flow_controller.dart`

定位：视频总结主流程控制器。

职责：

- 维护 stage 状态
- 管理 processing / draft / final chat 全流程推进
- 维护时间区间选择状态
- 生成与恢复流程快照
- 驱动聊天发送与最终稿生成

注意事项：

- 这里可以编排流程，但不应承担 UI 文案拼装细节。
- 新增业务阶段时，应优先判断是否属于这个 controller 的职责，避免继续生成新的上帝 controller。

### `lib/features/home/application/video_summary_session_history_controller.dart`

定位：会话历史与会话快照控制器。

职责：

- 维护 session 列表与 active session
- 创建新会话
- 恢复已有会话
- 同步当前活动会话快照
- 提供 seeded sessions 作为示例数据

注意事项：

- seeded 数据也必须走 domain -> mapper 链路，不要在这里直接手工拼 UI model。
- 会话 detail 文案可以是 application 层行为描述，但不要回灌进 repository。

### `lib/features/home/application/video_summary_text_editing_controller.dart`

定位：文本输入控制与可编辑快照同步控制器。

职责：

- 统一持有多个 `TextEditingController`
- 管理草稿生成后文本注入
- 管理聊天输入消费
- 管理 session snapshot 与文本状态同步

注意事项：

- 页面层不要重新创建平行的 text controller。
- 如果未来新增输入区域，优先评估是否应纳入这里统一管理。

### `lib/features/home/application/video_summary_settings_controller.dart`

定位：默认设置控制器。

职责：

- 维护默认时间范围开关
- 维护默认 processing 展开状态

注意事项：

- 它应保持轻量，不要把流程状态塞进 settings。

### `lib/features/home/application/video_summary_result_mapper.dart`

定位：domain data 到 presentation model 的映射器。

职责：

- 将 processing raw data 转成 `ProcessingSnapshot`
- 将 draft raw data 转成 `DraftResult`
- 将 final raw data 转成 `FinalSummaryData`
- 将 chat reply raw data 转成 `ChatMessage`

注意事项：

- 一切“展示层文案”“展示层标签”“UI 结构转换”优先留在这里。
- 若未来 UI 改版，应先评估是否只需要修改 mapper，而不是修改 repository 返回结构。

## 5.4 domain 层

### `lib/features/home/domain/video_summary_domain_models.dart`

定位：视频总结稳定业务结果模型。

职责：

- 描述 processing、draft、final、chat reply 等 raw/domain 结果数据

注意事项：

- 这些模型应尽量贴近稳定业务含义，而不是贴近具体页面样式。
- 新增字段时优先考虑是否属于长期稳定数据，而不是临时展示需求。

### `lib/features/home/domain/video_summary_time_utils.dart`

定位：时间相关解析与格式化工具。

职责：

- 格式化时间标签
- 解析时间范围
- 处理最小时长与默认区间

注意事项：

- 时间标签逻辑不要重新散落到 controller 或 widget 中。

## 5.5 widgets 层

### `lib/features/home/widgets/video_summary_content_widgets.dart`

定位：按 stage 分发 workspace 的入口组件。

职责：

- 根据 `VideoSummaryStage` 分发 ready / processing / draft / final chat 子工作区

注意事项：

- 这是 stage 分发器，不应再演变为新的业务编排中心。
- 若某一 stage 参数继续膨胀，应优先考虑继续细拆 stage widget。

### `lib/features/home/widgets/video_summary_ready_stage_workspace.dart`

定位：ready 阶段展示区。

### `lib/features/home/widgets/video_summary_processing_stage_workspace.dart`

定位：processing 阶段展示区。

### `lib/features/home/widgets/video_summary_draft_stage_workspace.dart`

定位：draft 阶段展示区。

### `lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart`

定位：final chat 阶段展示区。

当前状态判断：

- stage workspace 已完成拆分，方向正确。
- final chat 区块仍是后续最值得继续细拆的位置。

### `lib/features/home/widgets/video_summary_final_chat_widgets.dart`

定位：final chat 阶段的细分子组件集合。

注意事项：

- 若继续扩展追问体验、消息卡片或时间旅行交互，这里应继续承担组件细拆，而不是回流到 `final_chat_stage_workspace` 或 `home_screen.dart`。

### `lib/features/home/widgets/timestamp_interval_picker_sheet.dart`

定位：时间区间选择弹层。

职责：

- 承担时间范围选择 UI 与确认行为

注意事项：

- 不要把 `showModalBottomSheet` 逻辑重新内联回主内容组件。

### `lib/features/home/widgets/session_settings_sheet.dart`

定位：会话设置弹层。

职责：

- 承担默认行为设置 UI

注意事项：

- 继续保持弹层独立，不要把表单与开关实现重新塞回首页。

### `lib/features/home/widgets/video_summary_drawer_widgets.dart`

定位：历史会话抽屉与抽屉项组件。

职责：

- 展示 session list
- 提供创建、恢复、打开设置等入口

## 5.6 知识库页面

### `lib/features/knowledge_base/knowledge_base_home_screen.dart`

定位：知识库首页入口。

职责：

- 展示知识库入口与列表
- 通过 `AppNavigator` 进入知识库 session 页面

### `lib/features/knowledge_base/knowledge_base_session_screen.dart`

定位：知识库单库会话列表页。

### `lib/features/knowledge_base/knowledge_base_chat_screen.dart`

定位：知识库聊天页。

### `lib/features/knowledge_base/knowledge_base_sources_screen.dart`

定位：知识库来源页。

当前状态判断：

- 知识库内部导航已收口到统一路由层。
- 该 feature 目前更像 Phase 5 的路由接入对象，而不是本轮重构的核心业务拆分对象。

## 6. 后续开发注意事项

以下约束是后续开发时必须继续遵守的，否则当前重构收益会被快速冲掉。

### 6.1 关于分层

- repository 只能返回 domain/raw data。
- presentation model 只能由 application 层 mapper 产出。
- widget 层不要直接依赖 fake repository 或未来真实 repository。

### 6.2 关于页面职责

- 页面壳负责装配和触发，不负责承载复杂业务推导。
- 如果一个页面方法开始同时读写多个 provider、拼装文案、处理格式化、决定流程分支，说明应该下沉到 controller 或 mapper。

### 6.3 关于 controller

- controller 负责状态迁移和副作用，不负责具体视觉结构。
- 新增 controller 前，先判断是否只是现有 controller 的自然延伸。
- 避免把 flow、history、text editing、settings 再次合并成新的上帝控制器。

### 6.4 关于 mapper

- 所有面向界面的标题、标签、提示文案、 badge 文案、阶段描述，优先放在 mapper。
- 不要因为 UI 改字就改 repository 返回结构。

### 6.5 关于路由

- 新页面先加 `AppRoutes`，再加 `AppRouteArguments`，再进 `AppRouter`，最后由 `AppNavigator` 暴露调用入口。
- 不要在页面侧恢复零散 `Navigator.push` 或 `MaterialPageRoute`。
- 未知路由与错误参数应保持显式失败，不要静默兜底到首页。

### 6.6 关于 seeded/demo 数据

- 会话历史里的 seeded data 也属于正式架构的一部分，不是可以随意绕边界的临时代码。
- 它们必须继续复用 domain -> mapper -> presentation 的正式链路。

### 6.7 关于 widgets 细拆

- 当前最值得继续拆的区域仍然是 final chat 区块。
- 若聊天区继续增加交互，优先拆组件，不要让 `video_summary_final_chat_stage_workspace.dart` 再度膨胀。

### 6.8 关于真实 API 接入

- 未来接真实接口时，优先替换 repository 实现，不要先改页面。
- 若接口返回结构与当前 domain model 不一致，应先在 repository / adapter 层处理，再进入 application 层。

## 7. 当前遗留与后续建议

当前重构虽已达到阶段验收条件，但仍有以下后续空间：

### 7.1 已知仍可继续优化的点

- final chat 区块仍有继续拆分空间。
- `VideoSummaryWorkspace` 虽然已经只做 stage 分发，但参数数量仍然偏多。
- 知识库 feature 当前更偏静态演示页，后续如进入真实开发，还需要建立自己的 application/domain 边界。

### 7.2 建议的后续优先级

1. 继续处理 final chat 组件细拆。
2. 若知识库要进入真实开发，为知识库建立与 home 同级别的状态与数据边界。
3. 等路由和状态进一步稳定后，再决定是否评估 `go_router`。

## 8. 验收建议

建议将本轮重构作为“阶段验收通过”处理，理由如下：

- 关键复杂度已经从页面层转移到可维护的 application / domain / routing 边界。
- 当前主流程和主要跨页面导航都已有统一入口。
- 后续真实功能接入已经有明确扩展位，而不是只能继续堆页面逻辑。

若后续继续开发，应以“守住当前边界，不回流职责”为第一优先级。