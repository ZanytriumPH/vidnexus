import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vidnexus/services/attachment_service.dart';
import 'package:vidnexus/services/device_service.dart';
import 'package:vidnexus/services/task_service.dart';
import 'package:vidnexus/services/upload_service.dart';
import 'package:vidnexus/services/api/api_client.dart';
import 'package:vidnexus/services/models/video_summary_task_dto.dart';

// ---- Mocks ----

class MockDio extends Mock implements Dio {}

// A fake Dio that lets us intercept requests.
class FakeDioForTest implements Dio {
  FakeDioForTest({
    this.postResponse,
    this.headResponse,
    this.patchResponse,
    this.getResponse,
    this.deleteResponse,
  });

  Response<dynamic>? postResponse;
  Response<dynamic>? headResponse;
  Response<dynamic>? patchResponse;
  Response<dynamic>? getResponse;
  Response<dynamic>? deleteResponse;

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
    return (postResponse ?? Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200))
        as Response<T>;
  }

  @override
  Future<Response<T>> head<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final r = headResponse ??
        Response<T>(
          requestOptions: RequestOptions(path: path),
          statusCode: 204,
          headers: Headers.fromMap({
            'upload-offset': ['0'],
            'upload-length': ['1048576'],
          }),
        );
    return r as Response<T>;
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return (patchResponse ?? Response<T>(requestOptions: RequestOptions(path: path), statusCode: 204))
        as Response<T>;
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return (getResponse ?? Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200))
        as Response<T>;
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return (deleteResponse ?? Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200))
        as Response<T>;
  }

  // Stub the rest of the Dio interface (unused in tests but required).

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeDioForTest fakeDio;

  // Helper: create a standard success envelope.
  Map<String, dynamic> successEnvelope(Map<String, dynamic> data) => {
        'status': 'success',
        'data': data,
        'meta': {
          'request_id': 'req-test',
          'timestamp': '2026-05-23T10:00:00Z',
        },
      };

  setUp(() {
    fakeDio = FakeDioForTest();
    // Replace ApiClient.instance with our fake Dio.
    ApiClient.reset();
    ApiClient.injectTestDio(fakeDio);
  });

  tearDown(() {
    ApiClient.reset();
  });

  // ──── TaskService workflow 方法 ────

  group('TaskService workflow', () {
    test('startAnalysis returns celery_task_id and thread_id', () async {
      fakeDio.postResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/tasks/task-001/start-analysis'),
        statusCode: 200,
        data: successEnvelope({
          'task_id': 'task-001',
          'celery_task_id': 'celery-abc',
          'thread_id': 'task-001',
          'workflow_state': 'DRAFT_GENERATING',
          'accepted_at': '2026-05-23T10:00:00Z',
          'message': 'Phase-1 analysis workflow dispatched',
        }),
      );

      final service = const TaskService();
      final resp = await service.startAnalysis('task-001');

      expect(resp.status, 'success');
      expect(resp.data!.taskId, 'task-001');
      expect(resp.data!.celeryTaskId, 'celery-abc');
      expect(resp.data!.workflowState, 'DRAFT_GENERATING');
    });

    test('approveAndFinalize submits guidance and returns accepted', () async {
      fakeDio.postResponse = Response<Map<String, dynamic>>(
        requestOptions:
            RequestOptions(path: '/api/v1/tasks/task-001/approve-and-finalize'),
        statusCode: 200,
        data: successEnvelope({
          'task_id': 'task-001',
          'celery_task_id': 'celery-xyz',
          'thread_id': 'task-001',
          'workflow_state': 'FINAL_GENERATING',
          'accepted_at': '2026-05-23T10:05:00Z',
          'message': 'Phase-2 finalization workflow dispatched',
        }),
      );

      final service = const TaskService();
      final resp = await service.approveAndFinalize(
        'task-001',
        editedAggregatedChunkInsights: '请保留重点',
        humanGuidance: '输出更简洁',
      );

      expect(resp.status, 'success');
      expect(resp.data!.workflowState, 'FINAL_GENERATING');
      expect(resp.data!.celeryTaskId, 'celery-xyz');
    });
  });

  // ──── AttachmentService ────

  group('AttachmentService', () {
    late File tempFile;

    setUp(() async {
      // 创建临时文件供 MultipartFile.fromFile 使用。
      final tempDir = Directory.systemTemp;
      tempFile = File('${tempDir.path}/test_upload.png');
      await tempFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('uploadAttachment returns oss_key and presigned_url', () async {
      fakeDio.postResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/attachments/upload'),
        statusCode: 201,
        data: successEnvelope({
          'name': 'screenshot.png',
          'oss_key': 'attachments/usr_001/abc123.png',
          'mime_type': 'image/png',
          'size_bytes': 204800,
          'presigned_url':
              'file:///tmp/object_storage/attachments/usr_001/abc123.png',
        }),
      );

      final service = const AttachmentService();
      final resp = await service.uploadAttachment(
        filePath: tempFile.path,
        fileName: 'screenshot.png',
      );

      expect(resp.data!.name, 'screenshot.png');
      expect(resp.data!.ossKey, 'attachments/usr_001/abc123.png');
      expect(resp.data!.mimeType, 'image/png');
      expect(resp.data!.sizeBytes, 204800);
      expect(resp.data!.presignedUrl, isNotNull);
    });
  });

  // ──── UploadService (TUS) ────

  group('UploadService TUS', () {
    test('initUpload returns upload_id and chunk_size', () async {
      fakeDio.postResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/uploads'),
        statusCode: 201,
        data: {
          'upload_id': 'upl_001',
          'chunk_size': 10485760,
          'expires_at': '2026-05-23T12:00:00Z',
        },
      );

      final service = const UploadService();
      final resp = await service.initUpload(
        fileName: 'demo.mp4',
        totalSize: 524288000,
      );

      expect(resp.uploadId, 'upl_001');
      expect(resp.chunkSize, 10485760);
      expect(resp.expiresAt, isNotNull);
    });

    test('queryOffset returns upload-offset and upload-length headers', () async {
      fakeDio.headResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/uploads/upl_001'),
        statusCode: 204,
        headers: Headers.fromMap({
          'upload-offset': ['10485760'],
          'upload-length': ['524288000'],
          'tus-resumable': ['1.0.0'],
        }),
      );

      final service = const UploadService();
      final headers = await service.queryOffset('upl_001');

      expect(headers['upload-offset'], '10485760');
      expect(headers['upload-length'], '524288000');
    });

    test('uploadChunk returns false on 204 (not yet complete)', () async {
      fakeDio.patchResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/uploads/upl_001'),
        statusCode: 204,
      );

      final service = const UploadService();
      final complete = await service.uploadChunk(
        uploadId: 'upl_001',
        offset: 0,
        bytes: Uint8List(1024),
      );

      expect(complete, isFalse);
    });

    test('uploadChunk returns true on 200 (all chunks complete)', () async {
      fakeDio.patchResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/uploads/upl_001'),
        statusCode: 200,
      );

      final service = const UploadService();
      final complete = await service.uploadChunk(
        uploadId: 'upl_001',
        offset: 10485760,
        bytes: Uint8List(1024),
      );

      expect(complete, isTrue);
    });

    test('getStatus returns uploaded_chunks', () async {
      // 后端 GET /api/v1/uploads/{upload_id} 返回扁平 JSON（无 ApiResponse
      // 信封），与 initUpload 一致。
      fakeDio.getResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/uploads/upl_001'),
        statusCode: 200,
        data: {
          'upload_id': 'upl_001',
          'uploaded_size': 31457280,
          'total_size': 524288000,
          'uploaded_chunks': [0, 1, 2],
        },
      );

      final service = const UploadService();
      final data = await service.getStatus('upl_001');

      expect(data.uploadId, 'upl_001');
      expect(data.uploadedSize, 31457280);
      expect(data.totalSize, 524288000);
      expect(data.uploadedChunks, [0, 1, 2]);
    });
  });

  // ──── DeviceService ────

  group('DeviceService', () {
    test('registerDevice returns device_token_id', () async {
      fakeDio.postResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/devices'),
        statusCode: 200,
        data: successEnvelope({
          'device_token_id': 'devtok_001',
          'platform': 'android',
          'device_id': 'android_001',
          'app_version': '1.0.0',
          'registered_at': '2026-05-23T10:00:00Z',
        }),
      );

      final service = const DeviceService();
      final resp = await service.registerDevice(
        deviceToken: 'fcm_token_xxx',
        platform: 'android',
        appVersion: '1.0.0',
        deviceId: 'android_001',
      );

      expect(resp.data!.deviceTokenId, 'devtok_001');
      expect(resp.data!.platform, 'android');
      expect(resp.data!.deviceId, 'android_001');
    });

    test('listDevices returns device list', () async {
      fakeDio.getResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/devices'),
        statusCode: 200,
        data: {
          'status': 'success',
          'data': [
            {
              'device_token_id': 'devtok_001',
              'platform': 'android',
              'device_id': 'android_001',
              'app_version': '1.0.0',
              'registered_at': '2026-05-23T10:00:00Z',
            },
          ],
        },
      );

      final service = const DeviceService();
      final resp = await service.listDevices();

      expect(resp.status, 'success');
      expect(resp.data, hasLength(1));
      expect(resp.data!.first.deviceTokenId, 'devtok_001');
    });
  });

  // ──── DTO 序列化 ────

  group('Phase B DTO serialization', () {
    test('StartAnalysisResponseData fromJson parses all fields', () {
      final json = {
        'task_id': 'task-001',
        'celery_task_id': 'celery-abc',
        'thread_id': 'task-001',
        'workflow_state': 'DRAFT_GENERATING',
        'accepted_at': '2026-05-23T10:00:00Z',
        'message': 'Phase-1 analysis workflow dispatched',
      };

      final dto = StartAnalysisResponseData.fromJson(json);

      expect(dto.taskId, 'task-001');
      expect(dto.celeryTaskId, 'celery-abc');
      expect(dto.workflowState, 'DRAFT_GENERATING');
      expect(dto.message, 'Phase-1 analysis workflow dispatched');
    });

    test('ApproveAndFinalizeRequest toJson excludes null fields', () {
      const req = ApproveAndFinalizeRequest(
        editedAggregatedChunkInsights: '保留重点',
      );
      final json = req.toJson();

      expect(json['edited_aggregated_chunk_insights'], '保留重点');
      expect(json.containsKey('human_guidance'), isFalse);
    });

    test('DeviceRegisterRequest toJson maps all fields', () {
      const req = DeviceRegisterRequest(
        deviceToken: 'fcm-001',
        platform: 'android',
        appVersion: '1.0.0',
        deviceId: 'dev-001',
      );
      final json = req.toJson();

      expect(json['device_token'], 'fcm-001');
      expect(json['platform'], 'android');
      expect(json['app_version'], '1.0.0');
      expect(json['device_id'], 'dev-001');
    });
  });
}
