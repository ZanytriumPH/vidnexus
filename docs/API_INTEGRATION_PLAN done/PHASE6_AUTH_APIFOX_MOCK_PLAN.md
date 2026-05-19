# Auth Apifox Mock 方案：登录/注册/Token刷新/用户信息

> **创建日期**: 2026-05-17 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 2（AuthService） + Phase 6（认证流程完善） | **前置**: Phase 1 Mock 基础设施就绪

---

## 0. 前置约定

### 0.1 全局 Mock 规则

| 规则项 | 配置 |
|--------|------|
| 响应延迟 | 200-500ms（`@integer(200, 500)` ms 模拟真实网络） |
| 鉴权 Header | `/auth/me` 与 `/auth/refresh` 需校验 `Authorization: Bearer {{token}}`；`/auth/register` 与 `/auth/login` 不校验 |
| Content-Type | `application/json; charset=utf-8` |
| 基础 URL | `/api/v1` |

### 0.2 公共 Mock 变量（Apifox 前置脚本）

```javascript
// 前置脚本：初始化 Auth Mock 公共 ID 和 Token
pm.environment.set("mock_user_id", "user_mock_001");
pm.environment.set("mock_username", "vidnexus_user");

// Mock 有效 Token（HS256，payload: {sub: "user_mock_001", exp: 未来}）
pm.environment.set("mock_access_token", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyX21vY2tfMDAxIiwiZXhwIjo5OTk5OTk5OTk5LCJpYXQiOjE3MTU5MzYwMDB9.mock_access_signature");
pm.environment.set("mock_refresh_token", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyX21vY2tfMDAxIiwiZXhwIjo5OTk5OTk5OTk5LCJ0eXBlIjoicmVmcmVzaCJ9.mock_refresh_signature");

// Mock 过期 Token（exp 为过去时间）
pm.environment.set("mock_expired_token", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyX21vY2tfMDAxIiwiZXhwIjoxMDAwMDAwMDAwLCJpYXQiOjE3MTU5MzYwMDB9.mock_expired_signature");

// 注册/登录重复检测计数器
if (pm.info.requestName === "POST 注册" || pm.info.requestName === "POST 登录") {
    pm.environment.set("auth_attempt_count", 0);
}
```

### 0.3 公共响应信封

所有 Auth 接口使用统一信封（与 Phase 1-5 一致）：

```json
// 成功（单对象）
{
  "status": "success",
  "data": { ... },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}

// 错误
{
  "detail": "错误描述"
}
```

---

## 1. POST `/api/v1/auth/register` — 用户注册

> **调用方**: `AuthService.register()` → `RegisterScreen` 提交
> **请求体对齐**: `RegisterRequest(username, password)`

### 1.1 Mock 场景 1: 正常注册（默认）

**期望名称**: `注册成功`

**请求体校验**:
- `username` 长度 3-50
- `password` 长度 8-128

**响应**:

