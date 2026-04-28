# VidNexus 开发日志

## 记录时间

- 日期：2026-04-28
- 范围：本轮对话中围绕 视频总结 模块 与 简洁版 1.2 设计稿 的实现整理

## 本次开发目标

根据 pencil/简洁版1.2.pen 与 pencil/简洁版1.2_视频总结后续开发提示词 的约束，继续完成 Flutter 项目中的 视频总结 模块，并遵守以下原则：

- 1.2 processing、1.3 Aggregated Draft、1.4 Final Summary Chat 不是三个独立页面，而是同一工作区页面内的状态流转。
- 不接真实后端 API。
- 使用本地假数据模拟处理进度、草稿结果、最终总结与对话回复。
- UI 需要尽量贴近简洁版 1.2.pen。

## 已完成改动总览

### 1. 将视频总结后半段改为同屏状态流转

原本 开始生成初稿 会跳到 processing 占位路由。现已改为在 HomeScreen 内部通过状态切换完成整个流程：

- ready：初始上传与偏好输入状态。
- processing：处理中状态，保留浅蓝主卡片，并展示进度与处理详情。
- draft：聚合草稿状态，在同一页面展示草稿内容与总结指导输入。
- finalChat：最终总结聊天状态，在同一页面展示总结卡、消息流、时间戳区与输入区。

这意味着视频总结流程的控制中心已经统一收口到 lib/features/home/home_screen.dart，而不是通过多个独立路由串联。

### 2. 清理错误的 processing 路由入口

为了保证交互符合设计稿语义，已移除视频总结对 processing 占位页的依赖：

- app 路由中不再为视频总结流程注册单独的 processing 入口。
- 原有知识库占位页仍保留。
- HomeScreen 现在直接承载视频总结的后半段状态切换。

### 3. 重构数据层为可切换仓库接口

最初页面直接依赖本地 mock service。现已将其替换为可扩展的数据接缝：

- 新增 VideoSummaryRepository 抽象接口。
- 新增 FakeVideoSummaryRepository 作为当前假实现。
- App 入口通过依赖注入方式将仓库传给 HomeScreen。

这样后续如果要接真实接口，只需要新增真实仓库实现并替换注入，不需要重写 HomeScreen 的流程与视图逻辑。

### 4. 补齐视频总结相关模型

围绕工作区状态流转，已抽出视频总结模块所需的主要模型：

- VideoSummaryStage
- VideoAssetInfo
- ProcessingSnapshot
- ProcessingBadge
- ProcessingStep
- DraftResult
- FinalSummaryData
- TimestampChipData
- ChatMessage
- SummaryChatSender

这些模型用于解耦页面与数据来源，避免 UI 直接依赖散乱的 Map 或硬编码字段。

### 5. 处理进度与详情的本地模拟

processing 阶段现已具备本地模拟能力：

- 点击 开始生成初稿 后切换到 processing 状态。
- 使用 Stream 逐步推送 ProcessingSnapshot。
- 主卡片展示处理中的阶段信息、进度百分比、进度条与 badge。
- 点击处理中卡片可展开详细处理信息。
- 完成后自动切换到 draft 状态。

### 6. 聚合草稿状态实现

draft 阶段已经在同一页面内实现：

- 展示聚合稿正文卡片。
- 展示草稿概述与正文段落。
- 提供 总结指导（可选） 输入区域。
- 点击 生成最终稿 后进入 finalChat 状态。

当前草稿数据由本地仓库假实现返回，不依赖真实模型生成。

### 7. 最终总结聊天状态实现

finalChat 阶段已具备本地静态会话与一轮假对话能力：

- 展示最终总结主卡片。
- 展示消息块列表。
- 展示消息操作图标区。
- 展示时间戳范围选择与开关。
- 展示底部输入区。
- 用户发送消息后，本地追加一条用户消息与一条系统假回复。

### 8. 按 .pen 收紧 UI 细节

本轮对 UI 进行了多次收紧，目标是更接近简洁版 1.2.pen 的布局语义与视觉节奏，主要包括：

- 顶部栏尺寸、标题字号、左右图标按钮尺寸。
- processing 主卡片的圆角、渐变、状态 pill、进度条、细标签。
- 处理详情卡片的分层结构、辅助说明、步骤卡、底部提示条。
- draft 正文卡片的标签结构、正文容器、说明文字与间距。
- final chat 的总结卡、消息块、时间戳条、底部胶囊输入区和图标按钮。
- 底部导航的图标和选中态视觉。

虽然未做逐像素截图回归，但当前实现已经不再只是结构近似，而是向设计稿的卡片密度、圆角语言、文本层级与控件节奏继续靠拢。

## 关键文件变更

### 新增文件

- lib/features/home/video_summary_models.dart
- lib/features/home/video_summary_repository.dart
- lib/features/home/fake_video_summary_repository.dart
- DEVELOPMENT_LOG.md

### 主要修改文件

- lib/features/home/home_screen.dart
  - 从单纯首页入口改为视频总结统一工作区页面。
  - 内部承载 ready / processing / draft / finalChat 四种状态。
  - 增加处理详情展开、草稿过渡、最终总结聊天与时间戳逻辑。
  - 收紧组件布局与 UI 细节。

- lib/app/app.dart
  - 通过 FakeVideoSummaryRepository 注入 HomeScreen。
  - 保持知识库占位路由。

- lib/features/module_placeholder/module_placeholder_screen.dart
  - 当前仍作为知识库占位页使用。
  - 不再作为视频总结 processing 流程的承载页。

### 已移除文件

- lib/features/home/video_summary_mock_service.dart
  - 原有页面直连 mock service 已废弃，职责由仓库层替代。

## 当前代码结构说明

视频总结模块的主要结构如下：

- HomeScreen
  - 工作区页面与状态流转控制中心

- VideoSummaryRepository
  - 视频总结的数据接口定义

- FakeVideoSummaryRepository
  - 当前本地假实现

- video_summary_models.dart
  - 各种页面状态与展示模型

当前 App 的依赖关系是：

- VidNexusApp 创建 FakeVideoSummaryRepository
- HomeScreen 接收仓库依赖
- HomeScreen 通过仓库拉取视频信息、进度快照、草稿结果、最终总结与聊天回复

## 当前仍然故意未做的内容

以下内容当前明确没有实现，属于后续阶段工作：

- 真实后端 API 请求
- 真实上传逻辑
- 音视频处理能力
- 流式大模型回复
- 数据库存储
- 分享、导出、朗读等真实能力
- 基于真机截图的逐像素回归校准

## 验证情况

已执行并通过：

- flutter analyze

这说明当前改动在静态分析层面没有报错。

## 当前交互验收方式

可以通过以下路径验证当前实现：

1. 打开应用，停留在视频总结首页。
2. 点击开始生成初稿，确认页面不跳转，而是在当前页面进入 processing。
3. 观察浅蓝主卡片是否承担处理中主信息，并可展开详细处理信息。
4. 等待本地模拟进度结束，确认页面自动切到 draft。
5. 在 draft 中查看聚合稿正文，并输入总结指导。
6. 点击生成最终稿，确认页面切到 finalChat。
7. 在 finalChat 中输入消息，确认本地追加用户消息和系统假回复。

## 后续建议

后续可继续沿以下方向推进：

- 基于真机截图与 .pen 对比，继续微调字号、间距、圆角和图标位置。
- 将 FakeVideoSummaryRepository 替换为真实仓库实现，例如 HttpVideoSummaryRepository。
- 为时间戳选择、消息操作区和摘要卡片补上真实业务能力。
