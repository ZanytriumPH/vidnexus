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

  /// 最后一次收到 pong 响应（或任何有效后端消息）的时间。
  /// 初始化为当前时间，避免首次 ping 因未初始化而立即判定超时。
  DateTime _lastPongTime = DateTime.now();

  /// 连续未收到 pong 响应的次数。
  int _pongMissCount = 0;

  /// pong 响应超时检测 Timer。
  Timer? _pongTimeoutTimer;

  /// 连接就绪 Completer，connect() 成功后 resolve，断开后重置。
  Completer<void>? _connectedCompleter;

  /// 当前连接状态。
  WsConnectionState get state => _state;

  /// 最后收到的 sequence 号（用于重连确认）。
  int get lastSequence => _lastSequence;

  final _eventController = StreamController<WSEventEnvelope>.broadcast();

  /// 暴露 WS 事件流（后端推送的业务事件）。
  Stream<WSEventEnvelope> get eventStream => _eventController.stream;

  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  /// 连接状态变更流（客户端生成的内部事件）。
  /// 在 [connected]、[disconnected]、[reconnecting] 时 emit，
  /// [connecting] 不 emit（它是瞬时过渡态）。
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// 上次 emit 的连接状态，用于去重。
  WsConnectionState? _lastEmittedState;

  static const _maxReconnectDelaySeconds = 30;
  static const _heartbeatIntervalSeconds = 30;
  static const _pongTimeoutSeconds = 10;
  static const _maxPongMissCount = 3;

  /// 确保 WebSocket 已连接，可选超时。
  ///
  /// 如果已经处于 connected 状态，立即返回。
  /// 如果正在连接中，等待连接完成。
  /// 如果断开，触发连接并等待。
  Future<void> ensureConnected({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == WsConnectionState.connected) {
      return;
    }

    // 如果已有等待中的 Completer，复用
    if (_connectedCompleter != null && !_connectedCompleter!.isCompleted) {
      return _connectedCompleter!.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('WebSocket 连接超时（${timeout.inSeconds}s）'),
      );
    }

    _connectedCompleter = Completer<void>();
    connect(); // 不等待，让 connect() 内部在成功时 resolve Completer

    return _connectedCompleter!.future.timeout(
      timeout,
      onTimeout: () {
        _connectedCompleter = null;
        throw TimeoutException('WebSocket 连接超时（${timeout.inSeconds}s）');
      },
    );
  }

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

      // /vapi → /vws（nginx 为 API 和 WebSocket 分配了不同前缀）
      final wsBase = baseUrl.replaceFirst('/vapi', '/vws');
      String wsUrl = '$wsBase/ws/progress';
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

      debugPrint('[WS] Connecting to: $uri');
      _channel = WebSocketChannel.connect(uri);
      _state = WsConnectionState.connected;
      _reconnectAttempts = 0;
      _lastPongTime = DateTime.now();
      _pongMissCount = 0;

      // 通知等待者连接已就绪
      if (_connectedCompleter != null && !_connectedCompleter!.isCompleted) {
        _connectedCompleter!.complete();
      }

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startHeartbeat();
      _emitConnectionState(WsConnectionState.connected);
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _state = WsConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  /// 发送连接状态变更事件，自动去重。
  void _emitConnectionState(WsConnectionState newState) {
    if (_lastEmittedState == newState) return;
    _lastEmittedState = newState;
    _connectionStateController.add(newState);
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

      // 服务端心跳 pong 是纯文本，非 JSON
      if (text == 'pong') {
        debugPrint('[WS] Received pong');
        _lastPongTime = DateTime.now();
        _pongMissCount = 0;
        return;
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final event = WSEventEnvelope.fromJson(json);
      _lastSequence = event.sequence;

      // 收到任何有效的后端消息都视为连接存活
      _lastPongTime = DateTime.now();
      _pongMissCount = 0;

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
    // 重置连接 Completer，以便下次 ensureConnected 能重新等待
    if (_connectedCompleter != null && !_connectedCompleter!.isCompleted) {
      _connectedCompleter = null;
    }
    _emitConnectionState(WsConnectionState.disconnected);
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
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _sendPing() {
    try {
      _channel?.sink.add('ping');
    } catch (_) {
      // 连接已断开，忽略
      return;
    }

    // 记录 ping 发送时间，用于 pong 超时检测
    final pingSentTime = DateTime.now();
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = Timer(const Duration(seconds: _pongTimeoutSeconds), () {
      if (_lastPongTime.isBefore(pingSentTime)) {
        _pongMissCount++;
        debugPrint(
          '[WS] Pong timeout (miss $_pongMissCount/$_maxPongMissCount)',
        );
        if (_pongMissCount >= _maxPongMissCount) {
          debugPrint('[WS] Connection declared dead — triggering reconnect');
          _disconnectInternal();
          _scheduleReconnect();
        }
      }
    });
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
    _emitConnectionState(WsConnectionState.reconnecting);

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

  /// 释放资源。
  ///
  /// 关闭所有流控制器和定时器。调用后此实例不应再使用。
  void dispose() {
    _cancelReconnect();
    _stopHeartbeat();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _state = WsConnectionState.disconnected;
    _connectedCompleter = null;
    _eventController.close();
    _connectionStateController.close();
  }
}
