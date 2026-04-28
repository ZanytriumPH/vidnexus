import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppNavSection { videoSummary, knowledgeBase }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.current,
    required this.onSelected,
    super.key,
  });

  final AppNavSection current;
  final ValueChanged<AppNavSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              label: '视频总结',
              icon: Icons.play_arrow_rounded,
              selected: current == AppNavSection.videoSummary,
              labelStyle: labelStyle,
              onTap: () => onSelected(AppNavSection.videoSummary),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: '知识库',
              icon: Icons.bookmarks_outlined,
              selected: current == AppNavSection.knowledgeBase,
              labelStyle: labelStyle,
              onTap: () => onSelected(AppNavSection.knowledgeBase),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.labelStyle,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeChild = Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0F3F7) : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );

    if (selected) {
      return activeChild;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: activeChild,
    );
  }
}
