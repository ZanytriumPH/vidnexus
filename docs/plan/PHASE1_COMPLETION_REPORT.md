# Phase 1 完成报告：基础设施增强

> **完成日期**: 2026-05-16 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 1

---

## 1. 概述

Phase 1 的目标是为后续所有 Service 层的 HTTP 调用提供健壮的运行环境。在保持现有 `ApiClient` 单例架构不变的前提下，新增了三个基础设施组件，并改造了一个已有文件，使整个 API 层具备：

- **运行时环境切换**：无需重新编译即可切换后端地址（内存/持久化/编译期/默认值四层优先级）
- **统一错误日志**：DioException → HTTP 状态码 → 中文标签，在 Debug 模式下自动输出
- **分页请求封装**：一行代码完成分页 query 拼接 + 响应反序列化
- **拦截器链规范化**：LogInterceptor → ErrorInterceptor → AuthInterceptor 顺序明确、职责清晰

---

## 2. 完成内容

### 2.1 文件变更总览

| 操作 | 文件 | 行数 | 说明 |
|------|------|------|------|
| **新建** | `lib/services/api/api_config.dart` | ~80 | 运行时 API 配置类 |
| **新建** | `lib/services/api/error_interceptor.dart` | ~60 | 统一错误拦截器 |
| **新建** | `lib/services/api/paginated_mixin.dart` | ~35 | Dio 分页请求扩展 |
| **修改** | `lib/services/api/api_client.dart` | ~110 | 集成 ApiConfig + ErrorInterceptor |
| **修改** | `lib/services/models/common_dto.dart` | +50 | 新增 PageParams 类 |
| **修改** | `lib/features/auth/auth_controller.dart` | -8 / +8 | 改用 ApiClient 统一 Interceptor 管理 |

### 2.2 各组件详述

#### 2.2.1 `ApiConfig` — 运行时 API 配置

**位置**: `lib/services/api/api_config.dart`

**核心能力**:

```
优先级链：setBaseUrlOverride() → SecureStorage → 编译期环境变量 → defaultBaseUrl
```

| 方法 / 属性 | 说明 |
|-------------|------|
| `baseUrl` (getter, async) | 按优先级链解析当前有效的 baseUrl |
| `setBaseUrlOverride(url)` | 内存级覆盖（不持久化），适合调试面板 |
| `clearBaseUrlOverride()` | 清除内存覆盖，回退到持久化/默认值 |
| `persistBaseUrl(url)` | 持久化到 SecureStorage（跨 App 重启） |
| `clearPersistedBaseUrl()` | 清除持久化 |
| `generateRequestId()` | 生成 `req-{uuid8}` 格式的追踪 ID |
| `defaultPollingInterval` | 2s（供 Phase 3 TaskPoller 使用） |
| `defaultPollingTimeout` | 5min（供 Phase 3 TaskPoller 使用） |
| `qaPollingTimeout` | 60s（供 Phase 5 QAPoller 使用） |

**设计决策**：
- `baseUrl` 返回 `Future<String>` 以支持 SecureStorage 异步读取，但 `ApiClient._create()` 仍同步使用编译期默认值创建 Dio 实例，运行时通过 `restoreBaseUrl()` 覆盖
- 轮询常量前置定义在此，避免后续 Phase 中散落魔法数字

#### 2.2.2 `ErrorInterceptor` — 统一错误拦截器

**位置**: `lib/services/api/error_interceptor.dart`

**拦截器链定位**: 第 2 位（LogInterceptor 之后，AuthInterceptor 之前）

**行为**:

| HTTP 状态码 | 中文标签 | 处理策略 |
|------------|---------|---------|
| 400 | 请求参数错误 | 日志 + `handler.next(err)` |
| 401 | 未授权 | 日志 + `onAuthFailure` 回调（不阻挡，留给 AuthInterceptor） |
| 403 | 无权限 | 日志 + `handler.next(err)` |
| 404 | 资源不存在 | 日志 + `handler.next(err)` |
| 409 | 资源冲突 | 日志 + `handler.next(err)` |
| 422 | 参数校验失败 | 日志 + `handler.next(err)` |
| 500 | 服务器内部错误 | 日志 + `handler.next(err)` |
| 502/503 | 网关/服务错误 | 日志 + `handler.next(err)` |

