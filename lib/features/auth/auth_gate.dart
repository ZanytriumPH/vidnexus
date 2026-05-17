import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../home/home_screen.dart';
import 'auth_controller.dart';
import 'auth_state.dart';
import 'login_screen.dart';

/// 启动时认证守卫：等待 AuthController 恢复会话结果，
/// 根据登录状态决定展示主页还是登录页。
///
/// 同时监听 [AuthState.sessionExpired] 标志，
/// 在 token 过期时弹出提示并跳转到登录页。
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _sessionExpiredHandled = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // 首次加载中 → 启动画面
    if (authState.isLoading) {
      return const _SplashScreen();
    }

    // 会话过期 → 弹出提示
    if (authState.sessionExpired && !_sessionExpiredHandled) {
      _sessionExpiredHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSessionExpiredDialog(context);
        ref.read(authControllerProvider.notifier).clearSessionExpired();
      });
    }

    if (authState.isLoggedIn) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }

  void _showSessionExpiredDialog(BuildContext context) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('登录已过期'),
        content: const Text('你的登录状态已过期，请重新登录。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 启动画面：品牌 Logo + 加载指示器。
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'VidNexus',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
