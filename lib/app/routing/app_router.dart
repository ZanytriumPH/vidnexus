import 'package:flutter/material.dart';

import 'app_route_arguments.dart';
import 'app_route_error_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/video_summary_search_screen.dart';
import '../../features/knowledge_base/knowledge_base_chat_screen.dart';
import '../../features/knowledge_base/knowledge_base_home_screen.dart';
import '../../features/knowledge_base/knowledge_base_models.dart';
import '../../features/knowledge_base/knowledge_base_session_screen.dart';
import '../../features/knowledge_base/knowledge_base_sources_screen.dart';
import 'app_routes.dart';

/// 统一处理命名路由到页面实例的映射。
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    try {
      switch (settings.name) {
        case AppRoutes.home:
          final args = settings.arguments as HomeRouteArguments?;
          return _buildRoute(
            settings: settings,
            builder: (_) => HomeScreen(
              videoId: args?.videoId,
              taskId: args?.taskId,
            ),
          );
        case AppRoutes.videoSummarySearch:
          final args = _requireArguments<VideoSummarySearchRouteArguments>(
            settings,
          );
          return _buildRoute<String?>(
            settings: settings,
            builder: (_) => VideoSummarySearchScreen(sessions: args.sessions),
          );
        case AppRoutes.knowledgeBaseHome:
          return _buildRoute(
            settings: settings,
            builder: (_) => const KnowledgeBaseHomeScreen(),
          );
        case AppRoutes.knowledgeBaseSession:
          final args = _requireArguments<KnowledgeBaseSessionRouteArguments>(
            settings,
          );
          return _buildRoute(
            settings: settings,
            builder: (_) => KnowledgeBaseSessionScreen(kbid: args.kbid),
          );
        case AppRoutes.knowledgeBaseChat:
          final args = _requireArguments<KnowledgeBaseChatRouteArguments>(
            settings,
          );
          return _buildRoute(
            settings: settings,
            builder: (_) => KnowledgeBaseChatScreen(
              kbid: args.kbid,
              initialConversation: args.initialConversation,
            ),
          );
        case AppRoutes.knowledgeBaseSources:
          final args = _requireArguments<KnowledgeBaseSourcesRouteArguments>(
            settings,
          );
          return _buildRoute(
            settings: settings,
            builder: (_) => KnowledgeBaseSourcesScreen(kbid: args.kbid),
          );
        case AppRoutes.authLogin:
          return _buildRoute(
            settings: settings,
            builder: (_) => const LoginScreen(),
          );
        case AppRoutes.authRegister:
          return _buildRoute(
            settings: settings,
            builder: (_) => const RegisterScreen(),
          );
        default:
          return onUnknownRoute(settings);
      }
    } on ArgumentError catch (error) {
      return _buildRouteError(
        settings: settings,
        title: '路由参数错误',
        message: error.message?.toString() ?? '当前页面缺少必要参数。',
      );
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _buildRouteError(
      settings: settings,
      title: '未找到页面',
      message: '未注册路由：${settings.name ?? 'unknown'}',
    );
  }
}

/// 统一封装 Route 构建，确保所有页面都能拿到原始 RouteSettings。
MaterialPageRoute<T> _buildRoute<T extends Object?>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<T>(builder: builder, settings: settings);
}

MaterialPageRoute<void> _buildRouteError({
  required RouteSettings settings,
  required String title,
  required String message,
}) {
  return _buildRoute(
    settings: settings,
    builder: (_) => AppRouteErrorScreen(title: title, message: message),
  );
}

/// 参数化页面统一在这里做类型检查，避免页面层自己兜底猜参数。
T _requireArguments<T>(RouteSettings settings) {
  final arguments = settings.arguments;
  if (arguments is T) {
    return arguments;
  }

  throw ArgumentError(
    'Route ${settings.name} requires arguments of type $T, '
    'but received ${arguments.runtimeType}.',
  );
}

/// 页面层只调用这里的语义化导航方法，不直接关心 pushNamed 细节。
class AppNavigator {
  const AppNavigator._();

  static void popCurrent<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  static void goToHomeRoot(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
  }

  /// 跳转到首页并自动恢复指定视频的总结会话。
  ///
  /// 当同时提供 [taskId] 时，会直接通过 taskId 获取任务详情（无需 listTasks 全量匹配），
  /// 优先用于知识库 cited_resources 点击等已有明确 task 的场景。
  static void goToHomeWithVideo(
    BuildContext context, {
    required String videoId,
    String? taskId,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: HomeRouteArguments(videoId: videoId, taskId: taskId),
    );
  }

  static void goToKnowledgeBaseHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.knowledgeBaseHome,
      (route) => false,
    );
  }

  static void popToKnowledgeBaseHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  static Future<void> openKnowledgeBaseSession(
    BuildContext context, {
    required String kbid,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseSession,
      arguments: KnowledgeBaseSessionRouteArguments(kbid: kbid),
    );
  }

  static Future<void> openKnowledgeBaseChat(
    BuildContext context, {
    required String kbid,
    required KnowledgeConversationPreview initialConversation,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseChat,
      arguments: KnowledgeBaseChatRouteArguments(
        kbid: kbid,
        initialConversation: initialConversation,
      ),
    );
  }

  static Future<void> openKnowledgeBaseSources(
    BuildContext context, {
    required String kbid,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseSources,
      arguments: KnowledgeBaseSourcesRouteArguments(kbid: kbid),
    );
  }

  static Future<String?> openVideoSummarySearch(
    BuildContext context, {
    required VideoSummarySearchRouteArguments arguments,
  }) {
    return Navigator.of(context).pushNamed<String>(
      AppRoutes.videoSummarySearch,
      arguments: arguments,
    );
  }

  static Future<void> openLogin(BuildContext context) {
    return Navigator.of(context).pushNamed<void>(AppRoutes.authLogin);
  }

  static Future<void> openRegister(BuildContext context) {
    return Navigator.of(context).pushNamed<void>(AppRoutes.authRegister);
  }
}