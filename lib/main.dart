import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/api/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 固定竖屏，禁止自动旋转为横屏
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 恢复持久化的 baseUrl（SecureStorage > 环境变量 > 默认值）
  await ApiClient.restoreBaseUrl();

  // 首次通过 --dart-define 指定了 API_BASE_URL 时，自动持久化，
  // 之后不再需要 --dart-define
  const explicitUrl = String.fromEnvironment('API_BASE_URL');
  if (explicitUrl.isNotEmpty) {
    await ApiClient.updateBaseUrl(explicitUrl);
  }

  runApp(const ProviderScope(child: VidNexusApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const VidNexusApp();
  }
}
