import 'package:flutter/material.dart';

import 'app_route_arguments.dart';
import 'app_route_error_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/knowledge_base/knowledge_base_chat_screen.dart';
import '../../features/knowledge_base/knowledge_base_home_screen.dart';
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
          return _buildRoute(
            settings: settings,
            builder: (_) => const HomeScreen(),
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
            builder: (_) => KnowledgeBaseSessionScreen(library: args.library),
          );
        case AppRoutes.knowledgeBaseChat:
          final args = _requireArguments<KnowledgeBaseChatRouteArguments>(
            settings,
          );
          return _buildRoute(
            settings: settings,
            builder: (_) => KnowledgeBaseChatScreen(
              library: args.library,
              initialConversation: args.initialConversation,
            ),
          );
        case AppRoutes.knowledgeBaseSources:
          final args = _requireArguments<KnowledgeBaseSourcesRouteArguments>(
            settings,
          );
          return _buildRoute(
            settings: settings,
            builder: (_) => KnowledgeBaseSourcesScreen(library: args.library),
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
MaterialPageRoute<void> _buildRoute({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<void>(builder: builder, settings: settings);
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
    required KnowledgeBaseSessionRouteArguments arguments,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseSession,
      arguments: arguments,
    );
  }

  static Future<void> openKnowledgeBaseChat(
    BuildContext context, {
    required KnowledgeBaseChatRouteArguments arguments,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseChat,
      arguments: arguments,
    );
  }

  static Future<void> openKnowledgeBaseSources(
    BuildContext context, {
    required KnowledgeBaseSourcesRouteArguments arguments,
  }) {
    return Navigator.of(context).pushNamed<void>(
      AppRoutes.knowledgeBaseSources,
      arguments: arguments,
    );
  }
}