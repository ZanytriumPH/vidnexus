/// Auth 域请求/响应 DTO，与 backend/auth/models.py 及 schemas 对齐。
library;

class RegisterRequest {
  const RegisterRequest({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

class LoginRequest {
  const LoginRequest({
    required this.username,
    required this.password,
    required this.deviceId,
  });

  final String username;
  final String password;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'device_id': deviceId,
      };
}

class RefreshRequest {
  const RefreshRequest({
    required this.refreshToken,
    required this.deviceId,
  });

  final String refreshToken;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
        'device_id': deviceId,
      };
}

class CurrentUserData {
  const CurrentUserData({
    required this.userId,
    required this.username,
  });

  final String userId;
  final String username;

  factory CurrentUserData.fromJson(Map<String, dynamic> json) {
    return CurrentUserData(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
      };
}

class TokenResponseData {
  const TokenResponseData({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final CurrentUserData user;

  factory TokenResponseData.fromJson(Map<String, dynamic> json) {
    return TokenResponseData(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 1800,
      user: CurrentUserData.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
