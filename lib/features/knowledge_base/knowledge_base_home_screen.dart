import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_header_add_button.dart';
import 'application/knowledge_base_controller.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseHomeScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseHomeScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseHomeScreen> createState() =>
      _KnowledgeBaseHomeScreenState();
}

class _KnowledgeBaseHomeScreenState
    extends ConsumerState<KnowledgeBaseHomeScreen> {
  @override
  void initState() {
    super.initState();
    // 每次进入知识库首页时，确保列表数据已加载。
    // 覆盖两场景：① Provider 缓存中已有旧数据 ② 首次创建 Provider 时 build() 已触发
    Future.microtask(() {
      ref.read(libraryListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryListControllerProvider);
    final controller = ref.read(libraryListControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KnowledgeBaseHeader(
                        currentSection: AppNavSection.knowledgeBase,
                        onSectionSelected: (section) =>
                            _handleSectionSelection(context, section),
                        onCreatePressed: () => _showCreateDialog(context, controller),
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
                      if (state.isLoading && state.libraries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.libraries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              '暂无知识库，点击右上角 + 创建',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        )
                      else
                        _KnowledgeLibraryGrid(libraries: state.libraries),
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
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

  void _showCreateDialog(BuildContext context, LibraryListController controller) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建知识库'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '知识库名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                controller.createLibrary(name: name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
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
  const _KnowledgeLibraryGrid({required this.libraries});

  final List<KnowledgeBaseLibrary> libraries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: libraries
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
    final hasLatestQuestion = item.latestQuestion != null &&
        item.latestQuestion!.isNotEmpty;

    return InkWell(
      onTap: () {
        AppNavigator.openKnowledgeBaseSession(
          context,
          kbid: item.id,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        borderColor: AppColors.borderStrong,
        child: SizedBox(
          height: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                '${item.sourceCount} 份资料',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasLatestQuestion) ...[
                const SizedBox(height: 3),
                Text(
                  '最近提问 "${item.latestQuestion}"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Text(
                item.meta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
