# QA 图片附件功能开发计划

> 目标：恢复 QA 输入框的加号按钮（仅保留拍照 + 相册上传图片），实现前端图片上传与后端联调，并在聊天气泡中渲染用户发送的图片。

---

## 现状分析

### 已完成（可直接复用）

| 层 | 组件 | 状态 |
|----|------|------|
| 后端 | 附件上传接口 `POST /api/v1/attachments/upload` | ✅ 完整（仅图片，10MB 限制） |
| 后端 | QA 请求 Schema `attachments: list[AttachmentInfo]` | ✅ 完整 |
| 后端 | QA 响应 Schema 含 `attachments` 字段 | ✅ 完整 |
| 后端 | 数据库 `attachments` JSONB 列 + 迁移 | ✅ 完整 |
| 后端 | QA 记录读取时重新生成 presigned URL | ✅ 完整 |
| 后端 | RAG Agent 下载附件图片并送入 Vision LLM | ✅ 完整 |
| Flutter | `AttachmentService.uploadAttachment()` | ✅ 完整，从未调用 |
| Flutter | DTO `AttachmentInfo` 模型 | ✅ 完整 |
| Flutter | QA 请求/响应 DTO 含 `attachments` | ✅ 完整 |

### 需要开发

| 层 | 组件 | 缺失 |
|----|------|------|
| 后端 | 本地文件 HTTP 静态访问 | ❌ presigned URL 是 `file://` 协议，前端无法访问 |
| Flutter | `image_picker` 依赖 | ❌ 未安装 |
| Flutter | `ComposerAttachmentButton` 实际选取逻辑 | ❌ 三个 action 都是占位 SnackBar |
| Flutter | 输入框加号按钮 | ❌ 已注释 |
| Flutter | `ChatMessage` / `KnowledgeChatMessage` 模型 | ❌ 无 `attachments` 字段 |
| Flutter | Controller 发送消息时携带附件 | ❌ 不接受附件参数 |
| Flutter | Controller 历史消息映射保留附件 | ❌ 静默丢弃 `attachments` |
| Flutter | 聊天气泡图片渲染 | ❌ 无渲染逻辑 |
| Flutter | 图片预览 / 选中态 UI | ❌ 无 |

---

## 开发任务

### Phase 1：后端 — 静态文件服务

> 让前端能通过 HTTP 访问已上传的图片。

**文件：** `video_summarizer/backend/api/routes/attachment_upload.py`（或新建 `static_files.py`）

**任务：**
- [ ] 新增静态文件路由 `GET /api/v1/attachments/{user_id}/{filename}`，从 `oss_local_root` 目录提供文件
- [ ] 需要鉴权（至少校验 token），防止未授权访问
- [ ] 或修改 `oss_client.py` 的 `get_presigned_url()`，返回 HTTP URL 而非 `file://`
- [ ] 确保返回正确的 `Content-Type`（image/jpeg 等）

**方案选择：**
- **方案 A（推荐）**：新增一个受保护的静态文件路由，不需要真正的 presigned URL，直接用 `/api/v1/attachments/{oss_key}` 访问，后端校验权限后返回文件
- **方案 B**：保持 presigned URL 机制，但改为生成 HTTP URL（需要 token 签名逻辑）

---

### Phase 2：Flutter — 安装 image_picker

**文件：** `VidNexus/pubspec.yaml`

**任务：**
- [ ] 添加依赖 `image_picker: ^1.x`
- [ ] 执行 `flutter pub get`

---

### Phase 3：Flutter — 改造 ComposerAttachmentButton

> 只保留拍照和相册，移除文件选项，接入真实图片选取。

**文件：** `VidNexus/lib/app/widgets/composer_attachment_button.dart`

**任务：**
- [ ] 移除 `_AttachmentAction.file` 枚举值和对应的 BottomSheet 选项
- [ ] 注入 `ImagePicker`，实现 `_pickFromCamera()` → `ImagePicker.pickImage(source: ImageSource.camera)`
- [ ] 实现 `_pickFromGallery()` → `ImagePicker.pickImage(source: ImageSource.gallery)`
- [ ] 选取成功后通过回调返回 `XFile`（或 `File`）给父组件
- [ ] 添加图片大小/格式校验（与后端一致：JPEG/PNG/GIF/WEBP，≤10MB）
- [ ] 添加选取中的 loading 状态

**接口设计建议：**
```dart
ComposerAttachmentButton({
  required void Function(File imageFile) onImagePicked,
})
```

---

### Phase 4：Flutter — UI 模型增加 attachments 字段

**文件 1：** `VidNexus/lib/features/home/video_summary_presentation_models.dart`
- [ ] 新增 `ChatAttachment` 数据类（包含 `name`, `ossKey`, `mimeType`, `presignedUrl`）
- [ ] `ChatMessage` 增加 `List<ChatAttachment> attachments` 字段（默认空列表）

**文件 2：** `VidNexus/lib/features/knowledge_base/knowledge_base_models.dart`
- [ ] `KnowledgeChatMessage` 增加 `List<ChatAttachment> attachments` 字段（默认空列表）

> `ChatAttachment` 可抽到公共文件复用，两个模型引用同一个类。

---

### Phase 5：Flutter — 恢复加号按钮 + 接入上传流程

> 输入框区域：选图 → 上传 → 显示预览 → 随消息发送。

