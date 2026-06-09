import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import 'sse_models.dart';

/// SSE（Server-Sent Events）客户端，基于 Dio 的 ResponseType.stream 解析 text/event-stream。
///
/// 使用方式：
/// ```dart
/// final stream = SseClient.instance.connect(
///   '/api/v1/tasks/task_001/time-travel-qa/stream',
///   data: request.toJson(),
/// );
/// await for (final event in stream) {
///   // 处理 start / delta / done / error 事件
/// }
/// ```
class SseClient {
  const SseClient._();

  static const SseClient instance = SseClient._();

  Dio get _dio => ApiClient.instance;

  /// 连接 SSE 端点并返回事件流。
  ///
  /// [path] 为 API 路径，[data] 为 POST 请求体。
  /// 内部使用 [ResponseType.stream] 接收流式响应。
  Stream<SSEEvent> connect(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      path,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          if (headers != null) // ignore: use_null_aware_elements
            ...headers,
        },
      ),
    );

    final stream = response.data!.stream;
    final lineStream = _toLines(stream.cast<List<int>>());

    String? currentEvent;
    StringBuffer? currentData;

    await for (final line in lineStream) {
      final trimmed = line.trimRight();

      if (trimmed.isEmpty) {
        // 空行 = 事件结束，dispatch
        if (currentData != null && currentData.isNotEmpty) {
          final event = _dispatch(currentEvent, currentData.toString().trim());
          if (event != null) yield event;
        }
        currentEvent = null;
        currentData = null;
        continue;
      }

      if (trimmed.startsWith('event:')) {
        currentEvent = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('data:')) {
        currentData ??= StringBuffer();
        if (currentData.isNotEmpty) currentData.write('\n');
        currentData.write(trimmed.substring(5).trim());
      }
    }

    // 处理末尾未以空行结束的事件
    if (currentData != null && currentData.isNotEmpty) {
      final event = _dispatch(currentEvent, currentData.toString().trim());
      if (event != null) yield event;
    }
  }

  /// 将字节流转换为按行分割的字符串流。
  ///
  /// 使用 [utf8.decoder] 作为 StreamTransformer，而非对每个 chunk 独立调用
  /// [utf8.decode]。当 UTF-8 多字节字符（如中文）被分割到两个 chunk 边界时，
  /// StreamTransformer 会自动将不完整的尾部字节保留到下一个 chunk 合并解码，
  /// 避免 "Unfinished UTF-8 octet sequence" 错误。
  Stream<String> _toLines(Stream<List<int>> byteStream) async* {
    final buffer = StringBuffer();
    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer.write(chunk);
      while (true) {
        final newlineIndex = buffer.toString().indexOf('\n');
        if (newlineIndex == -1) break;

        yield buffer.toString().substring(0, newlineIndex);
        final remaining = buffer.toString().substring(newlineIndex + 1);
        buffer.clear();
        buffer.write(remaining);
      }
    }
    // 剩余数据作为最后一行
    if (buffer.isNotEmpty) {
      yield buffer.toString();
    }
  }

  /// 根据 event 字段分发事件类型并解析 JSON data。
  SSEEvent? _dispatch(String? event, String rawData) {
    final SSEEventType type;
    switch (event) {
      case 'start':
        type = SSEEventType.start;
        break;
      case 'delta':
        type = SSEEventType.delta;
        break;
      case 'done':
        type = SSEEventType.done;
        break;
      case 'error':
        type = SSEEventType.error;
        break;
      case 'progress':
        type = SSEEventType.progress;
        break;
      default:
        // 未知事件类型，跳过
        return null;
    }

    dynamic data;
    try {
      data = jsonDecode(rawData);
    } catch (_) {
      data = rawData;
    }

    return SSEEvent(
      type: type,
      event: event,
      data: data,
    );
  }
}
