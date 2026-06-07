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
///
/// async_finalize_upload Celery 任务完成后，后端写入 state 和 video_id 字段：
/// - state: "done"（新上传）/ "dedup_reused"（去重复用）/ "rejected"（格式校验失败）/ "failed"（失败）
/// - 非终态: "created" / "uploading" / "uploading_complete" / "finalizing"
/// - video_id: 最终关联的视频资源 ID（去重时是已有视频的 ID）
class UploadStatusResponseData {
  const UploadStatusResponseData({
    required this.uploadId,
    required this.uploadedSize,
    required this.totalSize,
    required this.uploadedChunks,
    this.state,
    this.videoId,
  });

  final String uploadId;
  final int uploadedSize;
  final int totalSize;
  final List<int> uploadedChunks;

  /// async_finalize_upload 完成后的状态（优先解析新字段 "state"，回退兼容 "status"）：
  /// "done" / "dedup_reused" / "rejected" / "failed" / null（处理中）
  final String? state;

  /// 最终关联的视频资源 ID（去重时可能与 createVideo 返回的不同）
  final String? videoId;

  factory UploadStatusResponseData.fromJson(Map<String, dynamic> json) {
    return UploadStatusResponseData(
      uploadId: json['upload_id'] as String? ?? '',
      uploadedSize: json['uploaded_size'] as int? ?? 0,
      totalSize: json['total_size'] as int? ?? 0,
      uploadedChunks: (json['uploaded_chunks'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      state: json['state'] as String? ?? json['status'] as String?,
      videoId: json['video_id'] as String?,
    );
  }
}
