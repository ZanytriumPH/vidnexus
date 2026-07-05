import '../models/common_dto.dart';

/// 错误消息映射工具：将技术错误转为用户可读的中文提示。
///
/// 三层优先级：
///   1. `error.code` 精确匹配（54 个稳定错误码）— 零歧义
///   2. HTTP statusCode 映射 — 粗粒度标准化信号
///   3. 后端 `error.message` 直接展示 — 后端已返回人类可读消息
///
/// `fromException` 自动检测异常类型：若为 [ApiError] 走结构化映射，
/// 否则走关键词兜底匹配（仅用于网络异常等非 ApiError 场景）。
class UserFriendlyError {
  UserFriendlyError._();

  // ---------------------------------------------------------------------------
  // 主入口
  // ---------------------------------------------------------------------------

  /// 从 [ApiError] 提取用户可读消息（三层优先级）。
  static String fromApiError(ApiError error) {
    // 1. error.code 精确匹配（最高优先级）
    if (error.code != null && error.code!.isNotEmpty) {
      final msg = _codeToMessage(error.code!);
      if (msg != null) return msg;
    }

    // 2. HTTP statusCode 映射
    if (error.statusCode != null) {
      final msg = _httpStatusMessage(error.statusCode!);
      if (msg != null) return msg;
    }

    // 3. 后端 error.message（人类可读）或 detail
    final backendMsg = error.message;
    if (backendMsg != null && backendMsg.isNotEmpty) return backendMsg;

    final detail = error.detail;
    if (detail != null && detail.isNotEmpty) return _sanitize(detail);

    return '操作失败，请稍后重试';
  }

  /// 智能分发：若异常为 [ApiError] 走结构化映射，否则走关键词兜底。
  static String fromException(Object e) {
    if (e is ApiError) return fromApiError(e);
    if (e is String) return _displayFallback(e);
    return _displayFallback(e.toString());
  }

  /// [deprecated] 仅用于非 ApiError 的字符串映射，保留以兼容旧调用。
  /// 新代码请使用 [fromApiError] 或 [fromException]。
  static String mapMessage(String raw) {
    return _displayFallback(raw);
  }

  // ---------------------------------------------------------------------------
  // 54 个稳定错误码 → 中文用户提示
  // ---------------------------------------------------------------------------

