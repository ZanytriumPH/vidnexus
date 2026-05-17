# Phase 6 完成报告：认证流程完善

> **完成日期**: 2026-05-17 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 6 | **前置依赖**: Phase 1 ✅ → Phase 2 ✅ → Phase 3 ✅ → Phase 4 ✅ → Phase 5 ✅

---

## 1. 概述

Phase 6 的目标是完成登录/注册之外的认证体验闭环：启动时自动恢复会话、提供显式登出入口、Token 过期时弹出用户提示并自动跳转登录页、完善 Request ID 追踪链路。不同于 Phase 2-5 的 Service 层新建，Phase 6 聚焦于 Auth 模块的内部增强与 `app.dart` 启动流程重构——引入 `AuthGate` 作为启动守卫，统一管理"加载中 → 已登录 → 未登录 → 会话过期"四种状态。

**9 个文件变更，1 个新建文件，零破坏性改动，所有现有路由与登录/注册页面保持不变。**

---

## 2. 完成内容

### 2.1 文件变更总览

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `lib/features/auth/auth_gate.dart` | 启动认证守卫 + Splash 画面 + 会话过期弹窗 |
| **修改** | `lib/app/app.dart` | `initialRoute` → `home: AuthGate()` |
| **修改** | `lib/features/auth/auth_state.dart` | 新增 `sessionExpired` 字段 |
| **修改** | `lib/features/auth/auth_controller.dart` | 7 处改动（详见 §2.2.2） |
| **修改** | `lib/features/auth/login_screen.dart` | `popCurrent` → `goToHomeRoot` |
| **修改** | `lib/features/auth/register_screen.dart` | `popCurrent` → `goToHomeRoot` |
| **修改** | `lib/services/api/auth_interceptor.dart` | 请求 ID 改用 UUID 格式 |
| **修改** | `lib/services/api/error_interceptor.dart` | 错误日志包含 `x-request-id` |
| **修改** | `lib/features/home/widgets/session_settings_sheet.dart` | 新增"退出登录"按钮 + 确认对话框 |

### 2.2 各组件详述

#### 2.2.1 `AuthGate` — 启动认证守卫（新建）

**位置**: `lib/features/auth/auth_gate.dart`

**职责**: 作为 `MaterialApp.home` 的唯一入口，替代原先的 `initialRoute: '/'`（直接进 `HomeScreen`）。

**四种状态渲染**:

| 状态条件 | 渲染内容 | 说明 |
|---------|---------|------|
| `isLoading == true` | `_SplashScreen` | 品牌 Logo + `CircularProgressIndicator`，等待 `_restoreSession()` 完成 |
| `isLoggedIn == true` | `HomeScreen` | 会话有效，直接进入主页 |
| `isLoggedIn == false`（初始） | `LoginScreen` | 无本地 token，展示登录页 |
| `sessionExpired == true` | `LoginScreen` + Dialog | Token 过期，弹出"登录已过期"对话框后再展示登录页 |

**关键实现细节**:

- `_sessionExpiredHandled` 标志防止 Dialog 重复弹出
- 会话过期 Dialog 使用 `barrierDismissible: false`，强制用户确认
- 确认后调用 `AuthController.clearSessionExpired()` 清除标志，避免下次重建时再次弹出
- `_SplashScreen` 使用 `AppColors.primary` 品牌色，与 `LoginScreen`/`RegisterScreen` 风格统一

**状态流转图**:

```
App 启动
  │
  ▼
AuthGate.build()
  │
  ├─ isLoading? ──yes──▶ _SplashScreen（品牌 Logo + 加载指示器）
  │                        │
  │                        │ (_restoreSession 完成)
  │                        ▼
  ├─ sessionExpired? ──yes──▶ showDialog("登录已过期") → LoginScreen
  │
  ├─ isLoggedIn? ──yes──▶ HomeScreen
  │
  └─ isLoggedIn? ──no───▶ LoginScreen
```

#### 2.2.2 `AuthController` — 增强（7 处改动）

