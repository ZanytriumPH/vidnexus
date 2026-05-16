import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 将 DioException 映射为 ApiError，并产出中文用户提示。
///
/// 注册位置：在 LogInterceptor 之后、AuthInterceptor 之前。
/// 401 错误由 AuthInterceptor 优先处理，本拦截器对 401 仅做日志记录。
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({
    this.onAuthFailure,
  });

  /// 当 401 发生且 AuthInterceptor 未处理（即未注入或 refresh 失败）时回调。
  final VoidCallback? onAuthFailure;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    // 401 留给 AuthInterceptor 处理；仅当 AuthInterceptor 未注入或已失效时
    // 才在这里做 fallback 日志与回调。
    if (statusCode == 401) {
      _log('401 Unauthorized — ${_extractDetail(err)}');
      onAuthFailure?.call();
      return handler.next(err);
    }

    // 统一日志
    _log('${statusCode ?? 'N/A'} — ${_statusLabel(statusCode)} — ${_extractDetail(err)}');

    return handler.next(err);
  }

  /// 从响应体提取 detail 字段。
  String _extractDetail(DioException err) {
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      return data['detail']?.toString() ?? data['message']?.toString() ?? '';
    }
    return err.message ?? '';
  }

  /// HTTP 状态码 → 中文标签。
  String _statusLabel(int? statusCode) {
    return switch (statusCode) {
      400 => '请求参数错误',
      401 => '未授权',
      403 => '无权限',
      404 => '资源不存在',
      409 => '资源冲突',
      422 => '参数校验失败',
      500 => '服务器内部错误',
      502 => '网关错误',
      503 => '服务暂不可用',
      _ => '未知错误',
    };
  }

  void _log(String msg) {
    if (kDebugMode) {
      debugPrint('[API Error] $msg');
    }
  }
}
