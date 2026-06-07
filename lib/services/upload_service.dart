import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'models/common_dto.dart';
import 'models/upload_dto.dart';

/// TUS 分片上传 Service，与后端 /api/v1/uploads 路由对齐（new.md 新增）。
///
/// 分片大小固定 10 MiB（与后端对齐）。
class UploadService {
  const UploadService();

  /// 固定分片大小：10 MiB。
  static const int chunkSize = 10 * 1024 * 1024;

  Dio get _dio => ApiClient.instance;

  /// 初始化上传会话。
  Future<InitUploadResponseData> initUpload({
    required String fileName,
    required int totalSize,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.uploads,
      data: InitUploadRequest(
        fileName: fileName,
        totalSize: totalSize,
      ).toJson(),
    );
    // 后端返回扁平 JSON：{"upload_id":"...","chunk_size":...,"expires_at":"..."}
    // 不走 ApiResponse 信封，直接解析
    return InitUploadResponseData.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 查询已上传偏移量（HEAD 请求）。
  ///
  /// 返回 Map：{'upload-offset': String, 'upload-length': String}。
  Future<Map<String, String>> queryOffset(String uploadId) async {
    final resp = await _dio.head(
      ApiEndpoints.upload(uploadId),
      options: Options(headers: {'Tus-Resumable': '1.0.0'}),
    );
    final result = <String, String>{};
    resp.headers.forEach((name, values) {
      result[name] = values.join(', ');
    });
    return result;
  }

  /// 上传单个分片。
  ///
  /// [offset] 为当前已上传字节数，[bytes] 为分片二进制数据。
  /// 返回 true 表示全部上传完成（HTTP 200），false 表示继续（HTTP 204）。
  Future<bool> uploadChunk({
    required String uploadId,
    required int offset,
    required Uint8List bytes,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.upload(uploadId),
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Tus-Resumable': '1.0.0',
          'Upload-Offset': offset.toString(),
          'Content-Type': 'application/offset+octet-stream',
        },
      ),
    );
    return resp.statusCode == 200;
  }

  /// 取消上传。
  Future<ApiResponse<InitUploadResponseData>> cancelUpload(
    String uploadId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.upload(uploadId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      InitUploadResponseData.fromJson,
    );
  }

  /// 查询上传状态。
  ///
  /// 后端 GET /api/v1/uploads/{upload_id} 返回扁平 JSON（无 ApiResponse
  /// 信封），与 initUpload 一致，因此直接解析。
  Future<UploadStatusResponseData> getStatus(String uploadId) async {
    final resp = await _dio.get(ApiEndpoints.upload(uploadId));
    return UploadStatusResponseData.fromJson(
      resp.data as Map<String, dynamic>,
    );
  }
}