**位置**: `lib/features/auth/auth_controller.dart`

**改动清单**:

| # | 方法/位置 | 改动前 | 改动后 |
|---|----------|--------|--------|
| 1 | `build()` 返回值 | `const AuthState()` | `const AuthState(isLoading: true)` |
| 2 | `logout()` 签名 | `Future<void> logout()` | `Future<void> logout({bool isSessionExpired = false})` |
| 3 | `logout()` 状态 | `state = const AuthState()` | `state = AuthState(sessionExpired: isSessionExpired)` |
| 4 | `tryRefresh()` 空 token | 直接返回 `false` | 先调 `_onRefreshFailed()` 再返回 `false` |
| 5 | `tryRefresh()` 失败 | 仅 catch 忽略 | catch 后调 `await _onRefreshFailed()` |
| 6 | `_restoreSession()` 刷新失败 | `if (!refreshed) await logout()` | 移除（`tryRefresh` 已通过 `_onRefreshFailed` 处理） |
| 7 | `_injectAuthInterceptor()` 回调 | `onRefreshFailed: logout` | `onRefreshFailed: () => _onRefreshFailed()` |

**新增方法**:

```dart
/// 标记会话已过期并登出（供外部在 401 不可恢复时调用）。
Future<void> expireSession() async {
  await logout(isSessionExpired: true);
}

/// 清除 sessionExpired 标志（在 AuthGate 弹出提示后调用）。
void clearSessionExpired() {
  if (state.sessionExpired) {
    state = state.copyWith(sessionExpired: false);
  }
}

/// refresh 失败时的统一处理：清除存储 + 清除拦截器 + 设置过期标志。
Future<void> _onRefreshFailed() async {
  await secureStorage.delete(key: _kAccessToken);
  await secureStorage.delete(key: _kRefreshToken);
  _clearAuthInterceptor();
  state = state.copyWith(isLoggedIn: false, sessionExpired: true);
}
```

**设计决策 — 为什么需要 `_onRefreshFailed()` 独立方法**:

`tryRefresh()` 被两处调用：(1) `_restoreSession()` 启动恢复时，(2) `AuthInterceptor.onError` 拦截 401 时。两处都需要在 refresh 失败后执行相同的清理逻辑（删 token + 清拦截器 + 设过期标志），统一收口到 `_onRefreshFailed()` 避免重复代码和状态不一致。

#### 2.2.3 `AuthState` — 新增字段

**位置**: `lib/features/auth/auth_state.dart`

新增 `sessionExpired` 字段：

```dart
/// 当 refresh token 失败或 401 无法恢复时置为 true，
/// 供 AuthGate 层弹出"登录已过期"提示并跳转登录页。
final bool sessionExpired;
```

`copyWith` 同步扩展，默认值 `false`，向后兼容。

#### 2.2.4 `LoginScreen` / `RegisterScreen` — 导航修正

**改动**: `AppNavigator.popCurrent(context)` → `AppNavigator.goToHomeRoot(context)`

**原因**: 之前的 `popCurrent` 假设 LoginScreen 总是被 push 在 HomeScreen 之上。引入 `AuthGate` 后，LoginScreen 可能直接作为 `AuthGate` 的子组件渲染（无 Navigator 历史），此时 `popCurrent` 为无效操作。`goToHomeRoot` 使用 `pushNamedAndRemoveUntil`，无论是作为根页面还是被 push 的页面，都能正确清除栈并跳转到主页。

#### 2.2.5 `AuthInterceptor` — Request ID 升级

**位置**: `lib/services/api/auth_interceptor.dart`

**改动前**:
```dart
options.headers['x-request-id'] =
    options.headers['x-request-id'] ?? 'req-${DateTime.now().millisecondsSinceEpoch}';
```

**改动后**:
```dart
options.headers['x-request-id'] =
    options.headers['x-request-id'] ?? ApiClient.generateRequestId();
```

`ApiClient.generateRequestId()` 内部使用 `const Uuid().v4().substring(0, 8)`，生成格式为 `req-a1b2c3d4` 的 UUID 短标识，替代原先的毫秒时间戳。新增 `import 'api_client.dart'`。

