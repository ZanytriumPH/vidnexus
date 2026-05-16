import 'package:dio/dio.dart';

/// 自动注入 Authorization header，并在 401 时尝试 refresh token。
///
/// 使用方式：在 auth controller 拿到 token 后调用 [setTokens]；
/// 登出时调用 [clear] 移除 token。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Future<String?> Function() getAccessToken,
    required Future<void> Function() onRefreshFailed,
    required Future<bool> Function() tryRefresh,
  })  : _getAccessToken = getAccessToken,
        _onRefreshFailed = onRefreshFailed,
        _tryRefresh = tryRefresh;

  final Future<String?> Function() _getAccessToken;
  final Future<void> Function() _onRefreshFailed;
  final Future<bool> Function() _tryRefresh;

  bool _isRefreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // 注入 request id（可从外部传入，这里先用简单的实现）
    options.headers['x-request-id'] =
        options.headers['x-request-id'] ?? 'req-${DateTime.now().millisecondsSinceEpoch}';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      // 尝试 refresh
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          // 重试原请求
          final opts = err.requestOptions;
          final token = await _getAccessToken();
          opts.headers['Authorization'] = 'Bearer $token';
          try {
            final response = await Dio().fetch(opts);
            _isRefreshing = false;
            return handler.resolve(response);
          } catch (e) {
            _isRefreshing = false;
            return handler.next(err);
          }
        }
      } catch (_) {}
      _isRefreshing = false;
      await _onRefreshFailed();
    }
    handler.next(err);
  }
}
