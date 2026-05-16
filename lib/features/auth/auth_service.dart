import 'package:dio/dio.dart';

import '../../services/api/api_client.dart';
import '../../services/api/api_endpoints.dart';
import '../../services/models/auth_dto.dart';
import '../../services/models/common_dto.dart';

/// 封装 4 个 auth API 调用。
class AuthService {
  const AuthService();

  Dio get _dio => ApiClient.instance;

  /// 注册。
  Future<ApiResponse<CurrentUserData>> register({
    required String username,
    required String password,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.authRegister,
      data: RegisterRequest(username: username, password: password).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      CurrentUserData.fromJson,
    );
  }

  /// 登录。
  Future<ApiResponse<TokenResponseData>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.authLogin,
      data: LoginRequest(
        username: username,
        password: password,
        deviceId: deviceId,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      TokenResponseData.fromJson,
    );
  }

  /// 刷新 token。
  Future<ApiResponse<TokenResponseData>> refresh({
    required String refreshToken,
    required String deviceId,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.authRefresh,
      data: RefreshRequest(
        refreshToken: refreshToken,
        deviceId: deviceId,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      TokenResponseData.fromJson,
    );
  }

  /// 获取当前用户信息。
  Future<ApiResponse<CurrentUserData>> me() async {
    final resp = await _dio.get(ApiEndpoints.authMe);
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      CurrentUserData.fromJson,
    );
  }
}
