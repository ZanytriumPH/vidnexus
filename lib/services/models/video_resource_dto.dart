/// Video Resource 域请求/响应 DTO，与后端 schemas 对齐。
library;

/// POST /api/v1/videos 请求体。
class VideoResourceCreateRequest {
  const VideoResourceCreateRequest({required this.fileName});

  final String fileName;

  Map<String, dynamic> toJson() => {'file_name': fileName};
}

/// PATCH /api/v1/videos/{video_id} 请求体。
class VideoResourceUpdateRequest {
  const VideoResourceUpdateRequest({required this.fileName});

  final String fileName;

  Map<String, dynamic> toJson() => {'file_name': fileName};
}

/// VideoResource 响应 data 对象。
class VideoResourceResponseData {
  const VideoResourceResponseData({
    required this.videoId,
    required this.ownerId,
    required this.fileName,
    this.ossKey,
    this.presignedUrl,
    this.duration,
    this.fullTranscript,
    this.transcribeStatus,
    this.transcriptVectorIds,
    this.keyframes,
    this.frameExtractionStatus,
    this.keyframesOssPrefix,
    this.extractCompletedAt,
    this.createdAt,
    this.fileHash,
    this.taskRefCount,
  });

  final String videoId;
  final String ownerId;
  final String fileName;
  final String? ossKey;
  final String? presignedUrl;
  final int? duration;
  final String? fullTranscript;
  final String? transcribeStatus;
  final List<String>? transcriptVectorIds;
  final List<dynamic>? keyframes;
  final String? frameExtractionStatus;
  final String? keyframesOssPrefix;
  final String? extractCompletedAt;
  final String? createdAt;
  final String? fileHash;
  final int? taskRefCount;

  factory VideoResourceResponseData.fromJson(Map<String, dynamic> json) {
    return VideoResourceResponseData(
      videoId: json['video_id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      ossKey: json['oss_key'] as String?,
      presignedUrl: json['presigned_url'] as String?,
      duration: json['duration'] as int?,
      fullTranscript: json['full_transcript'] as String?,
      transcribeStatus: json['transcribe_status'] as String?,
      transcriptVectorIds: (json['transcript_vector_ids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      keyframes: json['keyframes'] as List<dynamic>?,
      frameExtractionStatus: json['frame_extraction_status'] as String?,
      keyframesOssPrefix: json['keyframes_oss_prefix'] as String?,
      extractCompletedAt: json['extract_completed_at'] as String?,
      createdAt: json['created_at'] as String?,
      fileHash: json['file_hash'] as String?,
      taskRefCount: json['task_ref_count'] as int?,
    );
  }
}

/// DELETE /api/v1/videos/{video_id} 响应 data。
class VideoResourceDeleteResponseData {
  const VideoResourceDeleteResponseData({required this.videoId});

  final String videoId;

  factory VideoResourceDeleteResponseData.fromJson(Map<String, dynamic> json) {
    return VideoResourceDeleteResponseData(
      videoId: json['video_id'] as String? ?? '',
    );
  }
}
