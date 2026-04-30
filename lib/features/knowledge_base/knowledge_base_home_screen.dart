import 'package:flutter/material.dart';

import '../../app/routing/app_route_arguments.dart';
import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_header_add_button.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseHomeScreen extends StatelessWidget {
  const KnowledgeBaseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KnowledgeBaseHeader(
                      currentSection: AppNavSection.knowledgeBase,
                      onSectionSelected: (section) =>
                          _handleSectionSelection(context, section),
                      onCreatePressed: () => _showCreateHint(context),
                    ),
                    const SizedBox(height: 14),
                    const _KnowledgeSearchBar(),
                    const SizedBox(height: 18),
                    Text(
                      '我的知识库',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _KnowledgeLibraryGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSectionSelection(BuildContext context, AppNavSection section) {
    switch (section) {
      case AppNavSection.videoSummary:
        AppNavigator.goToHomeRoot(context);
      case AppNavSection.knowledgeBase:
        return;
    }
  }

  void _showCreateHint(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新建知识库流程将在下一阶段接入。')));
  }
}

class _KnowledgeBaseHeader extends StatelessWidget {
  const _KnowledgeBaseHeader({
    required this.currentSection,
    required this.onSectionSelected,
    required this.onCreatePressed,
  });

  final AppNavSection currentSection;
  final ValueChanged<AppNavSection> onSectionSelected;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KnowledgeBaseTopBar(
          currentSection: currentSection,
          onSectionSelected: onSectionSelected,
          title: '知识库',
          showTitle: false,
          trailing: AppHeaderAddButton(onPressed: onCreatePressed),
        ),
        const SizedBox(height: 12),
        Text(
          '像 NotebookLM 一样管理资料与问答',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _KnowledgeSearchBar extends StatelessWidget {
  const _KnowledgeSearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            '搜索知识库、资料或问答',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeLibraryGrid extends StatelessWidget {
  const _KnowledgeLibraryGrid();

  @override
  Widget build(BuildContext context) {
    const items = demoKnowledgeBaseLibraries;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _KnowledgeLibraryCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KnowledgeLibraryCard extends StatelessWidget {
  const _KnowledgeLibraryCard({required this.item});

  final KnowledgeBaseLibrary item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppNavigator.openKnowledgeBaseSession(
          context,
          arguments: KnowledgeBaseSessionRouteArguments(library: item),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        borderColor: AppColors.borderStrong,
        child: SizedBox(
          height: 121,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.meta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
