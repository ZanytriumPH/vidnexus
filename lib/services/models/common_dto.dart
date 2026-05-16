import 'package:dio/dio.dart';

/// 公共 JSON 结构，与后端 schemas/common.py 对齐。

/// 响应元信息（对应 MetaInfo）。
class MetaInfo {
  const MetaInfo({
    required this.requestId,
    required this.timestamp,
  });

  final String requestId;
  final String timestamp;

  factory MetaInfo.fromJson(Map<String, dynamic> json) {
    return MetaInfo(
      requestId: json['request_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'timestamp': timestamp,
      };
}

/// 分页信息（对应 PaginationInfo）。
class PaginationInfo {
  const PaginationInfo({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
    this.nextCursor,
  });

  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;
  final String? nextCursor;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'page_size': pageSize,
        'total': total,
        'has_next': hasNext,
        'next_cursor': nextCursor,
      };
}

/// 业务接口成功响应（单对象），对应 {status, data, meta} 信封。
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    this.data,
    this.meta,
  });

  final String status;
  final T? data;
  final MetaInfo? meta;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse(
      status: json['status'] as String? ?? 'success',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? MetaInfo.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 业务接口成功响应（列表），对应 {status, data, pagination, meta} 信封。
class ApiListResponse<T> {
  const ApiListResponse({
    required this.status,
    required this.data,
    this.pagination,
    this.meta,
  });

  final String status;
  final List<T> data;
  final PaginationInfo? pagination;
  final MetaInfo? meta;

  factory ApiListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiListResponse(
      status: json['status'] as String? ?? 'success',
      data: (json['data'] as List<dynamic>?)
              ?.map(
                (e) => fromJsonT(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? MetaInfo.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 通用错误响应（兼容 FastAPI detail 与全局 500 格式）。
class ApiError {
  const ApiError({
    this.detail,
    this.status,
    this.message,
    this.statusCode,
  });

  final String? detail;
  final String? status;
  final String? message;
  final int? statusCode;

  factory ApiError.fromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiError(
        detail: data['detail'] as String?,
        status: data['status'] as String?,
        message: data['message'] as String?,
        statusCode: e.response?.statusCode,
      );
    }
    return ApiError(
      detail: e.message,
      statusCode: e.response?.statusCode,
    );
  }

  /// 用户可读的错误消息。
  String get userMessage {
    return detail ?? message ?? '未知错误，请稍后重试';
  }
}
