import 'package:flutter/material.dart';

import '../../../../app/widgets/app_user_avatar.dart';
import '../../../app/theme/app_colors.dart';
import 'video_summary_drawer_shared.dart';

class VideoSummaryHistoryDrawer extends StatelessWidget {
  const VideoSummaryHistoryDrawer({
    required this.sessions,
    required this.onNewSessionPressed,
    required this.onSessionSelected,
    required this.onSettingsPressed,
    required this.onSearchPressed,
    this.isLoadingHistory = false,
    this.errorMessage,
    this.onRetryHistory,
    super.key,
  });

  final List<VideoSummaryDrawerSessionItem> sessions;
  final VoidCallback onNewSessionPressed;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onSearchPressed;
  final bool isLoadingHistory;
  final String? errorMessage;
  final VoidCallback? onRetryHistory;

  Widget _buildSessionList(BuildContext context) {
    if (isLoadingHistory && sessions.length <= 1) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text(
                '加载历史会话中…',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && sessions.length <= 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
              if (onRetryHistory != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onRetryHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重试', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return VideoSummaryDrawerSessionCard(
          session: session,
          onTap: () => onSessionSelected(session.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '会话中心',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: onSearchPressed,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: onNewSessionPressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '＋',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '新建视频总结会话',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '历史会话',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildSessionList(context),
              ),
              const SizedBox(height: 14),
              // 用户区（已登录显示头像+用户名，未登录显示"去登录"）
              const AppDrawerUserTile(),
              const SizedBox(height: 10),
              // 设置区
              InkWell(
                onTap: onSettingsPressed,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '设置',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            Text(
                              '调整会话默认行为',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
