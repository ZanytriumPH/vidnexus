import '../../services/models/auth_dto.dart';

/// Auth 领域的状态数据类，由 AuthController 管理。
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.sessionExpired = false,
    this.accessToken,
    this.refreshToken,
    this.currentUser,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isLoggedIn;

  /// 当 refresh token 失败或 401 无法恢复时置为 true，
  /// 供 AuthGate 层弹出"登录已过期"提示并跳转登录页。
  final bool sessionExpired;

  final String? accessToken;
  final String? refreshToken;
  final CurrentUserData? currentUser;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    bool? sessionExpired,
    String? accessToken,
    String? refreshToken,
    CurrentUserData? currentUser,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
