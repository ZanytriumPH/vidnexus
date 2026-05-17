import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../services/api/api_client.dart';
import '../../services/api/auth_interceptor.dart';
import '../../services/models/auth_dto.dart';
import '../../services/models/common_dto.dart';
import 'auth_service.dart';
import 'auth_state.dart';

/// Secure storage keys。
const _kAccessToken = 'auth.access_token';
const _kRefreshToken = 'auth.refresh_token';
const _kDeviceId = 'auth.device_id';

/// AuthService provider。
final authServiceProvider = Provider<AuthService>((ref) => const AuthService());

/// Auth state provider。
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  late final AuthService _authService;
  final _uuid = const Uuid();

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    // 启动时尝试恢复登录态
    _restoreSession();
    return const AuthState(isLoading: true);
  }

  // ---- public API ----

  /// 注册。
  Future<void> register(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _authService.register(
        username: username,
        password: password,
      );
      if (resp.status == 'success' && resp.data != null) {
        // 注册成功后自动登录
        await login(username, password);
      }
    } on DioException catch (e) {
      _handleError(e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 登录。
  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deviceId = await _getOrCreateDeviceId();
      final resp = await _authService.login(
        username: username,
        password: password,
        deviceId: deviceId,
      );
      if (resp.status == 'success' && resp.data != null) {
        await _persistTokens(resp.data!);
        _injectAuthInterceptor();
        state = AuthState(
          isLoggedIn: true,
          accessToken: resp.data!.accessToken,
          refreshToken: resp.data!.refreshToken,
          currentUser: resp.data!.user,
        );
      }
    } on DioException catch (e) {
      _handleError(e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 登出。
  ///
  /// [isSessionExpired] 为 true 时表示因 token 过期被动登出，
  /// 此时会设置 sessionExpired 标志，供 UI 层弹出提示。
  Future<void> logout({bool isSessionExpired = false}) async {
    await secureStorage.delete(key: _kAccessToken);
    await secureStorage.delete(key: _kRefreshToken);
    // 不清除 deviceId，保留用于下次登录
    _clearAuthInterceptor();
    state = AuthState(sessionExpired: isSessionExpired);
  }

  /// 静默刷新 token（供 AuthInterceptor 回调）。
  Future<bool> tryRefresh() async {
    try {
      final refreshToken =
          await secureStorage.read(key: _kRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        await _onRefreshFailed();
        return false;
      }

      final deviceId = await _getOrCreateDeviceId();
      final resp = await _authService.refresh(
        refreshToken: refreshToken,
        deviceId: deviceId,
      );
      if (resp.status == 'success' && resp.data != null) {
        await _persistTokens(resp.data!);
        state = state.copyWith(
          isLoggedIn: true,
          accessToken: resp.data!.accessToken,
          refreshToken: resp.data!.refreshToken,
          currentUser: resp.data!.user,
        );
        return true;
      }
    } on DioException {
      // refresh 失败，清除登录态
    }
    await _onRefreshFailed();
    return false;
  }

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

  Future<void> _onRefreshFailed() async {
    await secureStorage.delete(key: _kAccessToken);
    await secureStorage.delete(key: _kRefreshToken);
    _clearAuthInterceptor();
    state = state.copyWith(isLoggedIn: false, sessionExpired: true);
  }

  /// 清除错误信息。
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ---- private ----

  Future<void> _restoreSession() async {
    // 注意：不在 build() 同步阶段读取 state；isLoading: true 已由 build() 返回值设置。
    try {
      final accessToken = await secureStorage.read(key: _kAccessToken);
      final refreshToken = await secureStorage.read(key: _kRefreshToken);

      if (accessToken == null || accessToken.isEmpty) {
        state = const AuthState();
        return;
      }

      // 先用存储的 token 尝试验证
      state = state.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      _injectAuthInterceptor();

      final resp = await _authService.me();
      if (resp.status == 'success' && resp.data != null) {
        state = AuthState(
          isLoggedIn: true,
          accessToken: accessToken,
          refreshToken: refreshToken,
          currentUser: resp.data,
        );
      } else {
        // token 无效，尝试 refresh
        // tryRefresh 内部已通过 _onRefreshFailed 处理失败情况，
        // 此处不再额外调用 logout，避免覆盖 sessionExpired 状态。
        await tryRefresh();
      }
    } on DioException {
      // 网络不可达时，如果本地有 token 就保持乐观登录
      final accessToken = await secureStorage.read(key: _kAccessToken);
      if (accessToken != null && accessToken.isNotEmpty) {
        state = AuthState(
          isLoggedIn: true,
          accessToken: accessToken,
          refreshToken: await secureStorage.read(key: _kRefreshToken),
          // 无用户信息，需要触发 /me
        );
      } else {
        state = const AuthState();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _persistTokens(TokenResponseData data) async {
    await secureStorage.write(key: _kAccessToken, value: data.accessToken);
    await secureStorage.write(key: _kRefreshToken, value: data.refreshToken);
  }

  Future<String> _getOrCreateDeviceId() async {
    var deviceId = await secureStorage.read(key: _kDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'flutter_${_uuid.v4()}';
      await secureStorage.write(key: _kDeviceId, value: deviceId);
    }
    return deviceId;
  }

  void _injectAuthInterceptor() {
    ApiClient.injectAuthInterceptor(
      AuthInterceptor(
        getAccessToken: () async =>
            state.accessToken ?? await secureStorage.read(key: _kAccessToken),
        onRefreshFailed: () => _onRefreshFailed(),
        tryRefresh: tryRefresh,
      ),
    );
  }

  void _clearAuthInterceptor() {
    ApiClient.removeAuthInterceptor();
  }

  void _handleError(DioException e) {
    final apiError = ApiError.fromDioException(e);
    state = state.copyWith(
      isLoading: false,
      errorMessage: apiError.userMessage,
    );
  }
}
