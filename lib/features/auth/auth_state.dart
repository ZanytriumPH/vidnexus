import '../../services/models/auth_dto.dart';

/// Auth 领域的状态数据类，由 AuthController 管理。
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.accessToken,
    this.refreshToken,
    this.currentUser,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isLoggedIn;
  final String? accessToken;
  final String? refreshToken;
  final CurrentUserData? currentUser;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
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
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
