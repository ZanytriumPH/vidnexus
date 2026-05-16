import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dio 单例工厂，统一管理 baseUrl、超时、拦截器。
class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  /// 仅用于测试或切换环境时重建实例。
  static void reset() {
    _instance = null;
  }

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        // TODO: 从环境配置读取，当前使用 Android 模拟器默认地址
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000',
        ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }

    // AuthInterceptor 在 auth controller 初始化后动态注入，
    // 避免循环依赖。
    return dio;
  }
}

/// 安全存储单例，供 auth 层持久化 token。
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
