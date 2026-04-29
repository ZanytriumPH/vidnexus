# VidNexus 开发指南

## 1. 这份文档是给谁看的

这份文档是写给刚开始接触这个项目的开发同学看的，尤其适合：

- 刚学 Flutter，还不太理解为什么项目要分层
- 能看懂页面代码，但不清楚 controller、repository、mapper 分别有什么用
- 不知道一个功能应该写在哪个文件夹里
- 担心“改能改，但是不知道会不会把架构改坏”

如果你想先知道“这个项目现在为什么要这样设计”，看这份文档就够了。

如果你后面要把任务交给 AI 去继续开发，请再看 [docs/refactor/AI_DEVELOPMENT_GUIDE.md](docs/refactor/AI_DEVELOPMENT_GUIDE.md)。

## 2. 先讲结论：为什么要这样分层

### 2.1 不分层会发生什么

在小 Demo 里，把所有代码都写在页面里，短期是最快的。

但这个项目不是只有一个简单表单，它已经包含了：

- 视频总结主流程
- 处理中状态
- 草稿编辑
- 最终稿追问
- 会话历史恢复
- 时间区间选择
- 知识库多页面跳转

如果这些东西都继续写在一个页面里，后面就会越来越难维护，常见问题是：

- 改一个按钮，结果影响另一个阶段
- 页面文件越来越长，读不动
- 假数据和 UI 文案混在一起，后面接真实 API 很痛苦
- 想给 AI 分配任务时，不知道应该改哪个文件

所以这次重构的目标不是“为了高级而高级”，而是为了把不同类型的问题放到不同位置，让每个文件只做自己该做的事。

### 2.2 这套分层本质上是在回答 4 个问题

项目里所有代码，基本都可以归到下面 4 类问题里：

1. 页面长什么样
2. 状态怎么变化
3. 数据从哪里来
4. 路由怎么跳

现在的分层就是把这 4 类问题分开：

- widgets / screen：负责页面长什么样
- application：负责状态怎么变化
- repository / fake repository：负责数据从哪里来
- app/routing：负责路由怎么跳

再往里细一点：

- domain：负责“稳定的业务数据长什么样”
- mapper：负责“把稳定数据翻译成 UI 需要的数据”

## 3. 先从目录理解整个项目

当前与重构最相关的目录是：

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
docs/
  refactor/
