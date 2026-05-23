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

  // 建立连接
  wsClient.connect();

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
    wsClient.disconnect();
  });

  return controller.stream;
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
