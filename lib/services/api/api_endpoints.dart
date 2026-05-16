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
}