```

你可以先把它理解成：

- app：全局公用层
- features：具体功能模块
- docs：设计说明与验收文档

## 4. app 文件夹是干什么的

### 4.1 app 的作用

app 文件夹放的是“整个应用都要用”的东西，而不是某个具体功能自己私有的东西。

比如：

- 应用入口
- 全局主题
- 路由系统
- 全局通用组件

### 4.2 [lib/app/app.dart](lib/app/app.dart)

这个文件是应用入口。

它的作用是：

- 创建 `MaterialApp`
- 注册主题
- 指定初始路由
- 把路由分发交给 `AppRouter`

你可以把它理解成“应用总开关”。

这里不应该写业务逻辑，不应该写某个功能的状态处理，也不应该塞页面内逻辑。

### 4.3 [lib/app/routing](lib/app/routing)

这里是当前项目的统一路由层。

它的作用是：

- 统一管理页面名称
- 统一管理参数化页面需要的参数
- 统一决定某个路由跳到哪个页面
- 统一提供页面层可以调用的导航方法

为什么这一步重要：

如果每个页面都自己写 `Navigator.push(...)`，项目小的时候没事，页面一多就会非常乱。

统一路由层的好处是：

- 跳转规则集中，出了问题容易找
- 不同页面的导航风格一致
- 以后想改路由方案时，有一个中心位置可改

#### [lib/app/routing/app_routes.dart](lib/app/routing/app_routes.dart)

这个文件只负责一件事：定义路由名字。

比如：

- 首页是什么路由
- 知识库首页是什么路由
- 知识库会话页、聊天页、来源页分别是什么路由

为什么要单独放这里：

因为路由名如果散落到各页面里，后面很难统一维护。

#### [lib/app/routing/app_route_arguments.dart](lib/app/routing/app_route_arguments.dart)

这个文件负责“参数化页面需要什么参数”。

例如知识库聊天页，不是空着进去的，它需要：

- 当前知识库对象
- 初始会话对象

这些参数被打包成 arguments 类。

这么做的好处是：

- 调用时更清楚
- 参数不会东一个西一个散传
- `AppRouter` 可以检查参数类型是否正确

#### [lib/app/routing/app_router.dart](lib/app/routing/app_router.dart)

这个文件是“路由总调度中心”。

它做两件事：

1. `AppRouter`
   负责根据路由名真正创建页面
2. `AppNavigator`
   负责给页面提供统一跳转方法

你可以把它理解成：

- `AppRoutes` 是路由名词典
- `AppRouteArguments` 是路由入参说明书
- `AppRouter` 是前台调度员
- `AppNavigator` 是给业务页面调用的统一门把手

#### [lib/app/routing/app_route_error_screen.dart](lib/app/routing/app_route_error_screen.dart)

这个文件是路由出错时显示的页面。

它存在的意义是：

- 如果路由写错了，不要悄悄回首页
- 如果参数类型错了，要明确显示错误

这对开发期非常重要，因为它能尽快暴露真实问题。

## 5. features 是干什么的

features 可以理解为“按功能分模块”。

当前和重构最相关的是两个模块：

- home：视频总结主功能
- knowledge_base：知识库功能

为什么要按功能分：

- 同一个功能的代码更容易放在一起
- 后续开发时更容易定位代码
- 某个功能继续变复杂时，可以在自己模块内部继续演进，而不会污染全局

## 6. home 模块为什么是当前最核心的部分

因为本轮重构的重点，就是把原来堆在首页里的复杂状态和逻辑拆开。

### 6.1 [lib/features/home/home_screen.dart](lib/features/home/home_screen.dart)

这个文件是首页页面壳。

它现在负责：

- 把页面整体结构组装起来
- 读取几个核心 provider
- 打开抽屉、打开设置、切换知识库
- 把回调传给 workspace

它现在不应该负责：

- 自己手动管理所有业务状态
- 自己做 repository 调用
- 自己做时间格式化
- 自己拼装 UI 展示模型

你可以把它理解成“总装配页面”，而不是“所有事情都亲自做的页面”。

## 7. application 层是干什么的

这是整个项目最容易让新手困惑，但也是最重要的一层。

### 7.1 一句话解释 application

application 层负责“状态怎么流动、流程怎么推进、多个东西怎么协作”。

它不负责页面长什么样，也不负责真正从接口拿数据。

### 7.2 为什么不能把这些逻辑继续写页面里

因为页面应该主要关心：

- 显示什么
- 点击后触发什么回调

而不应该同时负责：

- 什么时候进入 processing
- 什么时候生成草稿
- 会话何时同步
- 草稿文本何时回填
- 时间区间如何校验

这些一旦都塞回页面里，页面就会再次变成“上帝组件”。

### 7.3 application 里的几个核心文件

#### [lib/features/home/application/video_summary_flow_controller.dart](lib/features/home/application/video_summary_flow_controller.dart)

这是视频总结主流程控制器。

你可以把它理解成“主状态机”。

它负责：

- 当前处于哪个阶段
- 是否正在生成
- 是否正在发送聊天
- 当前选中的时间区间是什么
- processing / draft / final chat 三种结果现在是什么

用户点了“开始生成”以后，真正推进流程的是它。

所以如果你以后新增“某个流程阶段的状态变化”，第一反应应该先看这个文件，而不是先去改页面。

#### [lib/features/home/application/video_summary_session_history_controller.dart](lib/features/home/application/video_summary_session_history_controller.dart)

这是会话历史控制器。

它负责：

- 当前有哪些 session
- 哪个 session 是激活状态
- 如何创建新会话
- 如何同步当前会话快照
- 如何恢复旧会话

这类逻辑如果写在页面里，会非常乱，因为它同时涉及状态保存、状态恢复、UI 列表展示、当前 active 标记等多个问题。

#### [lib/features/home/application/video_summary_text_editing_controller.dart](lib/features/home/application/video_summary_text_editing_controller.dart)

这是文本编辑控制器。

它非常重要，因为它统一管理了：

- 偏好输入框
- 聊天输入框
- 草稿正文输入框

为什么要单独拆出来：

因为 `TextEditingController` 不是普通字符串，它本身带生命周期和监听器。

如果这些编辑器继续零散地放在页面里：

- 很容易丢同步
- 很容易恢复 session 时漏掉某一个框
- 很容易出现改文本但 session 没同步的问题

#### [lib/features/home/application/video_summary_settings_controller.dart](lib/features/home/application/video_summary_settings_controller.dart)

这是默认设置控制器。

它管理的是一些较稳定的偏好项，比如：

- 默认是否开启时间区间范围
- 默认是否展开 processing 卡片

这类数据不该混进主流程 controller，因为它们不是“当前流程走到哪一步”，而是“默认配置是什么”。

#### [lib/features/home/application/video_summary_result_mapper.dart](lib/features/home/application/video_summary_result_mapper.dart)

这是 mapper，也就是“翻译器”。

它负责把 domain/raw data 转成 UI 真正要吃的 presentation model。

这是很多新手一开始最难理解的点。

你可以这样理解：

- domain model 是稳定业务数据
- presentation model 是界面展示数据

例如：

- domain 里可能只有进度、阶段、引用时间范围
- 但 UI 里需要的是标题、标签、按钮文案、chip 文案、状态说明

这些“展示层结构和文案”就不应该让 repository 直接产出，而应该由 mapper 来翻译。

好处是：

- 接口数据更稳定
- UI 改版时不用把 repository 一起推倒
- 假数据和真实数据都能走同一条映射链路

## 8. domain 层是干什么的

### 8.1 一句话解释 domain

domain 层表示“业务上稳定的数据和规则”。

它不是页面，也不是接口实现，更不是 UI 文案。

### 8.2 [lib/features/home/domain/video_summary_domain_models.dart](lib/features/home/domain/video_summary_domain_models.dart)

这里定义了视频总结流程里的稳定结果模型，比如：

- processing 数据
- draft 数据
- final result 数据
- chat reply 数据

为什么要单独放出来：

因为 repository 返回什么，应该先由业务含义决定，而不是由某个页面长什么样决定。

### 8.3 [lib/features/home/domain/video_summary_time_utils.dart](lib/features/home/domain/video_summary_time_utils.dart)

这里放的是时间处理工具。

它负责：

- 时间显示格式化
- 时间区间解析
- 范围合法性辅助处理

为什么要抽出来：

因为时间相关逻辑如果散落在 controller 和 widget 里，后面会重复、会不一致，也更难测试和复用。

## 9. repository 是干什么的

### 9.1 一句话解释 repository

repository 层负责“给 application 层提供数据”，你可以先把它理解成“数据源接口”。

### 9.2 [lib/features/home/video_summary_repository.dart](lib/features/home/video_summary_repository.dart)

这是 repository 抽象。

它定义了：

- 怎么拿视频资源
- 怎么启动 draft generation
- 怎么拿草稿结果
- 怎么生成最终稿
- 怎么发送追问

它的意义是：

- controller 不需要知道数据到底来自假数据、真实接口，还是本地缓存
- 以后替换实现时，只换 repository 就行

### 9.3 [lib/features/home/fake_video_summary_repository.dart](lib/features/home/fake_video_summary_repository.dart)

这是当前的假数据实现。

它现在的重要意义不是“只是个 mock”，而是：

- 它已经遵守 repository contract
- 它返回的是 domain/raw data
- 它没有直接返回 UI 模型

这很关键，因为以后接真实 API 时，才能无缝替换。

## 10. model 文件为什么分成两份

这是本轮重构里一个非常关键的改动。

### 10.1 [lib/features/home/video_summary_models.dart](lib/features/home/video_summary_models.dart)

这里放的是基础共享模型，比如：

- 当前阶段枚举
- 视频资源基本信息
- 时间区间选择

这些模型比较中性，跨多层都可能会用到。

### 10.2 [lib/features/home/video_summary_presentation_models.dart](lib/features/home/video_summary_presentation_models.dart)

这里放的是 UI 专用展示模型，比如：

- ProcessingSnapshot
- DraftResult
- FinalSummaryData
- ChatMessage

为什么不能把它们和 domain model 混在一起：

因为这些模型已经包含明显的 UI 组织方式和展示语义。

简单说：

- domain model 关心“业务上有什么”
- presentation model 关心“界面上怎么显示”

## 11. widgets 文件夹是干什么的

widgets 层主要负责“把数据画出来”。

### 11.1 [lib/features/home/widgets/video_summary_content_widgets.dart](lib/features/home/widgets/video_summary_content_widgets.dart)

这个文件是 stage 分发器。

它根据当前状态决定展示：

- ready 阶段工作区
- processing 阶段工作区
- draft 阶段工作区
- final chat 阶段工作区

它的作用很像一个路由分发器，只不过不是页面路由，而是“页面内部阶段路由”。

### 11.2 四个 stage workspace

当前已经拆成：

- [lib/features/home/widgets/video_summary_ready_stage_workspace.dart](lib/features/home/widgets/video_summary_ready_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_processing_stage_workspace.dart](lib/features/home/widgets/video_summary_processing_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_draft_stage_workspace.dart](lib/features/home/widgets/video_summary_draft_stage_workspace.dart)
- [lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart](lib/features/home/widgets/video_summary_final_chat_stage_workspace.dart)

这比以前把所有阶段都塞在一个大文件里更容易理解，也更容易维护。

### 11.3 其他关键 widgets

- [lib/features/home/widgets/timestamp_interval_picker_sheet.dart](lib/features/home/widgets/timestamp_interval_picker_sheet.dart)
  时间区间选择弹层

- [lib/features/home/widgets/session_settings_sheet.dart](lib/features/home/widgets/session_settings_sheet.dart)
  会话设置弹层

- [lib/features/home/widgets/video_summary_drawer_widgets.dart](lib/features/home/widgets/video_summary_drawer_widgets.dart)
  历史会话抽屉

- [lib/features/home/widgets/video_summary_final_chat_widgets.dart](lib/features/home/widgets/video_summary_final_chat_widgets.dart)
  final chat 阶段的子组件

这些文件的存在，本质上都是为了避免“一个文件把整个首页的全部视觉细节和交互细节都写完”。

## 12. knowledge_base 模块目前怎么看

当前知识库模块的重构重点不在业务状态拆分，而在“先接入统一路由层”。

你可以暂时把它理解为：

- 已经有多页面结构
- 已经接入统一路由
- 未来如果继续深入开发，也会像 home 一样逐步建立自己的 application / domain 边界

当前最重要的几个文件是：

- [lib/features/knowledge_base/knowledge_base_home_screen.dart](lib/features/knowledge_base/knowledge_base_home_screen.dart)
- [lib/features/knowledge_base/knowledge_base_session_screen.dart](lib/features/knowledge_base/knowledge_base_session_screen.dart)
- [lib/features/knowledge_base/knowledge_base_chat_screen.dart](lib/features/knowledge_base/knowledge_base_chat_screen.dart)
- [lib/features/knowledge_base/knowledge_base_sources_screen.dart](lib/features/knowledge_base/knowledge_base_sources_screen.dart)

## 13. 作为新手，开发时最容易犯的错误

### 错误 1：觉得在页面里直接写最省事

短期可能是，但长期一定会回到重构前的问题。

判断标准：

如果你在页面里开始同时做下面 3 件以上的事情，就大概率写错位置了：

- 读多个 provider
- 调 repository
- 拼装展示文案
- 做格式化
- 决定阶段切换
- 维护多个 `TextEditingController`

### 错误 2：直接让 repository 返回 UI 模型

这是最常见的边界污染。

记住一句话：

- repository 返回稳定数据
- mapper 产出 UI 数据

### 错误 3：新增页面时直接自己写 Navigator

正确顺序应该是：

1. 先加路由名到 `AppRoutes`
2. 如果有参数，先建 arguments 类
3. 在 `AppRouter` 里注册页面
4. 在 `AppNavigator` 里暴露统一跳转入口

### 错误 4：新增输入框时自己在页面里再 new 一个 TextEditingController

如果这个输入框属于视频总结主流程，优先先看能不能纳入 `VideoSummaryTextEditingController`。

不然以后会出现：

- 页面恢复时漏同步
- session 快照不完整
- 文本状态和流程状态脱节

## 14. 遇到需求时，应该先改哪里

这里给你一个非常实用的判断表。

### 情况 A：只改界面排版或样式

优先看：

- 对应 stage workspace
- 对应 widgets 文件

### 情况 B：改流程状态，比如增加一个处理中状态

优先看：

- `video_summary_flow_controller.dart`
- `video_summary_domain_models.dart`
- `video_summary_result_mapper.dart`

### 情况 C：改假数据或接真实接口

优先看：

- `video_summary_repository.dart`
- `fake_video_summary_repository.dart`

### 情况 D：改知识库页面跳转

优先看：

- `app_routes.dart`
- `app_route_arguments.dart`
- `app_router.dart`

### 情况 E：改草稿、聊天输入、会话恢复

优先看：

- `video_summary_text_editing_controller.dart`
- `video_summary_session_history_controller.dart`
- `home_screen.dart`

## 15. 你可以把当前项目理解成什么状态

当前项目不是一个“理论上很完美”的架构项目。

更准确地说，它现在处在一个非常实用的状态：

- 足够清晰，可以继续开发
- 足够稳定，可以继续接真实能力
- 足够分层，能让多人或 AI 协作不至于失控

这就是这轮重构真正的价值。

## 16. 你接下来最应该记住的 5 句话

1. 页面负责装配和触发，不负责承载全部业务逻辑。
2. controller 负责状态和流程，不负责画界面。
3. repository 负责给稳定数据，不负责产出 UI 结构。
4. mapper 负责把稳定数据翻译成界面需要的模型。
5. 新页面导航统一走 `AppRoutes + AppRouter + AppNavigator`。

如果你能先记住这 5 句话，后面再看代码时就不容易迷路。