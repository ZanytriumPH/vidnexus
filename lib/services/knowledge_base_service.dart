import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/knowledge_base_dto.dart';

/// 知识库 CRUD + 视频绑定 Service，与后端 /api/v1/kbs 路由对齐。
class KnowledgeBaseService {
  const KnowledgeBaseService();

  Dio get _dio => ApiClient.instance;

  // ---- 知识库 CRUD ----

  /// 创建知识库。
  Future<ApiResponse<KnowledgeBaseResponseData>> createKB({
    required String name,
    String? category,
    String? description,
    KBConfig? config,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.kbs,
      data: KnowledgeBaseCreateRequest(
        name: name,
        category: category,
        description: description,
        config: config,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KnowledgeBaseResponseData.fromJson,
    );
  }

  /// 分页获取知识库列表。
  Future<ApiListResponse<KnowledgeBaseResponseData>> listKBs({
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<KnowledgeBaseResponseData>(
      ApiEndpoints.kbs,
      params: params,
      fromJsonT: KnowledgeBaseResponseData.fromJson,
    );
  }

  /// 获取单个知识库详情。
  Future<ApiResponse<KnowledgeBaseResponseData>> getKB(String kbid) async {
    final resp = await _dio.get(ApiEndpoints.kb(kbid));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KnowledgeBaseResponseData.fromJson,
    );
  }

  /// 更新知识库（可更新 name / category / description / config）。
  Future<ApiResponse<KnowledgeBaseResponseData>> updateKB(
    String kbid, {
    String? name,
    String? category,
    String? description,
    KBConfig? config,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.kb(kbid),
      data: KnowledgeBaseUpdateRequest(
        name: name,
        category: category,
        description: description,
        config: config,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KnowledgeBaseResponseData.fromJson,
    );
  }

  /// 删除知识库。
  Future<ApiResponse<KBDeleteResponseData>> deleteKB(String kbid) async {
    final resp = await _dio.delete(ApiEndpoints.kb(kbid));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KBDeleteResponseData.fromJson,
    );
  }

  // ---- 视频绑定 ----

  /// 向知识库绑定视频。
  Future<ApiResponse<KBVideoBindResponseData>> bindVideo({
    required String kbid,
    required String videoId,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.kbVideos(kbid),
      data: KBVideoBindRequest(videoId: videoId).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KBVideoBindResponseData.fromJson,
    );
  }

  /// 分页获取知识库下的视频列表。
  Future<ApiListResponse<KBVideoItem>> listVideos(
    String kbid, {
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<KBVideoItem>(
      ApiEndpoints.kbVideos(kbid),
      params: params,
      fromJsonT: KBVideoItem.fromJson,
    );
  }

  /// 从知识库解绑视频。
  Future<ApiResponse<KBVideoBindResponseData>> unbindVideo({
    required String kbid,
    required String videoId,
  }) async {
    final resp = await _dio.delete(ApiEndpoints.kbVideo(kbid, videoId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      KBVideoBindResponseData.fromJson,
    );
  }
}
