import 'package:dio/dio.dart';

import '../models/common_dto.dart';

/// Dio 分页请求扩展，简化 GET 列表接口调用。
extension PaginatedDioExtension on Dio {
  /// 发起分页 GET 请求并解析为 [ApiListResponse]。
  ///
  /// [path] — API 路径（如 /api/v1/kbs）。
  /// [params] — 分页参数。
  /// [fromJsonT] — 列表单项的 fromJson 工厂。
  /// [extraQuery] — 额外的 query 参数（如过滤条件）。
  Future<ApiListResponse<T>> getPaginated<T>(
    String path, {
    required PageParams params,
    required T Function(Map<String, dynamic>) fromJsonT,
    Map<String, dynamic>? extraQuery,
    CancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      ...params.toQueryParameters(),
      if (extraQuery != null) ...extraQuery,
    };

    final response = await get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    );

    return ApiListResponse.fromJson(
      response.data as Map<String, dynamic>,
      fromJsonT,
    );
  }
}
