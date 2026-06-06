import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_bottom_nav.dart';
import '../../app/widgets/app_header_add_button.dart';
import '../../app/widgets/app_card.dart';
import 'application/knowledge_base_controller.dart';
import 'knowledge_base_models.dart';
import 'widgets/knowledge_base_shared_widgets.dart';

class KnowledgeBaseSourcesScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseSourcesScreen({required this.kbid, super.key});

  final String kbid;

  @override
  ConsumerState<KnowledgeBaseSourcesScreen> createState() =>
      _KnowledgeBaseSourcesScreenState();
}

class _KnowledgeBaseSourcesScreenState
    extends ConsumerState<KnowledgeBaseSourcesScreen> {
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(selectedLibraryControllerProvider).selectedLibrary;
    final sources = library?.sources ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: KnowledgeBaseTopBar(
                currentSection: AppNavSection.knowledgeBase,
                onSectionSelected: (section) {
                  switch (section) {
                    case AppNavSection.videoSummary:
                      AppNavigator.goToHomeRoot(context);
                    case AppNavSection.knowledgeBase:
                      AppNavigator.popToKnowledgeBaseHome(context);
                  }
                },
                title: '来源',
                onLeadingPressed: () => AppNavigator.popCurrent(context),
                trailing: AppHeaderAddButton(
                  onPressed: () => _openNewConversation(context, ref),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '管理当前知识库中可被引用的资料',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (sources.isEmpty)
                      Text(
                        '暂无来源资料',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      )
                    else
                      ...sources.map(
                        (source) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _KnowledgeSourceCard(
                            source: source,
                            onDelete: () => _confirmDeleteSource(source),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewConversation(BuildContext context, WidgetRef ref) {
    final libraryTitle =
        ref.read(selectedLibraryControllerProvider).selectedLibrary?.title ?? '';
    AppNavigator.openKnowledgeBaseChat(
      context,
      kbid: widget.kbid,
      initialConversation: buildEmptyKnowledgeConversation(
        libraryTitle: libraryTitle,
      ),
    );
  }

  Future<void> _confirmDeleteSource(KnowledgeSourceItem source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除来源'),
        content: Text('确定要从知识库中移除"${source.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref
          .read(selectedLibraryControllerProvider.notifier)
          .deleteSource(source.id);
    }
  }
}

class _KnowledgeSourceCard extends StatelessWidget {
  const _KnowledgeSourceCard({required this.source, required this.onDelete});

  final KnowledgeSourceItem source;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppNavigator.goToHomeWithVideo(
        context,
        videoId: source.id,
      ),
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        backgroundColor: Colors.white,
        borderColor: AppColors.borderStrong,
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                source.kindLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  source.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 22, color: AppColors.textHint),
            ),
          ),
        ],
      ),      ),    );
  }
}