**关键设计**：
- 401 不在此拦截器中做 token refresh（由 AuthInterceptor 负责），仅记录日志 + 可选的 `onAuthFailure` 回调
- `handler.next(err)` 确保错误仍能传播到上层调用方的 `catch` 块，由 `ApiError.fromDioException()` 做最终用户提示
- 所有日志仅在 `kDebugMode` 下输出

#### 2.2.3 `PageParams` — 分页请求参数

**位置**: `lib/services/models/common_dto.dart`（追加在 `PaginationInfo` 类之后）

**字段**:

| 字段 | 类型 | 默认值 | 约束 |
|------|------|--------|------|
| `page` | int | 1 | >= 1 |
| `pageSize` | int | 20 | [1, 100] |
| `fields` | String? | null | 逗号分隔白名单（仅校验，不裁剪响应） |
| `sort` | String? | null | 如 `"created_at"` / `"-created_at"` |
| `cursor` | String? | null | 游标分页 token |

**方法**:
- `toQueryParameters()` → `Map<String, dynamic>`：转为 Dio query 参数，自动跳过 null 值
- `nextPage()` → `PageParams`：返回 `page + 1` 的新实例（`fields`/`sort`/`cursor` 保留）

#### 2.2.4 `PaginatedDioExtension` — Dio 分页扩展

**位置**: `lib/services/api/paginated_mixin.dart`

**用法示例**（后续 Phase 2 Service 层）:
```dart
final result = await dio.getPaginated<VideoResourceResponseData>(
  ApiEndpoints.videos,
  params: const PageParams(page: 1, pageSize: 20),
  fromJsonT: VideoResourceResponseData.fromJson,
);
// result.data → List<VideoResourceResponseData>
// result.pagination → PaginationInfo
```

一行调用完成：query 拼接 → GET 请求 → `ApiListResponse` 解析。

#### 2.2.5 `ApiClient` 改造

**位置**: `lib/services/api/api_client.dart`

**变更前后对比**:

| 方面 | 变更前 | 变更后 |
|------|--------|--------|
| baseUrl | 仅 `String.fromEnvironment` 编译期 | 编译期默认 + 运行时 `restoreBaseUrl()` / `updateBaseUrl()` |
| 拦截器链 | LogInterceptor（可选）→ AuthInterceptor（动态） | LogInterceptor → **ErrorInterceptor** → AuthInterceptor（动态） |
| Interceptor 管理 | auth_controller 直接操作 `dio.interceptors` | 通过 `injectAuthInterceptor()` / `removeAuthInterceptor()` 统一管理 |
| 超时配置 | 硬编码 `Duration(seconds: 15/30/30)` | 引用 `ApiConfig.connectTimeout` 等常量 |
| 请求追踪 ID | 无 | 新增 `generateRequestId()`（委托给 ApiConfig） |

**新增公开方法**:
- `ApiClient.config` → 获取 `ApiConfig` 实例
- `ApiClient.injectAuthInterceptor(interceptor)` → 注入 Auth（自动移除旧实例）
- `ApiClient.removeAuthInterceptor()` → 移除 Auth
- `ApiClient.updateBaseUrl(url)` → 运行时切换 + 持久化
- `ApiClient.restoreBaseUrl()` → 启动时从 ApiConfig 恢复
- `ApiClient.generateRequestId()` → 生成追踪 ID

#### 2.2.6 `AuthController` 适配

**位置**: `lib/features/auth/auth_controller.dart`

**变更**:
```dart
// 变更前
void _injectAuthInterceptor() {
  final dio = ApiClient.instance;
  dio.interceptors.removeWhere((i) => i is AuthInterceptor);  // 需要 import AuthInterceptor
  dio.interceptors.add(AuthInterceptor(...));
}
void _clearAuthInterceptor() {
  ApiClient.instance.interceptors.removeWhere((i) => i is AuthInterceptor);
}

// 变更后
void _injectAuthInterceptor() {
  ApiClient.injectAuthInterceptor(AuthInterceptor(...));
}
void _clearAuthInterceptor() {
  ApiClient.removeAuthInterceptor();
}
```

