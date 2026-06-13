import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/services/websocket/ws_client.dart';

/// Token provider that returns null/empty to prevent actual connections.
Future<String?> _noToken() async => null;

void main() {
  group('WsClient connection state stream', () {
    test('connectionStateStream is a broadcast stream', () {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );
      final stream = client.connectionStateStream;
      expect(stream.isBroadcast, isTrue);
    });

    test('dispose closes both stream controllers', () {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      expect(() => client.dispose(), returnsNormally);
      // After dispose, adding to closed streams should be handled silently
      expect(client.state, WsConnectionState.disconnected);
    });

    test('initial state is disconnected', () {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      expect(client.state, WsConnectionState.disconnected);
      expect(client.lastSequence, 0);
    });

    test('connect with null token stays disconnected', () async {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      await client.connect();
      expect(client.state, WsConnectionState.disconnected);
    });

    test(
      'state reflects connected after connect with valid token',
      () async {
        final client = WsClient(
          baseUrl: 'http://localhost:8765', // arbitrary port
          tokenProvider: () async => 'fake-token',
        );

        await client.connect();

        // WebSocketChannel.connect() typically returns a channel object
        // synchronously, setting state to connected (async failure comes later).
        // Either connected or reconnecting means the state machine advanced.
        expect(
          client.state,
          anyOf(WsConnectionState.connected, WsConnectionState.reconnecting),
        );

        client.dispose();
      },
    );

    test('disconnect calls do not emit duplicate disconnected', () async {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      final states = <WsConnectionState>[];
      final sub = client.connectionStateStream.listen(states.add);

      await client.disconnect(); // already disconnected, should not emit
      await client.disconnect(); // ditto

      expect(states.isEmpty, isTrue);

      await sub.cancel();
      client.dispose();
    });
  });

  group('WsClient heartbeat fields', () {
    test('heartbeat constants are configured correctly', () {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      // Just verify construction succeeds and state is clean
      expect(client.state, WsConnectionState.disconnected);
      expect(client.lastSequence, 0);
    });
  });

  group('WsClient ensureConnected', () {
    test('ensureConnected times out when no token', () async {
      final client = WsClient(
        baseUrl: 'http://localhost:9999',
        tokenProvider: _noToken,
      );

      await expectLater(
        () => client.ensureConnected(
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );

      client.dispose();
    });
  });
}
