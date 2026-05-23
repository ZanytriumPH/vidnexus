import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/global_chat_dto.dart';
import 'models/video_qa_dto.dart';
import 'sse/sse_client.dart';
import 'sse/sse_models.dart';

/// 知识库全局问答 CRUD Service，与后端 /api/v1/kbs/{kbid}/chats/{chat_id}/qa 路由对齐。
class GlobalQAService {
  const GlobalQAService();

  Dio get _dio => ApiClient.instance;

  /// 在会话中创建问答。
  Future<ApiResponse<GlobalQARecordResponseData>> createQA({
    required String kbid,
    required String chatId,
    required String questionContent,
    List<AttachmentInfo> attachments = const [],
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.kbChatQaList(kbid, chatId),
      data: GlobalQACreateRequest(
        questionContent: questionContent,
        attachments: attachments,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalQARecordResponseData.fromJson,
    );
  }

  /// 分页获取会话下的问答列表。
  Future<ApiListResponse<GlobalQARecordResponseData>> listQAs(
    String kbid,
    String chatId, {
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<GlobalQARecordResponseData>(
      ApiEndpoints.kbChatQaList(kbid, chatId),
      params: params,
      fromJsonT: GlobalQARecordResponseData.fromJson,
    );
  }

  /// 获取单条问答详情。
  Future<ApiResponse<GlobalQARecordResponseData>> getQA(
    String kbid,
    String chatId,
    String qaId,
  ) async {
    final resp = await _dio.get(ApiEndpoints.kbChatQa(kbid, chatId, qaId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalQARecordResponseData.fromJson,
    );
  }

  /// 触发重生成。
  Future<ApiResponse<GlobalQARecordResponseData>> updateQA(
    String kbid,
    String chatId,
    String qaId, {
    required bool regenerate,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.kbChatQa(kbid, chatId, qaId),
      data: GlobalQAUpdateRequest(regenerate: regenerate).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      GlobalQARecordResponseData.fromJson,
    );
  }

  /// 删除问答。
  Future<ApiResponse<QADeleteResponseData>> deleteQA(
    String kbid,
    String chatId,
    String qaId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.kbChatQa(kbid, chatId, qaId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      QADeleteResponseData.fromJson,
    );
  }

  /// 通过 SSE 流式获取全局 QA 回答（new.md 新增）。
  Stream<SSEEvent> createQAStream({
    required String kbid,
    required String chatId,
    required String questionContent,
    List<AttachmentInfo> attachments = const [],
  }) {
    return SseClient.instance.connect(
      ApiEndpoints.kbChatQAStream(kbid, chatId),
      data: GlobalQACreateRequest(
        questionContent: questionContent,
        attachments: attachments,
      ).toJson(),
    );
  }
}