#### 2.2.6 `ErrorInterceptor` — Request ID 日志

**位置**: `lib/services/api/error_interceptor.dart`

**改动**: 所有 `_log()` 调用前增加 `[$requestId]` 前缀。

新增 `_extractRequestId()` 方法：

```dart
String _extractRequestId(DioException err) {
  // 优先从请求 options headers 中获取（由 AuthInterceptor 注入）
  final reqId = err.requestOptions.headers['x-request-id'];
  if (reqId != null && reqId.toString().isNotEmpty) return reqId.toString();
  // fallback：从响应 headers 中获取（服务端可能回传）
  final respId = err.response?.headers.value('x-request-id');
  if (respId != null && respId.isNotEmpty) return respId;
  return 'no-request-id';
}
```

**日志输出示例**:

```
[API Error] [req-a1b2c3d4] 404 — 资源不存在 — KnowledgeBase not found
[API Error] [req-e5f6g7h8] 401 Unauthorized — Token has expired
```

#### 2.2.7 `session_settings_sheet.dart` — 登出入口

**位置**: `lib/features/home/widgets/session_settings_sheet.dart`

在原有两个设置开关下方新增分割线和"退出登录"按钮：

- 按钮样式：红色文字 + 浅红边框 `OutlinedButton.icon`，左侧 `Icons.logout_rounded`
- 点击弹出确认对话框："确定要退出当前账号吗？"
- 确认后调用 `AuthController.logout()` + 关闭设置 sheet
- 使用 `ConsumerWidget` 通过 `WidgetRef` 访问 `authControllerProvider`

### 2.3 `app.dart` 启动流程变更

**改动前**:
```dart
MaterialApp(
  initialRoute: AppRoutes.home,  // 直接进入 HomeScreen
  onGenerateRoute: AppRouter.onGenerateRoute,
  ...
)
```

**改动后**:
```dart
MaterialApp(
  home: const AuthGate(),  // 经 AuthGate 守卫决定进入 HomeScreen 或 LoginScreen
  onGenerateRoute: AppRouter.onGenerateRoute,
  ...
)
```

`AppRoutes.home`（`'/'`）保留在 `AppRouter` 中用于 `AppNavigator.goToHomeRoot()` 的 `pushNamedAndRemoveUntil` 调用。

---

## 3. 架构一致性

### 3.1 状态管理模式对齐

Phase 6 的 `AuthState.sessionExpired` 标志 + `AuthGate` 监听模式，与 Phase 3-4 建立的 Riverpod `Notifier` + `ConsumerWidget` 监听模式完全一致：

| Phase | Controller | 关键状态字段 | 监听 Widget |
|-------|-----------|------------|------------|
| Phase 3 | `VideoSummaryFlowController` | `stage`, `isGenerating` | `HomeScreen`（`ConsumerStatefulWidget`） |
| Phase 4 | `KnowledgeBaseController` | `isLoading`, `libraries` | `KnowledgeBaseHomeScreen`（`ConsumerWidget`） |
| **Phase 6** | **`AuthController`** | **`isLoading`, `isLoggedIn`, `sessionExpired`** | **`AuthGate`（`ConsumerStatefulWidget`）** |

### 3.2 路由模式对齐

| 改动 | 遵循规则 |
|------|---------|
| `LoginScreen`/`RegisterScreen` 导航改用 `AppNavigator.goToHomeRoot()` | 页面层只调用 `AppNavigator` 语义化方法（`AI_DEVELOPMENT_GUIDE.md`） |
| `AuthGate` 保留在 `lib/features/auth/` | 新组件按功能域放置 |
| `app.dart` 路由注册保留 `AppRoutes` + `AppRouter` | 不主动迁移 `go_router` |
| 新增 `_LogoutButton` 为 `ConsumerWidget` | 遵循 Riverpod 模式 |

### 3.3 已有能力复用

