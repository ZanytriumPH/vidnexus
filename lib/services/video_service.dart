import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/video_resource_dto.dart';

/// 视频资源 CRUD Service，与后端 /api/v1/videos 路由对齐。
///
/// 注意：DELETE /api/v1/videos/{videoId} 返回 202（受理语义）。
class VideoService {
  const VideoService();

  Dio get _dio => ApiClient.instance;

  /// 创建视频资源记录。
  ///
  /// 当前仅传 file_name，文件实际上传暂不在对接范围。
  Future<ApiResponse<VideoResourceResponseData>> createVideo({
    required String fileName,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.videos,
      data: VideoResourceCreateRequest(fileName: fileName).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoResourceResponseData.fromJson,
    );
  }

  /// 获取单个视频资源详情。
  Future<ApiResponse<VideoResourceResponseData>> getVideo(
    String videoId,
  ) async {
    final resp = await _dio.get(ApiEndpoints.video(videoId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoResourceResponseData.fromJson,
    );
  }

  /// 分页获取视频资源列表。
  Future<ApiListResponse<VideoResourceResponseData>> listVideos({
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<VideoResourceResponseData>(
      ApiEndpoints.videos,
      params: params,
      fromJsonT: VideoResourceResponseData.fromJson,
    );
  }

  /// 更新视频文件名。
  Future<ApiResponse<VideoResourceResponseData>> updateVideo(
    String videoId, {
    required String fileName,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.video(videoId),
      data: VideoResourceUpdateRequest(fileName: fileName).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoResourceResponseData.fromJson,
    );
  }

  /// 删除视频资源。
  ///
  /// 后端返回 202 Accepted（受理语义），前端应做异步刷新处理。
  Future<ApiResponse<VideoResourceDeleteResponseData>> deleteVideo(
    String videoId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.video(videoId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoResourceDeleteResponseData.fromJson,
    );
  }
}
