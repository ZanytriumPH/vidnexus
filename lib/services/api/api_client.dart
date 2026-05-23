import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';
import 'error_interceptor.dart';

/// Dio 单例工厂，统一管理 baseUrl、超时、拦截器。
///
/// 拦截器链（按顺序）：
///   1. LogInterceptor（仅 Debug 模式）
///   2. ErrorInterceptor（统一错误日志与状态映射）
///   3. AuthInterceptor（需在 auth controller 初始化后通过 [injectAuthInterceptor] 注入）
class ApiClient {
  ApiClient._();

  static Dio? _instance;
  static final ApiConfig _config = ApiConfig();
  static ErrorInterceptor? _errorInterceptor;
  static Interceptor? _authInterceptor;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  /// 获取 ApiConfig 实例（用于运行时修改 baseUrl 等）。
  static ApiConfig get config => _config;

  /// 仅用于测试或切换环境时重建实例。
  static void reset() {
    _instance = null;
    _errorInterceptor = null;
    _authInterceptor = null;
  }

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        // 编译期默认值；运行时可通过 ApiConfig 覆盖
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: ApiConfig.defaultBaseUrl,
        ),
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Debug 日志拦截器
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }

    // 2. 统一错误拦截器（在 AuthInterceptor 之前注册）
    _errorInterceptor = ErrorInterceptor();
    dio.interceptors.add(_errorInterceptor!);

    // 3. AuthInterceptor 在 auth controller 初始化后动态注入，
    //    避免循环依赖。见 [injectAuthInterceptor]。

    return dio;
  }

  /// 注入 AuthInterceptor（须在拿到 token 之后调用一次）。
  ///
  /// 重复调用安全——会先移除旧的 AuthInterceptor。
  static void injectAuthInterceptor(Interceptor interceptor) {
    removeAuthInterceptor();
    _authInterceptor = interceptor;
    instance.interceptors.add(interceptor);
  }

  /// 移除当前注入的 AuthInterceptor。
  static void removeAuthInterceptor() {
    if (_authInterceptor != null) {
      instance.interceptors.remove(_authInterceptor);
      _authInterceptor = null;
    }
  }

  /// 更新运行时 baseUrl（同步 Dio BaseOptions + 通知 ApiConfig）。
  static Future<void> updateBaseUrl(String url) async {
    final dio = instance;
    dio.options.baseUrl = url;
    await _config.persistBaseUrl(url);
  }

  /// 从 ApiConfig 恢复 baseUrl（通常在 App 启动时调用）。
  static Future<void> restoreBaseUrl() async {
    final url = await _config.baseUrl;
    final dio = instance;
    dio.options.baseUrl = url;
  }

  /// 生成请求追踪 ID。
  static String generateRequestId() => _config.generateRequestId();

  /// 仅用于测试：注入外部 Dio 实例替代内部单例。
  ///
  /// 调用后 [instance] 返回注入的 Dio。测试结束后应调用 [reset] 清理。
  static void injectTestDio(Dio dio) {
    _instance = dio;
  }
}

/// 安全存储单例，供 auth 层持久化 token。
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
