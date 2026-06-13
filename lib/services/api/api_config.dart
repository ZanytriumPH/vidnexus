/// API 运行时配置，支持通过 SecureStorage 持久化和运行时覆盖。
///
/// 优先级：运行时设置 > SecureStorage 持久化 > 编译期环境变量 > 默认值
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class ApiConfig {
  ApiConfig({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _keyBaseUrl = 'api_config_base_url';

  /// 默认 baseUrl（Android 模拟器 → 宿主机 localhost）。
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  // ---- baseUrl ----

  String? _overriddenBaseUrl;

  /// 获取当前有效的 baseUrl（异步版本）。
  ///
  /// 优先级：运行时覆盖 > SecureStorage > 编译期环境变量 > 默认值。
  Future<String> get baseUrl async {
    if (_overriddenBaseUrl != null) return _overriddenBaseUrl!;
    final stored = await _storage.read(key: _keyBaseUrl);
    if (stored != null && stored.isNotEmpty) return stored;
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultBaseUrl,
    );
  }

  /// 获取当前有效的 baseUrl（同步版本）。
  ///
  /// 仅返回运行时覆盖或默认值，不访问 SecureStorage。
  String get baseUrlSync {
    if (_overriddenBaseUrl != null) return _overriddenBaseUrl!;
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultBaseUrl,
    );
  }

  /// 运行时覆盖 baseUrl（仅内存，不持久化）。
  void setBaseUrlOverride(String url) {
    _overriddenBaseUrl = url;
  }

  /// 清除运行时覆盖，回退到持久化/默认值。
  void clearBaseUrlOverride() {
    _overriddenBaseUrl = null;
  }

  /// 持久化 baseUrl 到 SecureStorage。
  Future<void> persistBaseUrl(String url) async {
    await _storage.write(key: _keyBaseUrl, value: url);
  }

  /// 清除持久化的 baseUrl。
  Future<void> clearPersistedBaseUrl() async {
    await _storage.delete(key: _keyBaseUrl);
  }

  // ---- request-id ----

  /// 生成请求追踪 ID，格式：req-{uuid_short}。
  String generateRequestId() {
    return 'req-${const Uuid().v4().substring(0, 8)}';
  }

  // ---- timeout ----

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 45);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ---- polling ----

  /// 默认轮询间隔。
  static const Duration defaultPollingInterval = Duration(seconds: 2);

  /// 默认轮询超时。
  static const Duration defaultPollingTimeout = Duration(minutes: 5);

  /// QA 轮询超时。
  static const Duration qaPollingTimeout = Duration(seconds: 60);
}
