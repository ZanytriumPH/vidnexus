import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class VidNexusApp extends StatelessWidget {
  const VidNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidNexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // AuthGate 作为首页守卫：启动时检查登录状态，
      // 已登录进入主页，未登录进入登录页。
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