| 依赖组件 | Phase | 使用位置 |
|---------|-------|---------|
| `FlutterSecureStorage`（`secureStorage` 单例） | Phase 1 | `AuthController._restoreSession()`, `_persistTokens()`, `_getOrCreateDeviceId()` |
| `ApiClient.injectAuthInterceptor()` | Phase 2 | `AuthController._injectAuthInterceptor()` |
| `ApiClient.removeAuthInterceptor()` | Phase 2 | `AuthController._clearAuthInterceptor()`, `_onRefreshFailed()` |
| `ApiClient.generateRequestId()` | Phase 1 | `AuthInterceptor.onRequest` |
| `ApiConfig` | Phase 1 | `ErrorInterceptor`（通过 `ApiClient` 间接） |

---

## 4. 端点覆盖

Phase 6 不新增 Service 端点。Auth 4 端点（register, login, refresh, me）在项目早期已由 `AuthService` 覆盖，Phase 6 完善了这些端点的调用时机和错误恢复流程：

| 端点 | 方法 | Service | 调用时机 |
|------|------|---------|---------|
| `POST /api/v1/auth/register` | `AuthService.register()` | 已有 | 注册页提交 |
| `POST /api/v1/auth/login` | `AuthService.login()` | 已有 | 登录页提交 |
| `POST /api/v1/auth/refresh` | `AuthService.refresh()` | 已有 | 401 拦截 + 启动恢复 |
| `GET /api/v1/auth/me` | `AuthService.me()` | 已有 | 启动恢复验证 token 有效性 |

**全量端点覆盖率**（Phase 6 后）:

| 路由组 | 端点数 | Service 层 | Phase |
|--------|--------|-----------|-------|
| system (health) | 1 | 直接 Dio | Phase 1 ✅ |
| auth | 4 | `AuthService` | **Phase 6 ✅** |
| knowledge-bases | 8 | `KnowledgeBaseService` | Phase 2 ✅ |
| video-resources | 5 | `VideoService` | Phase 2 ✅ |
| video-summary-tasks | 5 | `TaskService` | Phase 2 ✅ |
| video-qa | 5 | `VideoQAService` | Phase 5 ✅ |
| global-chat | 5 | `GlobalChatService` | Phase 5 ✅ |
| global-qa | 5 | `GlobalQAService` | Phase 5 ✅ |
| **合计** | **38** | **8 Service** | **38/38 ✅** |

---

## 5. 验证结果

### 5.1 静态分析

```
$ flutter analyze
Analyzing VidNexus...
No issues found! (ran in 4.9s)
```

零错误、零警告。

### 5.2 功能验证

| 验证项 | 方法 | 结果 |
|--------|------|------|
| `AuthGate` 四种状态渲染路径正确 | 代码审阅 | ✅ |
| `_restoreSession()` → `tryRefresh()` 失败不再双重重置状态 | 代码审阅 | ✅ |
| `_onRefreshFailed()` 三步骤（删 token + 清拦截器 + 设标志）完整 | 代码审阅 | ✅ |
| `sessionExpired` Dialog `barrierDismissible: false` | 代码审阅 | ✅ |
| `LoginScreen`/`RegisterScreen` 登录成功跳转 `goToHomeRoot` | 代码审阅 | ✅ |
| 设置页登出按钮 → 确认对话框 → `logout()` 链路 | 代码审阅 | ✅ |
| `AuthInterceptor` 使用 UUID 格式 request-id | 代码审阅 | ✅ |
| `ErrorInterceptor` 日志含 `[req-xxxxxxxx]` 前缀 | 代码审阅 | ✅ |
| `build()` 初始 `isLoading: true` 避免 LoginScreen 闪烁 | 代码审阅 | ✅ |

### 5.3 用户场景覆盖