**文件 1：** `VidNexus/lib/features/home/widgets/video_summary_final_chat_widgets.dart`
- [ ] 取消注释 `ComposerAttachmentButton` 的 import 和使用
- [ ] 在 `ChatComposer` 的 state 中维护 `_pendingAttachments` 列表（待上传的本地文件）
- [ ] `onImagePicked` 回调中：调用 `AttachmentService.uploadAttachment()`，成功后将 `AttachmentInfo` 加入待发送列表
- [ ] 输入框上方显示选中图片的缩略图预览条（可滑动，支持点击删除）
- [ ] 发送消息时将 `attachments` 一并传给 controller

**文件 2：** `VidNexus/lib/features/knowledge_base/widgets/knowledge_base_shared_widgets.dart`
- [ ] 同上，恢复 `ComposerAttachmentButton`，接入相同逻辑

---

### Phase 6：Flutter — Controller 层联调

**文件 1：** `VidNexus/lib/features/home/application/video_summary_flow_controller.dart`
- [ ] `sendChatMessage()` 签名增加 `List<AttachmentInfo> attachments` 参数
- [ ] 传递给 `_repository.sendSummaryChatMessage()` 的对应方法
- [ ] `_refreshChatMessagesFromBackend()` 映射时读取 `qa.attachments`，转为 `ChatAttachment` 填入 `ChatMessage`

**文件 2：** `VidNexus/lib/features/knowledge_base/application/knowledge_base_chat_controller.dart`
- [ ] `_sendChatMessage()` 增加 `attachments` 参数
- [ ] 传递给 `_qaService.createQAStream()`
- [ ] `_loadQaHistory()` 映射时读取 `dto.attachments`

**文件 3：** Repository 接口层
- [ ] `video_summary_repository.dart` 中 `sendSummaryChatMessage()` 增加 attachments 参数
- [ ] `http_video_summary_repository.dart` 实现中构建 `VideoQACreateRequest` 时填入 attachments
- [ ] 知识库 QA service 的 `createQAStream()` 同样增加 attachments 参数

---

### Phase 7：Flutter — 聊天气泡图片渲染

**文件 1：** `VidNexus/lib/features/home/widgets/video_summary_final_chat_widgets.dart`
- [ ] `_SummaryChatBubbleBody` 中，当 `message.attachments` 非空时，在文本上方渲染图片缩略图网格
- [ ] 使用 `CachedNetworkImage` 或 `Image.network` 加载 presigned URL
- [ ] 点击缩略图打开全屏图片预览（`showDialog` + `PhotoView` 或简单的 `InteractiveViewer`）
- [ ] 加载失败时显示占位图

**文件 2：** `VidNexus/lib/features/knowledge_base/knowledge_base_chat_screen.dart`
- [ ] `_KnowledgeChatBubble` 同样增加图片渲染逻辑

**UI 规格建议：**
- 缩略图尺寸：80×80，圆角 8px，最多显示 4 张，超出显示 "+N"
- 网格间距：4px
- 仅用户消息气泡显示附件（AI 回复不显示）

---

### Phase 8：联调测试

- [ ] 后端启动，确认静态文件路由可访问
- [ ] Flutter 端拍照 → 上传 → 检查 OSS 目录有文件
- [ ] QA 请求带 attachments → 后端收到 → RAG Agent 下载图片 → Vision LLM 分析
- [ ] QA 响应返回 attachments → 前端历史消息渲染图片
- [ ] 知识库 QA 同样流程验证
- [ ] 边界测试：大图片（接近 10MB）、多张图片（最多 10 张）、网络错误、上传失败

---

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `backend/api/routes/attachment_upload.py` 或新建 | 新增 HTTP 静态文件路由 |
| `VidNexus/pubspec.yaml` | 添加 `image_picker` 依赖 |
| `VidNexus/lib/app/widgets/composer_attachment_button.dart` | 重写：移除文件选项，接入 image_picker |
| `VidNexus/lib/features/home/video_summary_presentation_models.dart` | 新增 `ChatAttachment`，`ChatMessage` 增加字段 |
| `VidNexus/lib/features/knowledge_base/knowledge_base_models.dart` | `KnowledgeChatMessage` 增加字段 |
| `VidNexus/lib/features/home/widgets/video_summary_final_chat_widgets.dart` | 恢复按钮、上传流程、气泡图片渲染 |
| `VidNexus/lib/features/knowledge_base/widgets/knowledge_base_shared_widgets.dart` | 恢复按钮、上传流程 |
| `VidNexus/lib/features/knowledge_base/knowledge_base_chat_screen.dart` | 气泡图片渲染 |
| `VidNexus/lib/features/home/application/video_summary_flow_controller.dart` | 发送/历史映射携带附件 |
| `VidNexus/lib/features/knowledge_base/application/knowledge_base_chat_controller.dart` | 发送/历史映射携带附件 |
| `VidNexus/lib/features/home/video_summary_repository.dart` | 接口增加 attachments 参数 |
| `VidNexus/lib/features/home/http_video_summary_repository.dart` | 实现携带 attachments |
| `VidNexus/lib/services/video_qa_service.dart` | QA 请求携带 attachments |
| `VidNexus/lib/services/global_qa_service.dart` | QA 请求携带 attachments |

---

## 建议开发顺序

```
Phase 1 (后端静态路由)  ←  无依赖，可先行
Phase 2 (image_picker)  ←  无依赖
        ↓
Phase 3 (按钮改造)  ←  依赖 Phase 2
Phase 4 (UI 模型)   ←  无依赖
        ↓
Phase 5 (输入框接入)  ←  依赖 Phase 3 + 4
Phase 6 (Controller)  ←  依赖 Phase 4 + 5
Phase 7 (气泡渲染)    ←  依赖 Phase 4
        ↓
Phase 8 (联调)  ←  依赖全部
```

Phase 1 和 2 可并行，Phase 3/4 可并行，Phase 5/6/7 可部分并行。
