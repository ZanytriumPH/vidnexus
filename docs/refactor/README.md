# VidNexus 项目优化重构 README

## 1. 文档目的

这份文档用于在**不推翻现有原型成果**的前提下，逐步把当前项目从“可运行的高保真原型”重构为“可持续维护、可继续扩展、可接入真实接口”的 Flutter 应用。

当前项目的主要问题不是 UI 基础差，而是：

- 业务逻辑逐步堆积到页面层，开始出现状态爆炸。
- 展示组件和状态编排耦合过深，参数透传严重。
- 页面交互越来越复杂后，单文件和单组件体量失控。
- 当前还能靠人工维护，但继续叠加功能后维护成本会快速上升。

因此，本次重构目标不是“重写”，而是：

1. 控制复杂度继续上升。
2. 让后续接真实 API 时不需要再翻修 UI 层。
3. 保留已经做好的交互和视觉成果。
4. 将重构拆成多个低风险阶段执行。

## 2. 对当前重构方案的评估

你提出的总体方向是正确的，尤其是下面几点判断是准确的：

### 2.1 正确判断

- `HomeScreen` 确实承担了过多状态与业务逻辑。
- `VideoSummaryWorkspace` 的参数规模已经进入典型的 prop drilling 区域。
- `TimestampSection` 内联 BottomSheet 确实应该拆出去。
- 继续依赖 `StatefulWidget + setState` 管理主业务流，会让后续真实接口接入变得困难。
- 按 stage 拆分 workspace，是当前 UI 层最自然的解耦方式。

### 2.2 需要修正或补强的地方

你的方案本身没问题，但如果直接照原文一步到位执行，还可以再优化以下几点：

#### A. 状态管理建议优先选 Riverpod，而不是继续扩展 ChangeNotifier

你给的 ViewModel 示例是 `ChangeNotifier` 风格，这能工作，但从当前项目复杂度看，更推荐：

- `flutter_riverpod`
- `Notifier` / `AsyncNotifier`

原因：

- 当前页面已经有多个互相联动的状态切片，不再只是“一个表单 + 一个列表”。
- Riverpod 更适合拆 provider、按需监听、减少整页重建。
- 后续接真实 API、流式状态、会话历史、知识库多页面共享状态时会更稳。

结论：

- 如果目标只是快速止血，`Provider + ChangeNotifier` 可以做。
- 如果目标是继续做成长期维护项目，建议直接用 Riverpod，避免后面再迁移一次。

#### B. 不要只做一个巨型 HomeViewModel，要进一步切状态域

如果只是把 `HomeScreen` 里的 17 个状态变量平移到一个 `HomeViewModel` 里，问题会缓解，但不会真正消失。

更合理的做法是把状态分成几个领域：

- `VideoSummarySessionState`
- `VideoSummaryDraftState`
- `VideoSummaryFinalChatState`
- `VideoSummaryUiState`
- `VideoSummarySettingsState`

至少要把“会话历史快照”“处理中流程”“草稿编辑”“最终稿追问”分开，不要未来又变成一个新的上帝 ViewModel。

#### C. 路由统一化是合理的，但优先级没有状态拆分高

你提出用 `go_router` 是对的，但从当前项目现状看，它不应排在最前面。

原因：

- 当前真正难维护的不是页面跳转，而是页面内部状态和交互耦合。
- 当前路由数量不算多，复杂度主要在单页内部，而不是跨页导航。

建议优先级：

1. 先拆状态和组件。
2. 再抽复杂弹层。
3. 再决定是否接入 `go_router`。

#### D. 需要补一个“领域模型收敛”层，不只是工具类拆分

你提到抽 `time_utils.dart` 和 mock data，这个方向没问题，但还不够。

当前更关键的是把“业务状态快照”和“UI 展示模型”拆开：

- `DraftResult`、`FinalSummaryData` 这类是领域结果。
- `ProcessingSnapshot` 目前已经混进很多 UI 文案。
- `_SessionHistoryEntrySnapshot` 这类页面快照更偏应用层状态，不应与 UI 紧耦合。

建议新增一层：

- `features/home/domain/`
- `features/home/application/`

