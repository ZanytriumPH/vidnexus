import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/services/api/api_client.dart';
import 'package:vidnexus/services/models/video_qa_dto.dart';
import 'package:vidnexus/services/sse/sse_client.dart';
import 'package:vidnexus/services/sse/sse_models.dart';

/// 模拟 Dio stream 响应，用于测试 SSE 解析。
class FakeDioForSseTest with DioMixin implements Dio {
  Stream<Uint8List>? sseByteStream;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final stream = sseByteStream ?? Stream.value(Uint8List(0));
    final response = Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      headers: Headers.fromMap({
        'content-type': ['text/event-stream'],
      }),
    );
    // 使用 ResponseBody 设置流式数据
    response.data = ResponseBody(
      stream,
      200,
      headers: {
        'content-type': ['text/event-stream'],
      },
    ) as T;
    return response;
  }
}

/// 构造 SSE 字节流。
Stream<Uint8List> sseBytes(String text) =>
    Stream.value(Uint8List.fromList(utf8.encode(text)));

Stream<Uint8List> sseChunks(List<String> chunks) async* {
  for (final chunk in chunks) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    yield Uint8List.fromList(utf8.encode(chunk));
  }
}

void main() {
  late FakeDioForSseTest fakeDio;

  setUp(() {
    fakeDio = FakeDioForSseTest();
    ApiClient.reset();
    ApiClient.injectTestDio(fakeDio);
  });

  tearDown(() {
    ApiClient.reset();
  });

  // ──── SSE 事件解析 ────

  group('SSE event parsing', () {
    test('parses start event', () async {
      fakeDio.sseByteStream = sseBytes(
        'event: start\n'
        'data: {"task_id":"task_001","qa_id":"qa_001","timestamp":"2026-05-23T10:00:00Z"}\n'
        '\n',
      );

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, hasLength(1));
      expect(events[0].type, SSEEventType.start);
      final startData = events[0].parseData(TimeTravelQAStartData.fromJson);
      expect(startData?.taskId, 'task_001');
      expect(startData?.qaId, 'qa_001');
    });

    test('parses delta event', () async {
      fakeDio.sseByteStream = sseBytes(
        'event: delta\n'
        'data: {"task_id":"task_001","qa_id":"qa_001","chunk":"这是","sequence":1}\n'
        '\n',
      );

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, hasLength(1));
      expect(events[0].type, SSEEventType.delta);
      final deltaData = events[0].parseData(SSEDeltaData.fromJson);
      expect(deltaData?.chunk, '这是');
      expect(deltaData?.sequence, 1);
    });

    test('parses done event', () async {
      fakeDio.sseByteStream = sseBytes(
        'event: done\n'
        'data: {"task_id":"task_001","qa_id":"qa_001","answer_content":"完整答案"}\n'
        '\n',
      );

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, hasLength(1));
      expect(events[0].type, SSEEventType.done);
      final doneData = events[0].parseData(TimeTravelQADoneData.fromJson);
      expect(doneData?.answerContent, '完整答案');
    });

    test('parses error event', () async {
      fakeDio.sseByteStream = sseBytes(
        'event: error\n'
        'data: {"message":"Something went wrong"}\n'
        '\n',
      );

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, hasLength(1));
      expect(events[0].type, SSEEventType.error);
    });

    test('parses stream: start → delta×2 → done', () async {
      fakeDio.sseByteStream = sseChunks([
        'event: start\n'
            'data: {"task_id":"t1","qa_id":"q1"}\n'
            '\n',
        'event: delta\n'
            'data: {"task_id":"t1","qa_id":"q1","chunk":"Hello","sequence":1}\n'
            '\n',
        'event: delta\n'
            'data: {"task_id":"t1","qa_id":"q1","chunk":" World","sequence":2}\n'
            '\n',
        'event: done\n'
            'data: {"task_id":"t1","qa_id":"q1","answer_content":"Hello World"}\n'
            '\n',
      ]);

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, hasLength(4));
      expect(events[0].type, SSEEventType.start);
      expect(events[1].type, SSEEventType.delta);
      expect(events[2].type, SSEEventType.delta);
      expect(events[3].type, SSEEventType.done);

      final chunks = [
        events[1].parseData(SSEDeltaData.fromJson)!.chunk,
        events[2].parseData(SSEDeltaData.fromJson)!.chunk,
      ];
      expect(chunks.join(), 'Hello World');

      final doneData = events[3].parseData(TimeTravelQADoneData.fromJson);
      expect(doneData?.answerContent, 'Hello World');
    });

    test('ignores unknown event types', () async {
      fakeDio.sseByteStream = sseBytes(
        'event: ping\n'
        'data: {"ts":123}\n'
        '\n',
      );

      final events = await SseClient.instance
          .connect('/test')
          .toList();

      expect(events, isEmpty);
    });
  });

  // ──── TimeTravelQAStreamRequest 序列化 ────

  group('TimeTravelQAStreamRequest serialization', () {
    test('toJson includes all required fields', () {
      const req = TimeTravelQAStreamRequest(
        timestamp: '00:10:00',
        questionContent: '这段讲什么？',
      );
      final json = req.toJson();

      expect(json['timestamp'], '00:10:00');
      expect(json['question_content'], '这段讲什么？');
      expect(json['attachments'], []);
      expect(json.containsKey('window_seconds'), isFalse);
    });

    test('toJson includes window_seconds when set', () {
      const req = TimeTravelQAStreamRequest(
        timestamp: '00:10:00',
        questionContent: '这段讲什么？',
        windowSeconds: 60,
      );
      final json = req.toJson();

      expect(json['window_seconds'], 60);
    });

    test('toJson includes attachments', () {
      const req = TimeTravelQAStreamRequest(
        timestamp: '00:10:00',
        questionContent: '这段讲什么？',
        attachments: [
          AttachmentInfo(
            name: 'screenshot.png',
            ossKey: 'att/abc.png',
            mimeType: 'image/png',
            sizeBytes: 1024,
          ),
        ],
      );
      final json = req.toJson();

      final atts = json['attachments'] as List;
      expect(atts, hasLength(1));
      expect((atts[0] as Map)['oss_key'], 'att/abc.png');
    });
  });

  // ──── Global QA SSE 载荷 ────

  group('Global QA SSE payloads', () {
    test('GlobalQAStartData parses correctly', () {
      final json = {
        'kbid': 'kb_001',
        'chat_id': 'chat_001',
        'qa_id': 'gqa_001',
        'timestamp': '2026-05-23T10:00:00Z',
      };

      final data = GlobalQAStartData.fromJson(json);
      expect(data.kbid, 'kb_001');
      expect(data.chatId, 'chat_001');
      expect(data.qaId, 'gqa_001');
    });

    test('GlobalQADoneData parses with cited_sources', () {
      final json = {
        'kbid': 'kb_001',
        'chat_id': 'chat_001',
        'qa_id': 'gqa_001',
        'answer_content': '对比结果...',
        'cited_sources': [
          {'video_id': 'vid_001', 'quote': '...'},
        ],
      };

      final data = GlobalQADoneData.fromJson(json);
      expect(data.answerContent, '对比结果...');
      expect(data.citedSources, hasLength(1));
      expect(data.citedSources![0]['video_id'], 'vid_001');
    });
  });
}