```json
{
  "status": "success",
  "data": {
    "user_id": "{{mock_user_id}}",
    "username": "{{request.body.username}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> **前端行为**: 注册成功后，`AuthController.register()` 自动调用 `login()` → 进入主页。Mock 不区分 register 与 login 的用户对象，统一用 `CurrentUserData` 结构。

---

### 1.2 Mock 场景 2: 用户名已存在（409）

**期望名称**: `用户名已存在`

**触发条件**: 请求体 `username = "admin"` （模拟已占用用户名）

```json
{
  "detail": "用户名 'admin' 已被注册"
}
```

**HTTP Status**: `409`

> Apifox 期望配置：`请求体.username == "admin"`

---

### 1.3 Mock 场景 3: 参数校验失败（422）

**期望名称**: `参数校验失败`

**触发条件**: 请求体 `username` 长度 < 3 或 `password` 长度 < 8

```json
{
  "detail": "密码长度不能少于 8 个字符"
}
```

**HTTP Status**: `422`

> 前端 `LoginScreen` 和 `RegisterScreen` 已做客户端校验，此场景用于测试服务端校验兜底。

---

### 1.4 Mock 场景 4: 弱密码（422）

**期望名称**: `弱密码被拒绝`

**触发条件**: 请求体 `password = "12345678"`

```json
{
  "detail": "密码强度不足，请包含至少一个大写字母和一个数字"
}
```

**HTTP Status**: `422`

---

## 2. POST `/api/v1/auth/login` — 用户登录

> **调用方**: `AuthService.login()` → `LoginScreen` 提交
> **请求体对齐**: `LoginRequest(username, password, deviceId)`
> **响应体对齐**: `TokenResponseData`（含 `accessToken` + `refreshToken` + `user`）

### 2.1 Mock 场景 1: 正常登录（默认）

**期望名称**: `登录成功`

**响应**:

```json
{
  "status": "success",
  "data": {
    "access_token": "{{mock_access_token}}",
    "refresh_token": "{{mock_refresh_token}}",
    "token_type": "bearer",
    "expires_in": 1800,
    "user": {
      "user_id": "{{mock_user_id}}",
      "username": "{{request.body.username}}"
    }
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**字段说明**:

| 字段 | 值 | Flutter DTO 映射 |
|------|-----|-----------------|
| `access_token` | `{{mock_access_token}}` | `TokenResponseData.accessToken` |
| `refresh_token` | `{{mock_refresh_token}}` | `TokenResponseData.refreshToken` |
| `token_type` | `"bearer"` | `TokenResponseData.tokenType` |
| `expires_in` | `1800`（30 分钟） | `TokenResponseData.expiresIn` |
| `user.user_id` | `{{mock_user_id}}` | `CurrentUserData.userId` |
| `user.username` | 请求体回显 | `CurrentUserData.username` |

**前端行为链路**:
```
LoginScreen._submit()
  → AuthController.login(username, password)
    → AuthService.login()
    → 拿到 TokenResponseData
    → secureStorage.write(access_token + refresh_token)
    → _injectAuthInterceptor()
    → state = AuthState(isLoggedIn: true, ...)
    → LoginScreen ref.listen 检测 isLoggedIn
    → AppNavigator.goToHomeRoot()
    → AuthGate 重建 → HomeScreen
```

---

### 2.2 Mock 场景 2: 用户名或密码错误（401）

**期望名称**: `凭证无效`

**触发条件**: 请求体 `password = "wrong_password"`

```json
{
  "detail": "用户名或密码错误"
}
```

**HTTP Status**: `401`

> Apifox 期望配置：`请求体.password == "wrong_password"`  
> **注意**: 此时 `AuthInterceptor` 尚未注入（登录前无 token），401 由 `ErrorInterceptor` 记录日志后透传。`AuthController._handleError()` 将 `detail` 映射为 `errorMessage`，`LoginScreen` 渲染 `_ErrorBanner`。

---

### 2.3 Mock 场景 3: 账号被锁定（403）

**期望名称**: `账号已锁定`

**触发条件**: 请求体 `username = "locked_user"`

```json
{
  "detail": "账号已被锁定，请联系管理员"
}
```

**HTTP Status**: `403`

---

### 2.4 Mock 场景 4: 参数缺失（422）

**期望名称**: `缺少必填字段`

**触发条件**: 请求体 `device_id` 为空字符串

```json
{
  "detail": "device_id 为必填字段"
}
```

**HTTP Status**: `422`

> Apifox 期望配置：`请求体.device_id == ""`

---

## 3. POST `/api/v1/auth/refresh` — 刷新 Token

> **调用方**: `AuthService.refresh()` → `AuthController.tryRefresh()` → `AuthInterceptor.onError`（401 拦截时）
> **请求体对齐**: `RefreshRequest(refreshToken, deviceId)`
> **响应体对齐**: `TokenResponseData`（与登录相同结构）

### 3.1 Mock 场景 1: 正常刷新（默认）

**期望名称**: `刷新成功`

**鉴权要求**: 不校验 `Authorization` header（refresh 本身不需要 access token）

**响应**:

```json
{
  "status": "success",
  "data": {
    "access_token": "{{mock_access_token}}",
    "refresh_token": "{{mock_refresh_token}}",
    "token_type": "bearer",
    "expires_in": 1800,
    "user": {
      "user_id": "{{mock_user_id}}",
      "username": "{{mock_username}}"
    }
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**前端行为链路**:
```
API 返回 401
  → AuthInterceptor.onError
    → tryRefresh()
      → AuthService.refresh(refreshToken, deviceId)
      → 成功 → _persistTokens(newTokens)
      → state = state.copyWith(isLoggedIn: true, ...)
      → 重试原请求（AuthInterceptor 自动 fetch）
```

---

### 3.2 Mock 场景 2: Refresh Token 已过期（401）

**期望名称**: `Refresh Token 过期`

**触发条件**: 请求体 `refresh_token` 为 `{{mock_expired_token}}`

```json
{
  "detail": "Refresh token 已过期，请重新登录"
}
```

**HTTP Status**: `401`

> Apifox 期望配置：`请求体.refresh_token == pm.environment.get("mock_expired_token")`

**前端行为链路**（重要——Phase 6 核心场景）:
```
AuthInterceptor.onError
  → tryRefresh()
    → AuthService.refresh() 返回 401
    → DioException 被 tryRefresh 捕获
    → _onRefreshFailed()
      → secureStorage.delete(access_token + refresh_token)
      → _clearAuthInterceptor()
      → state = state.copyWith(isLoggedIn: false, sessionExpired: true)
    → tryRefresh() 返回 false
  → AuthInterceptor._onRefreshFailed 回调（已在 _onRefreshFailed 中处理）
  → AuthGate 检测 sessionExpired
    → showDialog("登录已过期，请重新登录")
    → 用户点"确定"
    → AuthGate 重建 → LoginScreen
```

---

### 3.3 Mock 场景 3: 设备不匹配（403）

**期望名称**: `设备不匹配`

**触发条件**: 请求体 `device_id = "unknown_device"`

```json
{
  "detail": "设备验证失败，请重新登录"
}
```

**HTTP Status**: `403`

---

## 4. GET `/api/v1/auth/me` — 获取当前用户信息

> **调用方**: `AuthService.me()` → `AuthController._restoreSession()`（启动时验证 token）
> **鉴权**: 必须携带 `Authorization: Bearer {{token}}`

### 4.1 Mock 场景 1: Token 有效（默认）

**期望名称**: `获取当前用户成功`

**鉴权校验**: `Authorization` header 为 `Bearer {{mock_access_token}}`

**响应**:

```json
{
  "status": "success",
  "data": {
    "user_id": "{{mock_user_id}}",
    "username": "{{mock_username}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**前端行为链路**:
```
App 启动
  → AuthGate.build() → isLoading: true → _SplashScreen
  → AuthController.build()
    → _restoreSession()
      → secureStorage 读取 access_token + refresh_token（有效）
      → _injectAuthInterceptor()
      → AuthService.me()
        → GET /api/v1/auth/me（携带 Bearer mock_access_token）
        → 200 → CurrentUserData(userId, username)
      → state = AuthState(isLoggedIn: true, currentUser: ...)
  → AuthGate 重建 → isLoading: false, isLoggedIn: true → HomeScreen
```

---

### 4.2 Mock 场景 2: Token 过期（401）

**期望名称**: `Token 已过期`

**鉴权校验**: `Authorization` header 为 `Bearer {{mock_expired_token}}`

```json
{
  "detail": "Token 已过期"
}
```

**HTTP Status**: `401`

> Apifox 期望配置：`Header.Authorization == "Bearer " + pm.environment.get("mock_expired_token")`

**前端行为链路**:
```
_restoreSession()
  → AuthService.me()
    → GET /api/v1/auth/me（携带过期 token）
    → 401
  → DioException 被 _restoreSession 的 catch 捕获
    → 走 DioException 分支（非 tryRefresh 触发，而是 _restoreSession 直调 me()）
```

等等——需要确认 `_restoreSession` 中 `/auth/me` 返回 401 的处理路径。当前代码：

```dart
final resp = await _authService.me();
if (resp.status == 'success' && resp.data != null) {
  // 登录成功
} else {
  // token 无效，尝试 refresh
  await tryRefresh();
}
```

`AuthService.me()` 内部如果遇到 401，Dio 会抛出 `DioException`（除非被 `AuthInterceptor` 拦截并重试）。但在 `_restoreSession` 中，`AuthInterceptor` 已经注入。所以：

- `AuthInterceptor.onError` 先拦截 401
- 调用 `tryRefresh()`
- 如果 refresh 成功 → 重试 `/auth/me` → 正常流程
- 如果 refresh 失败 → `handler.next(err)` → `ErrorInterceptor` → `DioException` 抛出
- `_restoreSession` 的 `on DioException` catch 捕获 → 网络不可达 fallback 逻辑

**正确的 Mock 行为**:

对于"启动时 token 过期"的完整 Mock 测试，需要两个接口配合：
1. `GET /auth/me`（携带过期 token）→ 401
2. `POST /auth/refresh`（携带过期 refresh token）→ 401

最终结果：`sessionExpired: true` → Dialog → LoginScreen

---

### 4.3 Mock 场景 3: 未携带 Token（401）

**期望名称**: `缺少 Authorization Header`

**触发条件**: `Authorization` header 缺失或为空

```json
{
  "detail": "未提供认证凭证"
}
```

**HTTP Status**: `401`

---

## 5. Auth 多场景联动测试矩阵

以下矩阵覆盖 Phase 6 所有用户场景，每个场景需配置对应接口的期望组合。

### 5.1 场景 A: 首次启动（无本地 Token）

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | — | `secureStorage` 无 token | `_restoreSession()` → `accessToken == null` → `state = const AuthState()` |
| 2 | — | — | `AuthGate` → `isLoading: false, isLoggedIn: false` → `LoginScreen` |

> **无需 Apifox Mock**，纯客户端逻辑。

### 5.2 场景 B: Token 有效启动

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | — | `secureStorage` 有有效 token | `_restoreSession()` 进入验证流程 |
| 2 | `GET /auth/me` | `4.1 Token 有效` | 200 → `CurrentUserData` |
| 3 | — | — | `AuthGate` → `isLoggedIn: true` → `HomeScreen` |

### 5.3 场景 C: Token 过期 → Refresh 成功

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | — | `secureStorage` 有过期 token | `_restoreSession()` |
| 2 | `GET /auth/me` | `4.2 Token 已过期`（携带过期 token） | `AuthInterceptor` 拦截 401 |
| 3 | `POST /auth/refresh` | `3.1 正常刷新` | 获取新 token |
| 4 | `GET /auth/me` | `4.1 Token 有效`（AuthInterceptor 自动重试） | 200 |
| 5 | — | — | `AuthGate` → `isLoggedIn: true` → `HomeScreen` |

> **Apifox 配置要点**: 步骤 2 和 3 是 AuthInterceptor 自动串联，前端代码无需手动编排。

### 5.4 场景 D: Token 过期 → Refresh 也过期（最终失败）

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | — | `secureStorage` 有过期 token | `_restoreSession()` |
| 2 | `GET /auth/me` | `4.2 Token 已过期` | `AuthInterceptor` 拦截 401 |
| 3 | `POST /auth/refresh` | `3.2 Refresh Token 过期` | 401 → `_onRefreshFailed()` |
| 4 | — | — | `state = {isLoggedIn: false, sessionExpired: true}` |
| 5 | — | — | `AuthGate` → Dialog "登录已过期" → `LoginScreen` |

### 5.5 场景 E: 使用中 Token 过期（运行时 401）

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | 任意需鉴权 API | 期望返回 401 | `AuthInterceptor.onError` 拦截 |
| 2 | `POST /auth/refresh` | `3.1 正常刷新` | 获取新 token → 重试原请求 |
| 3 | 或 `POST /auth/refresh` | `3.2 Refresh Token 过期` | `_onRefreshFailed()` → Dialog → LoginScreen |

### 5.6 场景 F: 正常登录

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | `POST /auth/login` | `2.1 登录成功` | 200 → `TokenResponseData` |
| 2 | — | — | `_persistTokens()` + `_injectAuthInterceptor()` |
| 3 | — | — | `state = AuthState(isLoggedIn: true)` |
| 4 | — | — | `LoginScreen.ref.listen` → `goToHomeRoot()` → `HomeScreen` |

### 5.7 场景 G: 登录失败

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | `POST /auth/login` | `2.2 凭证无效` | 401 → `_handleError()` → `errorMessage: "用户名或密码错误"` |
| 2 | — | — | `LoginScreen` 渲染 `_ErrorBanner` |

### 5.8 场景 H: 正常注册 → 自动登录

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | `POST /auth/register` | `1.1 注册成功` | 200 → `CurrentUserData` |
| 2 | `POST /auth/login` | `2.1 登录成功` | `AuthController.register()` 自动调用 `login()` |
| 3 | — | — | `goToHomeRoot()` → `HomeScreen` |

### 5.9 场景 I: 用户主动登出

| 步骤 | 接口 | Mock 期望 | 前端预期 |
|------|------|---------|---------|
| 1 | — | 设置页点击"退出登录" → 确认 | `_LogoutButton._confirmLogout()` |
| 2 | — | — | `AuthController.logout()` → 清除 SecureStorage + AuthInterceptor |
| 3 | — | — | `state = AuthState(sessionExpired: false)` |
| 4 | — | — | `AuthGate` → `isLoggedIn: false` → `LoginScreen` |

> **无需 Apifox Mock**，纯客户端逻辑。

---

## 6. Apifox 高级 Mock 配置指南

### 6.1 多期望优先级

Auth 4 个接口的建议期望顺序（Apifox 按从上到下匹配，命中即停止）：

**POST `/auth/register`**:
1. `参数校验失败`（422）— 条件: `username.length < 3 || password.length < 8`
2. `弱密码被拒绝`（422）— 条件: `password == "12345678"`
3. `用户名已存在`（409）— 条件: `username == "admin"`
4. `注册成功`（200）— 无条件（默认）

**POST `/auth/login`**:
1. `缺少必填字段`（422）— 条件: `device_id == ""`
2. `账号已锁定`（403）— 条件: `username == "locked_user"`
3. `凭证无效`（401）— 条件: `password == "wrong_password"`
4. `登录成功`（200）— 无条件（默认）

**POST `/auth/refresh`**:
1. `设备不匹配`（403）— 条件: `device_id == "unknown_device"`
2. `Refresh Token 过期`（401）— 条件: `refresh_token` 匹配 mock_expired_token
3. `刷新成功`（200）— 无条件（默认）

**GET `/auth/me`**:
1. `缺少 Authorization Header`（401）— 条件: Header `Authorization` 为空
2. `Token 已过期`（401）— 条件: Header `Authorization` 匹配 mock_expired_token
3. `获取当前用户成功`（200）— 无条件（默认）

### 6.2 自定义 Mock 响应脚本（高级）

若需动态 Mock（如模拟"第 2 次 refresh 才成功"），可在 Apifox "高级 Mock → 自定义脚本"中编写：

```javascript
// POST /auth/refresh — 模拟偶发 refresh 失败
var attempt = parseInt(pm.environment.get("auth_attempt_count") || "0");
attempt++;
pm.environment.set("auth_attempt_count", attempt.toString());

if (attempt <= 1) {
  // 第 1 次 refresh 失败
  return {
    statusCode: 401,
    body: JSON.stringify({
      detail: "Refresh token 已过期，请重新登录"
    })
  };
}

// 第 2 次及以后 refresh 成功
return {
  statusCode: 200,
  body: JSON.stringify({
    status: "success",
    data: {
      access_token: pm.environment.get("mock_access_token"),
      refresh_token: pm.environment.get("mock_refresh_token"),
      token_type: "bearer",
      expires_in: 1800,
      user: {
        user_id: pm.environment.get("mock_user_id"),
        username: pm.environment.get("mock_username")
      }
    },
    meta: {
      request_id: "req-" + Math.random().toString(36).substring(2, 10),
      timestamp: new Date().toISOString()
    }
  })
};
```

> **用途**: 验证 Phase 6 的 `_onRefreshFailed()` → `sessionExpired` → Dialog → LoginScreen 链路在"中间件偶发失败"场景下是否正确。

### 6.3 环境变量预设

在 Apifox 环境管理中创建 `VidNexus Mock` 环境，预设变量：

| 变量名 | 值 | 用途 |
|--------|-----|------|
| `mock_user_id` | `user_mock_001` | 所有 Auth 接口共用 |
| `mock_username` | `vidnexus_user` | `/auth/me` 响应 |
| `mock_access_token` | `eyJ...mock_access_signature` | 模拟有效 JWT |
| `mock_refresh_token` | `eyJ...mock_refresh_signature` | 模拟有效 Refresh Token |
| `mock_expired_token` | `eyJ...mock_expired_signature` | 模拟过期 Token（exp=1000000000） |
| `auth_attempt_count` | `0` | 高级 Mock 脚本计数器 |

---

## 7. 与 Flutter 端的数据流对照

### 7.1 请求/响应字段映射

| Flutter DTO | JSON 字段 | 方向 | 接口 |
|-------------|----------|------|------|
| `RegisterRequest.username` | `username` | → | `POST /auth/register` |
| `RegisterRequest.password` | `password` | → | `POST /auth/register` |
| `LoginRequest.username` | `username` | → | `POST /auth/login` |
| `LoginRequest.password` | `password` | → | `POST /auth/login` |
| `LoginRequest.deviceId` | `device_id` | → | `POST /auth/login` |
| `RefreshRequest.refreshToken` | `refresh_token` | → | `POST /auth/refresh` |
| `RefreshRequest.deviceId` | `device_id` | → | `POST /auth/refresh` |
| `TokenResponseData.accessToken` | `access_token` | ← | `POST /auth/login`, `POST /auth/refresh` |
| `TokenResponseData.refreshToken` | `refresh_token` | ← | `POST /auth/login`, `POST /auth/refresh` |
| `TokenResponseData.tokenType` | `token_type` | ← | `POST /auth/login`, `POST /auth/refresh` |
| `TokenResponseData.expiresIn` | `expires_in` | ← | `POST /auth/login`, `POST /auth/refresh` |
| `TokenResponseData.user` | `user` | ← | `POST /auth/login`, `POST /auth/refresh` |
| `CurrentUserData.userId` | `user_id` | ← | 以上 + `GET /auth/me` |
| `CurrentUserData.username` | `username` | ← | 以上 + `GET /auth/me` |

### 7.2 SecureStorage 持久化

| Flutter Key | 值来源 | 写入时机 | 清除时机 |
|-------------|--------|---------|---------|
| `auth.access_token` | `TokenResponseData.accessToken` | `login()` / `tryRefresh()` 成功 | `logout()` / `_onRefreshFailed()` |
| `auth.refresh_token` | `TokenResponseData.refreshToken` | `login()` / `tryRefresh()` 成功 | `logout()` / `_onRefreshFailed()` |
| `auth.device_id` | `"flutter_" + uuid.v4()` | 首次 `_getOrCreateDeviceId()` | 不主动清除 |

### 7.3 AuthInterceptor Header 注入

```dart
// AuthInterceptor.onRequest
options.headers['Authorization'] = 'Bearer $accessToken';  // 从 state 或 SecureStorage 读取
options.headers['x-request-id'] = ApiClient.generateRequestId();  // req-a1b2c3d4
```

---

## 8. 验证清单

### 8.1 单接口验证

| 接口 | 期望数 | 验证项 |
|------|--------|--------|
| `POST /auth/register` | 4 | 正常注册 / 用户名冲突 409 / 弱密码 422 / 参数校验 422 |
| `POST /auth/login` | 4 | 正常登录 / 凭证错误 401 / 账号锁定 403 / 缺少字段 422 |
| `POST /auth/refresh` | 3 | 正常刷新 / Token 过期 401 / 设备不匹配 403 |
| `GET /auth/me` | 3 | Token 有效 / Token 过期 401 / 缺少 Header 401 |

### 8.2 端到端场景验证

| 场景 | 涉及接口 | Phase 6 状态 |
|------|---------|------------|
| A: 首次启动（无本地 Token） | 无 | ✅ 纯客户端 |
| B: Token 有效启动 | `GET /auth/me` | ✅ |
| C: Token 过期 → Refresh 成功 | `GET /auth/me` + `POST /auth/refresh` | ✅ |
| D: Token 过期 → Refresh 也过期 | `GET /auth/me` + `POST /auth/refresh` | ✅ |
| E: 运行时 401 | 任意需鉴权 API + `POST /auth/refresh` | ✅ |
| F: 正常登录 | `POST /auth/login` | ✅ |
| G: 登录失败 | `POST /auth/login` | ✅ |
| H: 正常注册 → 自动登录 | `POST /auth/register` + `POST /auth/login` | ✅ |
| I: 主动登出 | 无 | ✅ 纯客户端 |

---

## 9. 与 Phase 2 的关系

Phase 2 建立了 `AuthService`（4 个 API 调用方法）和对应的 3 个 DTO（`RegisterRequest`、`LoginRequest`、`RefreshRequest`、`TokenResponseData`、`CurrentUserData`）。本 Mock 方案的请求/响应结构与 Phase 2 的 DTO 严格对齐：

```
lib/services/models/auth_dto.dart   ←── 本 Mock 方案的响应 JSON 结构
lib/services/api/api_endpoints.dart  ←── 本 Mock 方案的 URL 路径
lib/features/auth/auth_service.dart  ←── 本 Mock 方案的调用方
```

Phase 6 在此基础上完善了认证闭环（`AuthGate`、`sessionExpired`、登出、Request ID），本 Mock 方案覆盖了这些新增行为的测试场景（场景 C/D/E）。

---

## 10. 关键决策

| 决策项 | 结论 | 理由 |
|--------|------|------|
| `/auth/refresh` 不校验 `Authorization` header | Mock 不做鉴权 | refresh 接口本身不接受 access token，只接受 refresh token |
| Token 用固定字符串而非真实 JWT | `eyJ...mock_signature` | Apifox Mock 不执行 JWT 验签，仅需字符串匹配 |
| `expired_token` 的 exp 设为 `1000000000` | UNIX 时间戳 2001-09-09 | 任何当前时间都会判定为过期 |
| 不模拟 Token 自动续期 | Mock 始终返回固定 `expires_in: 1800` | 简化 Mock 逻辑，前端不依赖 `expires_in` 做主动续期 |
| 409/422/401/403 错误均用 `{"detail": "..."}` 格式 | 无 `status` 字段 | 对齐 FastAPI HTTPException 默认响应格式 |
