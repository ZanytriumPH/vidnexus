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
    return const AuthState();
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
  Future<void> logout() async {
    await secureStorage.delete(key: _kAccessToken);
    await secureStorage.delete(key: _kRefreshToken);
    // 不清除 deviceId，保留用于下次登录
    _clearAuthInterceptor();
    state = const AuthState();
  }

  /// 静默刷新 token（供 AuthInterceptor 回调）。
  Future<bool> tryRefresh() async {
    try {
      final refreshToken =
          await secureStorage.read(key: _kRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) return false;

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
    return false;
  }

  /// 清除错误信息。
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ---- private ----

  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true);
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
        final refreshed = await tryRefresh();
        if (!refreshed) {
          await logout();
        }
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
    final dio = ApiClient.instance;
    // 清除旧的 interceptor
    dio.interceptors.removeWhere((i) => i is AuthInterceptor);
    dio.interceptors.add(
      AuthInterceptor(
        getAccessToken: () async =>
            state.accessToken ?? await secureStorage.read(key: _kAccessToken),
        onRefreshFailed: logout,
        tryRefresh: tryRefresh,
      ),
    );
  }

  void _clearAuthInterceptor() {
    ApiClient.instance.interceptors.removeWhere((i) => i is AuthInterceptor);
  }

  void _handleError(DioException e) {
    final apiError = ApiError.fromDioException(e);
    state = state.copyWith(
      isLoading: false,
      errorMessage: apiError.userMessage,
    );
  }
}
