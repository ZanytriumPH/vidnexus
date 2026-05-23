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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 居中的圆形应用图标 (对齐 Android 12+ 系统启动画面规范)
          Center(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // 内部缩进，使图标视觉大小适中
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // 底部品牌区域 (对齐 Android 12+ 系统启动画面规范)
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '智汇视记',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