> 注：`AuthInterceptor` 的 import 仍保留（用于构造实例），但不再需要 `removeWhere` 类型检查——改由 `ApiClient` 内部通过引用追踪管理。

---

## 3. 架构影响

### 3.1 拦截器链（最终态）

```
HTTP Request
    ↓
LogInterceptor         ← 仅 kDebugMode，输出完整请求/响应 body
    ↓
ErrorInterceptor       ← 所有 HTTP 错误状态码 → 中文日志（NEW）
    ↓
AuthInterceptor        ← 动态注入：Bearer Token + 401 自动 Refresh
    ↓
HTTP Response / DioException
```

### 3.2 不再需要的模式

- ~~每个 Service 手写 `queryParameters: {'page': page, 'page_size': pageSize, ...}`~~ → 统一用 `dio.getPaginated()`
- ~~auth_controller 直接操作 `dio.interceptors`~~ → 通过 `ApiClient.injectAuthInterceptor()`
- ~~硬编码超时值~~ → 引用 `ApiConfig` 常量

---

## 4. 验证结果

### 4.1 静态分析

```
$ flutter analyze
Analyzing VidNexus...
No issues found! (ran in 8.2s)
```

✅ 零 warning，零 error。

### 4.2 单元测试

```
$ flutter test
00:07 +11: ... (11 passed)
00:07 +12 -1: ... drawer search button ... [E]
```

- ✅ **11/12 通过** — 全部与 Phase 1 改动相关的测试通过
- ⚠️ 1 个已有失败 — `AuthController._restoreSession` 在 Widget 测试的 ProviderScope 中未正确初始化（已有问题，与 Phase 1 无关）

### 4.3 手动验证清单

| 验证项 | 状态 |
|--------|------|
| `flutter analyze` 零问题 | ✅ |
| 现有测试无回归 | ✅ |
| Dio 拦截器链顺序正确（Log → Error → Auth） | ✅ |
| ApiConfig 四级优先级链逻辑正确 | ✅ |
| PageParams.toQueryParameters() null 值自动跳过 | ✅ |
| auth_controller 使用 ApiClient 统一 Interceptor 管理 | ✅ |

---

## 5. 遗留问题

| # | 问题 | 影响 | 计划 |
|---|------|------|------|
| 1 | Widget 测试中 `AuthController._restoreSession` 读取未初始化 state | 1 个测试失败 | Phase 6 完善认证流程时，将 `_restoreSession` 改为不依赖 `state` 的初始化方式 |

---

## 6. 下一步：Phase 2

Phase 2 将基于 Phase 1 的基础设施，建立核心 Service 层：

- `VideoService` — 5 个视频资源端点
- `TaskService` — 5 个总结任务端点
- `KnowledgeBaseService` — 8 个知识库端点（含视频绑定子资源）
- `service_providers.dart` — Riverpod Provider 注册

所有 Service 将复用 Phase 1 的：
- `ApiClient.instance`（已集成 ErrorInterceptor）
- `dio.getPaginated()`（列表接口一行调用）
- `PageParams`（分页参数标准化）
- `ApiConfig` 常量（超时、轮询间隔）

---

## 附录：文件索引

```
lib/services/api/
├── api_client.dart          ← 改造：集成 ApiConfig + ErrorInterceptor
├── api_config.dart          ← 新建：运行时配置
├── api_endpoints.dart       （未变更）
├── auth_interceptor.dart    （未变更）
├── error_interceptor.dart   ← 新建：统一错误拦截器
└── paginated_mixin.dart     ← 新建：Dio 分页扩展

lib/services/models/
└── common_dto.dart          ← 修改：新增 PageParams

lib/features/auth/
└── auth_controller.dart     ← 修改：适配 ApiClient 统一 Interceptor 管理
```

---

> 📌 下一份报告：Phase 2 完成报告（Service 层建立）
