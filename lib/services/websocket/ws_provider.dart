import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/auth_controller.dart';
import '../api/api_client.dart';
import 'ws_client.dart';
import 'ws_models.dart';

/// WebSocket 事件流 Provider。
///
/// 自动跟随登录态：登录后自动连接，登出后自动断开。
/// 监听 AuthController 的 [AuthState.isLoggedIn] 驱动生命周期。
final wsEventProvider = StreamProvider<WSEventEnvelope?>((ref) {
  final authState = ref.watch(authControllerProvider);

  if (!authState.isLoggedIn) {
    return const Stream.empty();
  }

  final wsClient = ref.watch(wsClientProvider);
  final controller = StreamController<WSEventEnvelope?>();

  // 订阅 WS 事件，转发到 Riverpod StreamProvider
  final subscription = wsClient.eventStream.listen(
    (event) => controller.add(event),
    onError: (e) => controller.addError(e),
  );

  // 建立连接（不 await，让 StreamProvider 尽早返回 stream；
  // 调用方通过 wsClient.ensureConnected() 等待就绪）
  wsClient.connect();

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
    wsClient.disconnect();
  });

  return controller.stream;
});

/// 确保 WebSocket 已连接的 Future Provider。
///
/// 在需要 WebSocket 就绪后才能进行的操作前 await 此 provider。
final wsReadyProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (!authState.isLoggedIn) {
    throw StateError('用户未登录，无法建立 WebSocket 连接');
  }

  // 触发 wsEventProvider 保持活跃（从而建立连接）
  ref.listen(wsEventProvider, (prev, next) {});

  final wsClient = ref.read(wsClientProvider);
  await wsClient.ensureConnected(timeout: const Duration(seconds: 10));
});

/// WebSocket 客户端 Provider。
final wsClientProvider = Provider<WsClient>((ref) {
  final baseUrl = ApiClient.config.baseUrlSync;

  Future<String?> tokenProvider() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return storage.read(key: 'auth.access_token');
  }

  return WsClient(
    baseUrl: baseUrl,
    tokenProvider: tokenProvider,
    onAuthFailure: () {
      // token 鉴权失败 → 触发会话过期登出
      ref.read(authControllerProvider.notifier).expireSession();
    },
  );
});
