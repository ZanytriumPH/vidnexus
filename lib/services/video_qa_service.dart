import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/video_qa_dto.dart';
import 'sse/sse_client.dart';
import 'sse/sse_models.dart';

/// 单视频追问 CRUD Service，与后端 /api/v1/tasks/{task_id}/qa 路由对齐。
class VideoQAService {
  const VideoQAService();

  Dio get _dio => ApiClient.instance;

  /// 在任务中创建局部追问。
  Future<ApiResponse<VideoQARecordResponseData>> createQA({
    required String taskId,
    required String questionContent,
    String? startTime,
    String? endTime,
    List<AttachmentInfo> attachments = const [],
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.taskQaList(taskId),
      data: VideoQACreateRequest(
        taskId: taskId,
        startTime: startTime,
        endTime: endTime,
        questionContent: questionContent,
        attachments: attachments,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoQARecordResponseData.fromJson,
    );
  }

  /// 分页获取任务下的问答列表。
  Future<ApiListResponse<VideoQARecordResponseData>> listQAs(
    String taskId, {
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<VideoQARecordResponseData>(
      ApiEndpoints.taskQaList(taskId),
      params: params,
      fromJsonT: VideoQARecordResponseData.fromJson,
    );
  }

  /// 获取单条问答详情。
  Future<ApiResponse<VideoQARecordResponseData>> getQA(
    String taskId,
    String qaId,
  ) async {
    final resp = await _dio.get(ApiEndpoints.taskQa(taskId, qaId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoQARecordResponseData.fromJson,
    );
  }

  /// 触发重生成。
  Future<ApiResponse<VideoQARecordResponseData>> updateQA(
    String taskId,
    String qaId, {
    required bool regenerate,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.taskQa(taskId, qaId),
      data: VideoQAUpdateRequest(regenerate: regenerate).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoQARecordResponseData.fromJson,
    );
  }

  /// 删除问答。
  Future<ApiResponse<QADeleteResponseData>> deleteQA(
    String taskId,
    String qaId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.taskQa(taskId, qaId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      QADeleteResponseData.fromJson,
    );
  }

  /// 通过 SSE 流式获取 time-travel QA 回答（new.md 新增）。
  Stream<SSEEvent> createTimeTravelQAStream(
    String taskId,
    TimeTravelQAStreamRequest request,
  ) {
    return SseClient.instance.connect(
      ApiEndpoints.taskTimeTravelQAStream(taskId),
      data: request.toJson(),
    );
  }
}
