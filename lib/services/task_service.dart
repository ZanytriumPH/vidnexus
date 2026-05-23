import 'package:dio/dio.dart';

import 'api/api_client.dart';
import 'api/api_endpoints.dart';
import 'api/paginated_mixin.dart';
import 'models/common_dto.dart';
import 'models/video_summary_task_dto.dart';

/// 视频总结任务 CRUD Service，与后端 /api/v1/tasks 路由对齐。
class TaskService {
  const TaskService();

  /// 暴露 Dio 实例供调试（如打印 baseUrl）。
  Dio get dio => ApiClient.instance;

  Dio get _dio => ApiClient.instance;

  /// 创建总结任务。
  Future<ApiResponse<VideoSummaryTaskResponseData>> createTask({
    required String kbid,
    required String videoId,
    String? userInitialPreference,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.tasks,
      data: TaskCreateRequest(
        kbid: kbid,
        videoId: videoId,
        userInitialPreference: userInitialPreference,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoSummaryTaskResponseData.fromJson,
    );
  }

  /// 获取单个任务详情（用于轮询进度）。
  Future<ApiResponse<VideoSummaryTaskResponseData>> getTask(
    String taskId,
  ) async {
    final resp = await _dio.get(ApiEndpoints.task(taskId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoSummaryTaskResponseData.fromJson,
    );
  }

  /// 分页获取任务列表。
  Future<ApiListResponse<VideoSummaryTaskResponseData>> listTasks({
    PageParams params = const PageParams(),
  }) async {
    return _dio.getPaginated<VideoSummaryTaskResponseData>(
      ApiEndpoints.tasks,
      params: params,
      fromJsonT: VideoSummaryTaskResponseData.fromJson,
    );
  }

  /// 更新任务（用户可写字段：draftSummary / userGuidance / title）。
  Future<ApiResponse<VideoSummaryTaskResponseData>> updateTask(
    String taskId, {
    String? draftSummary,
    String? userGuidance,
    String? title,
  }) async {
    final resp = await _dio.patch(
      ApiEndpoints.task(taskId),
      data: TaskUpdateRequest(
        draftSummary: draftSummary,
        userGuidance: userGuidance,
        title: title,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      VideoSummaryTaskResponseData.fromJson,
    );
  }

  /// 删除任务。
  Future<ApiResponse<TaskDeleteResponseData>> deleteTask(
    String taskId,
  ) async {
    final resp = await _dio.delete(ApiEndpoints.task(taskId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      TaskDeleteResponseData.fromJson,
    );
  }

  /// 触发 Phase-1 分析工作流（new.md 新增）。
  Future<ApiResponse<StartAnalysisResponseData>> startAnalysis(
    String taskId,
  ) async {
    final resp = await _dio.post(ApiEndpoints.taskStartAnalysis(taskId));
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      StartAnalysisResponseData.fromJson,
    );
  }

  /// 提交审批并触发 Phase-2 终稿生成（new.md 新增）。
  Future<ApiResponse<ApproveAndFinalizeResponseData>> approveAndFinalize(
    String taskId, {
    String? editedAggregatedChunkInsights,
    String? humanGuidance,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.taskApproveAndFinalize(taskId),
      data: ApproveAndFinalizeRequest(
        editedAggregatedChunkInsights: editedAggregatedChunkInsights,
        humanGuidance: humanGuidance,
      ).toJson(),
    );
    return ApiResponse.fromJson(
      resp.data as Map<String, dynamic>,
      ApproveAndFinalizeResponseData.fromJson,
    );
  }
}