让 repository 返回尽量稳定的领域数据，而不是直接返回大量贴着界面文案的对象。

## 3. 结合当前代码的进一步诊断

以下判断基于当前仓库代码，而不是泛泛而谈。

### 3.1 HomeScreen 的问题确实是“业务编排器 + 页面 + 状态容器”三合一

当前位置：

- [lib/features/home/home_screen.dart](../../../lib/features/home/home_screen.dart)

当前文件同时负责：

- 一级页面结构
- 抽屉与手势控制
- 会话历史快照创建与恢复
- 草稿生成流程编排
- 最终稿生成流程编排
- 聊天发送
- 设置弹窗
- 默认行为设置
- 时间区间默认值计算

这说明 `HomeScreen` 不是单纯 View，而是已经承担了应用服务层职责。

### 3.2 VideoSummaryWorkspace 已经是典型的大型 stage 分发组件

当前位置：

- [lib/features/home/widgets/video_summary_content_widgets.dart](../../../lib/features/home/widgets/video_summary_content_widgets.dart)

问题不是它用了 `if (stage == ...)`，而是：

- 仍然接了大量跨 stage 的参数。
- ready / processing / draft / finalChat 的依赖完全不同，却被塞进一个构造函数。
- parent 必须了解每个阶段所需的全部状态。

这已经具备“拆成四个 stage workspace”的全部条件。

### 3.3 时间区间弹窗确实应该从 TimestampSection 中抽离

当前位置：

- [lib/features/home/widgets/video_summary_content_widgets.dart](../../../lib/features/home/widgets/video_summary_content_widgets.dart)

当前 `TimestampSection` 里直接包含：

- 区间文案展示
- 交互入口
- `showModalBottomSheet`
- `RangeSlider` 逻辑
- 区间合法性处理
- 时间格式化

这是一个标准的“应该独立成组件/弹层文件”的案例。

### 3.4 你的诊断有一个细节需要更正

`HomeScreen` 里也有 BottomSheet，但它不是时间区间选择器，而是“会话设置”面板。

当前位置：

- [lib/features/home/home_screen.dart](../../../lib/features/home/home_screen.dart)

所以更准确的表述应该是：

- `TimestampSection` 的时间区间选择器应抽离。
- `HomeScreen` 的设置面板也应抽离。

换句话说，不是只有一个复杂弹层，而是**至少两个复杂弹层都应该独立文件化**。

### 3.5 Repository seam 是好的，但 FakeRepository 里仍然混有展示层文案

当前位置：

- [lib/features/home/fake_video_summary_repository.dart](../../../lib/features/home/fake_video_summary_repository.dart)

当前 repository seam 已经建立，这是项目里一个重要优点。

但现状问题是：

- `ProcessingSnapshot` 包含了大量直接服务 UI 的状态文案。
- 这些内容未来如果接真实接口，容易让 repository 和 UI 绑定过深。

建议未来把它进一步收敛成：

- 原始流程状态 / 原始分段进度
- 展示文案映射器（mapper）

## 4. 最终建议版本：推荐采用的重构方向

基于当前代码实际情况，推荐采用下面这版升级后的方案。

### 4.1 状态管理

推荐：`flutter_riverpod`

落地原则：

- 不做一个超大 provider。
- 按会话、流程、草稿、最终稿、设置拆 provider。
- 控制器只处理状态转换与副作用，不直接关心 Widget 结构。

### 4.2 UI 组件拆分

推荐目录结构：

```text
lib/
  features/
    home/
      presentation/
        screens/
          home_screen.dart
        widgets/
          ready/
            ready_stage_workspace.dart
            ready_upload_card.dart
            ready_preference_card.dart
          processing/
            processing_stage_workspace.dart
            processing_detail_card.dart
          draft/
            draft_stage_workspace.dart
            draft_body_card.dart
          final_chat/
            final_chat_stage_workspace.dart
            timestamp_section.dart
            summary_chat_bubble.dart
      application/
        video_summary_controller.dart
        session_history_controller.dart
      domain/
        models/
        services/
      infrastructure/
        fake_video_summary_repository.dart
```

### 4.3 弹层与复杂交互组件拆分

至少拆出以下文件：

