/// 错误消息映射工具：将技术错误转为用户可读的中文提示。
class UserFriendlyError {
  UserFriendlyError._();

  /// 从原始异常提取用户可读消息。
  static String fromException(Object e) {
    if (e is String) return mapMessage(e);
    return mapMessage(e.toString());
  }

  /// 将后端返回的原始 detail/message 映射为用户可读提示。
  static String mapMessage(String raw) {
    // ---- 用户名 / 注册相关 ----
    if (_containsAny(raw, ['already exists', 'already_exist', '已存在', 'duplicate', 'already registered'])) {
      return '该用户名已存在，请更换后重试';
    }
    if (_containsAny(raw, ['invalid username', 'username not found', 'user not found', '用户名', 'user does not exist'])) {
      return '用户名不存在，请检查后重试';
    }

    // ---- 密码 / 登录凭证相关 ----
    if (_containsAny(raw, ['invalid password', 'incorrect password', 'wrong password', '密码错误', 'invalid credentials', 'credentials'])) {
      return '用户名或密码错误，请检查后重试';
    }

    // ---- Token / 认证相关 ----
    if (_containsAny(raw, ['token expired', 'token invalid', 'unauthorized', 'not authenticated', 'session expired'])) {
      return '登录已过期，请重新登录';
    }
    if (_containsAny(raw, ['forbidden', 'permission', '权限', 'access denied'])) {
      return '您没有权限执行此操作';
    }

    // ---- 网络相关 ----
    if (_containsAny(raw, ['SocketException', 'Connection refused', 'Connection reset', 'Connection timed out', 'No route to host', 'Network is unreachable', 'network', 'timeout', '超时', 'Failed host lookup'])) {
      return '网络连接失败，请检查网络后重试';
    }

    // ---- 上传相关 ----
    if (_containsAny(raw, ['file too large', 'exceeds maximum', '文件过大', 'size limit'])) {
      return '文件过大，请选择较小的文件';
    }
    if (_containsAny(raw, ['unsupported format', 'invalid format', '格式不支持', 'file type', 'mime type'])) {
      return '文件格式不支持，请检查文件后重试';
    }
    if (_containsAny(raw, ['upload failed', '上传失败'])) {
      return '上传失败，请稍后重试';
    }

    // ---- WebSocket 相关 ----
    if (_containsAny(raw, ['WebSocket', 'ws', 'not connected', '未连接'])) {
      return '实时连接失败，请检查网络后重试';
    }

    // ---- 任务/资源冲突 ----
    if (_containsAny(raw, ['conflict', 'already exists', 'duplicate task', '409'])) {
      return '该操作与已有记录冲突，请检查后重试';
    }

    // ---- 资源不存在 ----
    if (_containsAny(raw, ['not found', 'not_found', '不存在', '404'])) {
      return '请求的资源不存在或已被删除';
    }

    // ---- 服务器错误 ----
    if (_containsAny(raw, ['internal server error', '500', '502', '503', 'server error', '服务器'])) {
      return '服务器繁忙，请稍后重试';
    }

    // ---- 请求频率限制 ----
    if (_containsAny(raw, ['rate limit', 'too many requests', '429'])) {
      return '操作太频繁，请稍后再试';
    }

    // ---- 参数校验 ----
    if (_containsAny(raw, ['validation', 'invalid', '422', 'unprocessable'])) {
      return '输入数据格式不正确，请检查后重试';
    }

    // 如果都不匹配，返回原始消息（安全过滤后的）
    // 避免暴露技术细节给用户
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '操作失败，请稍后重试';

    // 如果原始消息看起来像技术错误（含 Exception / stack trace），使用通用消息
    if (trimmed.contains('Exception') || trimmed.contains('Stack trace') || trimmed.contains('.dart')) {
      return '操作失败，请稍后重试';
    }

    return trimmed;
  }

  static bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((kw) => lower.contains(kw.toLowerCase()));
  }
}
