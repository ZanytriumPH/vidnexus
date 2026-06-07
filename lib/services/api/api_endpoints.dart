/// 所有 API endpoint 路径常量，与后端 FastAPI 路由严格对齐。
///
/// 来源：app_factory.py 中 create_app() 注册的全部 router。
class ApiEndpoints {
  ApiEndpoints._();

  static const String basePath = '/api/v1';

  // -- system --
  static const String health = '/health';

  // -- auth --
  static const String authRegister = '$basePath/auth/register';
  static const String authLogin = '$basePath/auth/login';
  static const String authRefresh = '$basePath/auth/refresh';
  static const String authMe = '$basePath/auth/me';

  // -- knowledge-bases --
  static const String kbs = '$basePath/kbs';
  static String kb(String kbid) => '$basePath/kbs/$kbid';
  static String kbVideos(String kbid) => '$basePath/kbs/$kbid/videos';
  static String kbVideo(String kbid, String videoId) =>
      '$basePath/kbs/$kbid/videos/$videoId';

  // -- video-resources --
  static const String videos = '$basePath/videos';
  static String video(String videoId) => '$basePath/videos/$videoId';

  /// GET /api/v1/videos/{video_id}/tasks — 查询视频关联的所有摘要任务（分页）。
  static String videoTasks(String videoId) => '$basePath/videos/$videoId/tasks';

  // -- video-summary-tasks --
  static const String tasks = '$basePath/tasks';
  static String task(String taskId) => '$basePath/tasks/$taskId';

  // -- video-qa (nested under task) --
  static String taskQaList(String taskId) => '$basePath/tasks/$taskId/qa';
  static String taskQa(String taskId, String qaId) =>
      '$basePath/tasks/$taskId/qa/$qaId';

  // -- global-chat (nested under kb) --
  static String kbChats(String kbid) => '$basePath/kbs/$kbid/chats';
  static String kbChat(String kbid, String chatId) =>
      '$basePath/kbs/$kbid/chats/$chatId';

  // -- global-qa (nested under kb chat) --
  static String kbChatQaList(String kbid, String chatId) =>
      '$basePath/kbs/$kbid/chats/$chatId/qa';
  static String kbChatQa(String kbid, String chatId, String qaId) =>
      '$basePath/kbs/$kbid/chats/$chatId/qa/$qaId';

  // -- task workflow (new.md 新增) --
  static String taskStartAnalysis(String taskId) =>
      '$basePath/tasks/$taskId/start-analysis';
  static String taskApproveAndFinalize(String taskId) =>
      '$basePath/tasks/$taskId/approve-and-finalize';

  /// POST /api/v1/tasks/{task_id}/clone-to-kb — 将 Task 克隆到另一个 KB。
  static String taskCloneToKb(String taskId) =>
      '$basePath/tasks/$taskId/clone-to-kb';

  // -- time-travel QA stream (new.md 新增) --
  static String taskTimeTravelQAStream(String taskId) =>
      '$basePath/tasks/$taskId/time-travel-qa/stream';

  // -- global QA stream (new.md 新增) --
  static String kbChatQAStream(String kbid, String chatId) =>
      '$basePath/kbs/$kbid/chats/$chatId/qa/stream';

  // -- attachments (new.md 新增) --
  static const String attachmentsUpload = '$basePath/attachments/upload';

  // -- uploads TUS (new.md 新增) --
  static const String uploads = '$basePath/uploads';
  static String upload(String uploadId) => '$basePath/uploads/$uploadId';

  // -- devices (new.md 新增) --
  static const String devices = '$basePath/devices';
  static String device(String deviceTokenId) =>
      '$basePath/devices/$deviceTokenId';
}