  /// 后端 error.code → 用户可读中文消息。
  /// 返回 null 表示该 code 不在映射表中（应由上层 fallback 处理）。
  static String? _codeToMessage(String code) {
    switch (code) {
      // ---- AUTH（8 个码）----
      case 'AUTH_MISSING_TOKEN':
        return '登录已过期，请重新登录';
      case 'AUTH_INVALID_TOKEN':
        return '登录已过期，请重新登录';
      case 'AUTH_INVALID_TOKEN_TYPE':
        return '登录已过期，请重新登录';
      case 'AUTH_DEVICE_MISMATCH':
        return '设备不匹配，请重新登录';
      case 'AUTH_INVALID_CREDENTIALS':
        return '用户名或密码错误';
      case 'AUTH_USERNAME_ALREADY_EXISTS':
        return '用户名已被注册';
      case 'AUTH_INSUFFICIENT_PERMISSIONS':
        return '无权限访问';
      case 'AUTH_USER_NOT_FOUND':
        return '用户不存在';

      // ---- KB（6 个码）----
      case 'KB_NOT_FOUND':
        return '知识库不存在';
      case 'KB_ACCESS_DENIED':
        return '无权访问该知识库';
      case 'KB_DUPLICATE_VIDEO':
        return '该视频已在知识库中';
      case 'KB_VIDEO_NOT_IN_KB':
        return '视频不在此知识库';
      case 'KB_VIDEO_BIND_FAILED':
        return '绑定失败，请重试';
      case 'KB_DELETE_FAILED':
        return '删除失败，请稍后重试';

      // ---- VIDEO（5 个码）----
      case 'VIDEO_NOT_FOUND':
        return '视频不存在';
      case 'VIDEO_NOT_READY':
        return '视频正在处理中，请稍后再试';
      case 'VIDEO_DELETE_FAILED':
        return '删除失败，请重试';
      case 'VIDEO_ACCESS_DENIED':
        return '无权访问该视频';
      case 'VIDEO_FILE_NOT_FOUND':
        return '源文件丢失，请联系管理员';

      // ---- TASK（10 个码）----
      case 'TASK_NOT_FOUND':
        return '任务不存在';
      case 'TASK_DUPLICATE_VIDEO_IN_KB':
        return '已有分析任务';
      case 'TASK_ACCESS_DENIED':
        return '无权访问该任务';
      case 'TASK_INVALID_STATE_TRANSITION':
        return '当前状态不支持此操作';
      case 'TASK_FINALIZATION_IN_PROGRESS':
        return '最终确认进行中，请稍后';
      case 'TASK_WORKFLOW_START_FAILED':
        return '启动失败，请重试';
      case 'TASK_CLONE_SOURCE_NOT_FOUND':
        return '源任务不存在';
      case 'TASK_CLONE_TARGET_KB_NOT_FOUND':
        return '目标知识库不存在';
      case 'TASK_APPROVE_FAILED':
        return '确认失败，请重试';
      case 'TASK_DELETE_FAILED':
        return '删除失败，请重试';

      // ---- QA（6 个码）----
      case 'QA_RECORD_NOT_FOUND':
        return '问答记录不存在';
      case 'QA_TASK_NOT_FOUND':
        return '关联的总结任务不存在';
      case 'QA_AGENT_NOT_CONFIGURED':
        return '服务暂不可用，请稍后重试';
      case 'QA_ACCESS_DENIED':
        return '无权访问该问答记录';
      case 'QA_DELETE_FAILED':
        return '删除失败，请重试';
      case 'QA_STREAM_ERROR':
        return '回答生成失败，请重试';

      // ---- GQA（4 个码）----
      case 'GQA_RECORD_NOT_FOUND':
        return '全局问答记录不存在';
      case 'GQA_ACCESS_DENIED':
        return '无权访问';
      case 'GQA_DELETE_FAILED':
        return '删除失败，请重试';
      case 'GQA_STREAM_ERROR':
        return '回答生成失败，请重试';

      // ---- CHAT（3 个码）----
      case 'CHAT_SESSION_NOT_FOUND':
        return '对话不存在';
      case 'CHAT_ACCESS_DENIED':
        return '无权访问该对话';
      case 'CHAT_DELETE_FAILED':
        return '删除失败，请重试';

      // ---- UPLOAD（7 个码）----
      case 'UPLOAD_SESSION_NOT_FOUND':
        return '上传已过期，请重新上传';
      case 'UPLOAD_SESSION_NOT_OWNER':
        return '无权操作此上传';
      case 'UPLOAD_SESSION_TERMINAL_STATE':
        return '上传已结束，请重新上传';
      case 'UPLOAD_CHUNK_INDEX_OUT_OF_RANGE':
        return '分片索引错误，请重试';
      case 'UPLOAD_CHUNK_SIZE_MISMATCH':
        return '分片大小错误，请重试';
      case 'UPLOAD_CHUNK_BODY_EMPTY':
        return '分片内容为空，请重试';
      case 'UPLOAD_FINALIZE_FAILED':
        return '上传处理失败，请重试';

      // ---- ATTACH（4 个码）----
      case 'ATTACH_FILE_TOO_LARGE':
        return '文件过大，请选择更小的文件';
      case 'ATTACH_UNSUPPORTED_TYPE':
        return '不支持的文件格式';
      case 'ATTACH_FILE_EMPTY':
        return '请选择有效文件';
      case 'ATTACH_UPLOAD_FAILED':
        return '上传失败，请重试';

      // ---- DEVICE（5 个码）----
      case 'DEVICE_NOT_FOUND':
        return '设备不存在';
      case 'DEVICE_NOT_OWNER':
        return '无权操作此设备';
      case 'DEVICE_REGISTER_FAILED':
        return '注册失败，请重试';
      case 'DEVICE_UNREGISTER_FAILED':
        return '注销失败，请重试';
      case 'DEVICE_LIST_FAILED':
        return '加载失败，请重试';

      // ---- REQUEST（3 个码）----
      case 'REQUEST_VALIDATE_INVALID_PAYLOAD':
        return '输入数据格式不正确，请检查后重试';
      case 'REQUEST_UNSUPPORTED_FIELDS':
        return '请求包含不支持的字段，请检查后重试';
      case 'REQUEST_INVALID_QUERY_PARAM':
        return '查询参数不合法，请检查后重试';

      // ---- SYSTEM（5 个码）----
      case 'SYSTEM_RUNTIME_INTERNAL_ERROR':
        return '服务器异常，请稍后重试';
      case 'SYSTEM_STORAGE_BACKEND_ERROR':
        return '服务配置异常';
      case 'SYSTEM_STORAGE_FILE_NOT_FOUND':
        return '文件不存在';
      case 'SYSTEM_DATABASE_ERROR':
        return '服务暂不可用，请稍后重试';
      case 'SYSTEM_SERVICE_UNAVAILABLE':
        return '服务维护中，请稍后重试';

      // ---- 废弃码 / 未知码 ----
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP statusCode 映射
  // ---------------------------------------------------------------------------

  /// HTTP 状态码 → 用户友好消息。
  static String? _httpStatusMessage(int statusCode) {
    return switch (statusCode) {
      400 => '请求参数有误，请检查输入内容',
      401 => '登录已过期，请重新登录',
      403 => '您没有权限执行此操作',
      404 => '请求的资源不存在',
      413 => '文件过大',
      415 => '不支持的文件格式',
      422 => '输入数据格式不正确，请检查后重试',
      429 => '操作太频繁，请稍后再试',
      500 || 502 || 503 => '服务器繁忙，请稍后重试',
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // 关键词兜底匹配（仅用于非 ApiError 的异常）
  // ---------------------------------------------------------------------------

  /// 将非 ApiError 异常的关键词映射为用户可读提示。
  /// 仅保留网络 / 技术类异常关键词；业务类错误（注册、冲突等）
  /// 已由 [fromApiError] 覆盖，此处不再保留以避免误匹配。
  static String _displayFallback(String raw) {
    // ---- 网络相关 ----
    if (_containsAny(raw, [
      'SocketException',
      'Connection refused',
      'Connection reset',
      'Connection timed out',
      'No route to host',
      'Network is unreachable',
      'Failed host lookup',
    ])) {
      return '网络连接失败，请检查网络后重试';
    }

    // ---- 超时 ----
    if (_containsAny(raw, ['timeout', '超时', 'timed out'])) {
      return '请求超时，请检查网络后重试';
    }

    // ---- WebSocket ----
    if (_containsAny(raw, ['WebSocket', 'ws:', 'not connected', '未连接'])) {
      return '实时连接失败，请检查网络后重试';
    }

    // 安全过滤
    return _sanitize(raw);
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  /// 安全过滤原始文本，避免暴露技术细节。
  static String _sanitize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '操作失败，请稍后重试';

    // 技术错误信息 → 通用消息
    if (trimmed.contains('Exception') ||
        trimmed.contains('Stack trace') ||
        trimmed.contains('.dart')) {
      return '操作失败，请稍后重试';
    }

    return trimmed;
  }

  static bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((kw) => lower.contains(kw.toLowerCase()));
  }
}
