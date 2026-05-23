import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'models/common_dto.dart';

/// 附件上传 Service，与后端 /api/v1/attachments/upload 对齐（new.md 新增）。
class AttachmentService {
  const AttachmentService();

  Dio get dio => ApiClient.instance;

  /// 上传附件（图片）。
  ///
  /// [filePath] 是本地文件绝对路径，[fileName] 是原始文件名。
  /// 返回 AttachmentUploadResponseData（包含 oss_key）。
  Future<ApiResponse<AttachmentUploadResponseData>> uploadAttachment({
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final resp = await dio.post(
      ApiEndpoints.attachmentsUpload,
      data: formData,
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      AttachmentUploadResponseData.fromJson,
    );
  }
}

/// POST /api/v1/attachments/upload 响应 data。
/// 字段与 AttachmentInfo 一致，额外携带 presigned_url。
class AttachmentUploadResponseData {
  const AttachmentUploadResponseData({
    required this.name,
    required this.ossKey,
    required this.mimeType,
    required this.sizeBytes,
    this.presignedUrl,
  });

  final String name;
  final String ossKey;
  final String mimeType;
  final int sizeBytes;
  final String? presignedUrl;

  factory AttachmentUploadResponseData.fromJson(Map<String, dynamic> json) {
    return AttachmentUploadResponseData(
      name: json['name'] as String? ?? '',
      ossKey: json['oss_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      presignedUrl: json['presigned_url'] as String?,
    );
  }
}
