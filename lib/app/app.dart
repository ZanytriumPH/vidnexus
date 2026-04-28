import 'package:flutter/material.dart';

import '../features/home/fake_video_summary_repository.dart';
import '../features/home/home_screen.dart';
import '../features/module_placeholder/module_placeholder_screen.dart';
import 'theme/app_theme.dart';

class VidNexusApp extends StatelessWidget {
  const VidNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidNexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (_) =>
            HomeScreen(repository: const FakeVideoSummaryRepository()),
        ModulePlaceholderScreen.knowledgeRouteName: (_) =>
            const ModulePlaceholderScreen.knowledgeBase(),
      },
    );
  }
}
