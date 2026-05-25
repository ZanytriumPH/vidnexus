import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_models.dart';

/// WebSocket 连接状态。
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket 客户端，管理与 /ws/progress 的连接（new.md 新增）。
///
/// 特性：
/// - JWT token 鉴权（query parameter）
/// - 自动重连（exponential backoff: 1s→2s→4s→…→30s 上限）
/// - 心跳 ping（每 30s）
/// - 鉴权失败处理（close code 4001）
class WsClient {
  WsClient({
    required this.baseUrl,
    required Future<String?> Function() tokenProvider,
    this.onAuthFailure,
  }) : _tokenProvider = tokenProvider;

  final String baseUrl;
  final Future<String?> Function() _tokenProvider;
  final VoidCallback? onAuthFailure;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription<dynamic>? _subscription;

  WsConnectionState _state = WsConnectionState.disconnected;
  int _reconnectAttempts = 0;
  int _lastSequence = 0;

  /// 当前连接状态。
  WsConnectionState get state => _state;

  /// 最后收到的 sequence 号（用于重连确认）。
  int get lastSequence => _lastSequence;

  final _eventController = StreamController<WSEventEnvelope>.broadcast();

  /// 暴露 WS 事件流。
  Stream<WSEventEnvelope> get eventStream => _eventController.stream;

  static const _maxReconnectDelaySeconds = 30;
  static const _heartbeatIntervalSeconds = 30;

  /// 建立连接。
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _state = WsConnectionState.connecting;
    _cancelReconnect();

    try {
      final token = await _tokenProvider();
      if (token == null || token.isEmpty) {
        _state = WsConnectionState.disconnected;
        return;
      }

      String wsUrl = '$baseUrl/ws/progress';
      if (wsUrl.startsWith('https://')) {
        wsUrl = wsUrl.replaceFirst('https://', 'wss://');
      } else if (wsUrl.startsWith('http://')) {
        wsUrl = wsUrl.replaceFirst('http://', 'ws://');
      }

      final uri = Uri.parse(wsUrl).replace(
        queryParameters: {
          'token': token,
          if (_lastSequence > 0) 'last_sequence': _lastSequence.toString(),
        },
      );

      _channel = WebSocketChannel.connect(uri);
      _state = WsConnectionState.connected;
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startHeartbeat();
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _state = WsConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  /// 断开连接。
  Future<void> disconnect() async {
    _cancelReconnect();
    _stopHeartbeat();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _state = WsConnectionState.disconnected;
  }

  void _onMessage(dynamic message) {
    try {
      final text = message as String;

      // 服务端心跳 pong 是纯文本，非 JSON，直接忽略
      if (text == 'pong') {
        debugPrint('[WS] Received pong');
        return;
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final event = WSEventEnvelope.fromJson(json);
      _lastSequence = event.sequence;

      if (event.eventType == WSEventType.reconnectAck) {
        debugPrint('[WS] Reconnect acknowledged, seq=${event.sequence}');
      }

      _eventController.add(event);
    } catch (e) {
      debugPrint('[WS] Failed to parse message: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Error: $error');
    final closeCode = _extractCloseCode(error);

    if (closeCode == 4001) {
      // 鉴权失败
      debugPrint('[WS] Auth failed (4001), triggering logout');
      onAuthFailure?.call();
      _disconnectInternal();
      return;
    }

    _disconnectInternal();
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connection closed');
    _disconnectInternal();
    if (_state != WsConnectionState.disconnected) {
      _scheduleReconnect();
    }
  }

  void _disconnectInternal() {
    _stopHeartbeat();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _state = WsConnectionState.disconnected;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) => _sendPing(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendPing() {
    try {
      _channel?.sink.add('ping');
    } catch (_) {
      // 连接已断开，忽略
    }
  }

  void _scheduleReconnect() {
    _cancelReconnect();
    _reconnectAttempts++;
    final delay = min(
      pow(2, _reconnectAttempts - 1).toInt(),
      _maxReconnectDelaySeconds,
    );
    debugPrint('[WS] Reconnecting in ${delay}s (attempt $_reconnectAttempts)');
    _state = WsConnectionState.reconnecting;

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 从异常中提取 close code（如果可用）。
  int? _extractCloseCode(dynamic error) {
    if (error is WebSocketChannelException) {
      // WebSocketChannelException 的 message 可能包含 close code 信息
      final msg = error.message ?? '';
      final match = RegExp(r'(\d{4})').firstMatch(msg);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }
    return null;
  }
}
