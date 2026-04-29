import 'package:flutter/material.dart';

import 'routing/app_router.dart';
import 'routing/app_routes.dart';
import 'theme/app_theme.dart';

class VidNexusApp extends StatelessWidget {
  const VidNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidNexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
