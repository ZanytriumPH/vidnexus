/// TUS 分片上传域请求/响应 DTO，与后端 /api/v1/uploads 对齐（new.md 新增）。
library;

/// POST /api/v1/uploads 请求体。
class InitUploadRequest {
  const InitUploadRequest({
    required this.fileName,
    required this.totalSize,
  });

  final String fileName; // 1~512
  final int totalSize; // >0 且 <=10GB

  Map<String, dynamic> toJson() => {
        'file_name': fileName,
        'total_size': totalSize,
      };
}

/// POST /api/v1/uploads 响应 data。
class InitUploadResponseData {
  const InitUploadResponseData({
    required this.uploadId,
    required this.chunkSize,
    this.expiresAt,
  });

  final String uploadId;
  final int chunkSize;
  final String? expiresAt;

  factory InitUploadResponseData.fromJson(Map<String, dynamic> json) {
    return InitUploadResponseData(
      uploadId: json['upload_id'] as String? ?? '',
      chunkSize: json['chunk_size'] as int? ?? 10485760,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

/// GET /api/v1/uploads/{upload_id} 响应 data。
class UploadStatusResponseData {
  const UploadStatusResponseData({
    required this.uploadId,
    required this.uploadedSize,
    required this.totalSize,
    required this.uploadedChunks,
  });

  final String uploadId;
  final int uploadedSize;
  final int totalSize;
  final List<int> uploadedChunks;

  factory UploadStatusResponseData.fromJson(Map<String, dynamic> json) {
    return UploadStatusResponseData(
      uploadId: json['upload_id'] as String? ?? '',
      uploadedSize: json['uploaded_size'] as int? ?? 0,
      totalSize: json['total_size'] as int? ?? 0,
      uploadedChunks: (json['uploaded_chunks'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}