- `timestamp_interval_picker_sheet.dart`
- `session_settings_sheet.dart`

如果继续增长，还可以继续拆：

- `history_drawer.dart`
- `session_restore_dialog.dart`

### 4.4 路由策略

建议：

- 本轮重构先不强制切 `go_router`
- 先建立统一的导航封装层
- 等状态层稳定后，再统一迁移到 `go_router`

这样风险更低。

### 4.5 文本控制器策略

当前 `TextEditingController` 全放在 `HomeScreen` 中。

后续建议：

- 草稿正文编辑 controller 仍可短期保留在页面层。
- 但聊天输入、偏好输入、草稿内容等核心文本状态要同步到 controller 对应的状态层。

不要让 controller 成为业务状态唯一真相源。

## 5. 分阶段重构路线图

下面这条路线图适合当前项目，不会一下子把已有 UI 打碎。

### Phase 1: 无痛抽离

目标：不改架构，只拆大文件。

任务：

- 抽 `timestamp_interval_picker_sheet.dart`
- 抽 `session_settings_sheet.dart`
- 抽 HomeScreen 中重复构造的 `VideoSummaryWorkspace` 参数打包方法
- 把 `video_summary_content_widgets.dart` 中体量大的私有组件拆文件

收益：

- 文件长度立即下降
- 后续切状态管理前更容易迁移

### Phase 2: 按 stage 拆 workspace

目标：消除 `VideoSummaryWorkspace` 大量跨阶段参数。

任务：

- 新建 `ReadyStageWorkspace`
- 新建 `ProcessingStageWorkspace`
- 新建 `DraftStageWorkspace`
- 新建 `FinalChatStageWorkspace`
- 让总入口只负责 stage 分发

收益：

- UI 结构变清晰
- 每个阶段只关心自己的状态与回调

### Phase 3: 引入状态管理

目标：把 `HomeScreen` 从“状态容器”降级为“页面壳”。

任务：

- 接入 Riverpod
- 建立 `video_summary_controller.dart`
- 把 `_startDraftGeneration()`、`_generateFinalSummary()`、`_sendChatMessage()` 等迁移出去
- 把会话快照同步逻辑抽到独立 controller/service

收益：

- 消除大部分 prop drilling
- UI 不再承担业务编排责任

### Phase 4: 领域收敛与基础设施清理

目标：让数据层和 UI 层边界稳定。

任务：

- 抽离时间格式化工具
- 抽离 knowledge base mock data
- 清理 repository 返回对象中的展示层文案
- 为 processing / draft / final result 建立更稳定的数据模型

收益：

- 为真实 API 接入做准备
- 后续不会因为 UI 文案变化而频繁改 repository

### Phase 5: 路由统一化

目标：统一页面跳转方式。

任务：

- 建立 app router
- 再决定是否引入 `go_router`
- 统一知识库内部页面和首页跳转入口

## 6. 建议的优先级排序

如果只选最重要的三件事，优先级建议如下：

1. 先拆 `VideoSummaryWorkspace`
2. 再抽弹层组件
3. 再引入 Riverpod 做状态迁移

而不是先改路由。

## 7. 重构执行原则

为了避免把现有项目“重构死”，执行时必须遵守：

- 一次只做一个阶段，不跨阶段并行大改。
- 每完成一个阶段都跑 `flutter analyze`。
- 每完成一个阶段都人工回归四个 stage：ready / processing / draft / finalChat。
- 不在同一轮里同时大改 UI 和状态管理。
- 优先保留现有视觉与交互结果，先迁移结构，再做样式微调。

## 8. 当前结论

总结如下：

- 你的重构方向整体是对的。
- 最大的问题不是判断错，而是还可以进一步分层和调整优先级。
- 当前项目最适合的路线不是“一步到位全量重写”，而是“拆文件 -> 拆 stage -> 拆状态 -> 再统一路由”。
- 当前最值得先做的事情，是把 `VideoSummaryWorkspace` 和两个 BottomSheet 独立出去，然后再把 `HomeScreen` 的业务逻辑迁到状态层。

这份文档会作为后续项目重构的基准说明。后面真正开始重构时，应严格按这里的阶段顺序推进。