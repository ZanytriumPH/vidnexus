import 'package:flutter/material.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_buttons.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_page_scaffold.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.currentSection,
    required this.items,
    required this.primaryActionLabel,
    super.key,
  });

  const ModulePlaceholderScreen.knowledgeBase({super.key})
    : title = '知识库',
      subtitle = '这里只保留知识资产模块入口，具体页面会在后续阶段逐步补齐。',
      currentSection = AppNavSection.knowledgeBase,
      items = const ['3. 首页', '3.1 会话', '3.2 聊天', '3.3 来源'],
      primaryActionLabel = '返回视频入口';

  final String title;
  final String subtitle;
  final AppNavSection currentSection;
  final List<String> items;
  final String primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: title,
      subtitle: subtitle,
      currentSection: currentSection,
      onSectionSelected: (section) => _handleSectionSelection(context, section),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            backgroundColor: AppColors.surfaceMuted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前阶段只接了路由壳子',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '后续页面会沿用同一套卡片、按钮、输入区和底部导航样式继续展开。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('预留页面', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppPrimaryButton(
            label: primaryActionLabel,
            onPressed: () => AppNavigator.goToHomeRoot(context),
          ),
        ],
      ),
    );
  }

  void _handleSectionSelection(BuildContext context, AppNavSection section) {
    switch (section) {
      case AppNavSection.videoSummary:
        AppNavigator.goToHomeRoot(context);
      case AppNavSection.knowledgeBase:
        if (currentSection != AppNavSection.knowledgeBase) {
          AppNavigator.goToKnowledgeBaseHome(context);
        }
    }
  }
}
