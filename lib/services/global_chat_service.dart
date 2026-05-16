import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/global_chat_dto.dart';

/// 知识库全局会话 CRUD Service，与后端 /api/v1/kbs/{kbid}/chats 路由对齐。
class GlobalChatService {
  const GlobalChatService();

  Dio get _dio => ApiClient.instance;

  /// 创建全局会话。
  Future<ApiResponse<GlobalChatSessionResponseData>> createChat({
    required String kbid,
    required String chatTitle,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.kbChats(kbid),
      data: GlobalChatCreateRequest(kbid: kbid, chatTitle: chatTitle).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalChatSessionResponseData.fromJson,
    );
  }

  /// 分页获取知识库下的会话列表。
  Future<ApiListResponse<GlobalChatSessionResponseData>> listChats(
    String kbid, {
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<GlobalChatSessionResponseData>(
      ApiEndpoints.kbChats(kbid),
      params: params,
      fromJsonT: GlobalChatSessionResponseData.fromJson,
    );
  }

  /// 获取单个会话详情。
  Future<ApiResponse<GlobalChatSessionResponseData>> getChat(
    String kbid,
    String chatId,
  ) async {
    final resp = await _dio.get(ApiEndpoints.kbChat(kbid, chatId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalChatSessionResponseData.fromJson,
    );
  }

  /// 重命名会话。
  Future<ApiResponse<GlobalChatSessionResponseData>> updateChat(
    String kbid,
    String chatId, {
    required String chatTitle,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.kbChat(kbid, chatId),
      data: GlobalChatUpdateRequest(chatTitle: chatTitle).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalChatSessionResponseData.fromJson,
    );
  }

  /// 删除会话（级联删除该会话下所有 QA）。
  Future<ApiResponse<GlobalChatDeleteResponseData>> deleteChat(
    String kbid,
    String chatId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.kbChat(kbid, chatId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalChatDeleteResponseData.fromJson,
    );
  }
}