| 场景 | 预期行为 | 实现位置 |
|------|---------|---------|
| 首次启动（无 token） | Splash → LoginScreen | `AuthGate.build()`: `isLoading=true` → `isLoggedIn=false` |
| 启动时 token 有效 | Splash → `/auth/me` 成功 → HomeScreen | `_restoreSession()` → `state = AuthState(isLoggedIn: true)` |
| 启动时 token 过期但 refresh 成功 | Splash → `/auth/me` 401 → `tryRefresh()` 成功 → HomeScreen | `_restoreSession()` → `tryRefresh()` 成功路径 |
| 启动时 token 过期且 refresh 失败 | Splash → `/auth/me` 401 → `tryRefresh()` 失败 → Dialog + LoginScreen | `_restoreSession()` → `_onRefreshFailed()` → `AuthGate` 检测 `sessionExpired` |
| 使用中 token 过期（API 返回 401） | `AuthInterceptor` 拦截 → `tryRefresh()` 失败 → Dialog + LoginScreen | `AuthInterceptor.onError` → `_onRefreshFailed()` → `AuthGate` 重建 |
| 用户主动登出 | 设置页 → 确认 → `logout()` → LoginScreen | `_LogoutButton._confirmLogout()` → `AuthController.logout()` |
| 网络不可达启动 | 有本地 token → 乐观登录 HomeScreen | `_restoreSession()` DioException catch 分支 |

---

## 6. 关键决策

| 决策项 | 结论 | 理由 |
|--------|------|------|
| 启动守卫用 `home:` 而非 `initialRoute:` | `MaterialApp.home: AuthGate()` | `initialRoute` 无法等待异步 auth 检查完成；`home` widget 可通过 Riverpod 响应式切换 |
| `sessionExpired` 用 Dialog 而非 SnackBar | `showDialog` + `barrierDismissible: false` | Token 过期是阻塞性事件，需要用户明确确认；SnackBar 自动消失用户可能错过 |
| `tryRefresh` 失败逻辑统一收口 `_onRefreshFailed()` | 独立 private 方法 | 避免 `_restoreSession` 和 `AuthInterceptor` 两处重复的清理代码 |
| `_restoreSession` 不再在 `tryRefresh` 失败后调 `logout()` | 移除 `await logout()` | `_onRefreshFailed()` 已设置正确的 `sessionExpired: true`，`logout()` 会覆盖为 `false` |
| `LoginScreen`/`RegisterScreen` 改用 `goToHomeRoot` | `popCurrent` → `goToHomeRoot` | 兼容 LoginScreen 作为根页面（AuthGate 子组件）和被 push 页面两种场景 |
| 登出入口放在设置 sheet 而非独立页面 | `session_settings_sheet.dart` 底部 | 设置 sheet 已是用户可触及的全局设置入口；不新增独立路由保持简洁 |
| `build()` 初始 `isLoading: true` | 启动即显示 Splash | 避免 `const AuthState()`（`isLoading: false`）导致首帧闪现 LoginScreen |

---

## 7. 风险回顾

| 原计划风险 | 当前状态 | 说明 |
|-----------|---------|------|
| Auth 拦截器与启动恢复时序冲突 | ✅ 已缓解 | `AuthInterceptor` 在 `_restoreSession()` 中通过 `_injectAuthInterceptor()` 注入，早于任何 API 调用；`_onRefreshFailed()` 统一清理 |
| Token 过期后 UI 无提示 | ✅ 已解决 | `sessionExpired` → Dialog → 用户确认 → LoginScreen |
| 登出后 token 残留 | ✅ 已解决 | `logout()` 删除 SecureStorage 中的 access + refresh token，清除 AuthInterceptor |

---

## 8. 与后续 Phase 的关系

Phase 6 是 `API_INTEGRATION_PLAN.md` 中最后一个功能 Phase。后续 Phase 7（集成测试与文档）依赖 Phase 6 完成的认证闭环：

| Phase 7 任务 | Phase 6 提供的依赖 |
|-------------|------------------|
| 端到端测试 `HttpVideoSummaryRepository` | `AuthInterceptor` 自动注入 token，测试可模拟登录态 |
| API 对接检查清单 | 38/38 端点 Service 覆盖率已达成 |
| `API_INTEGRATION_STATUS.md` | 所有路由组状态可标记为 ✅ |
