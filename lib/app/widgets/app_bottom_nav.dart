import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppNavSection { videoSummary, knowledgeBase }

class AppSectionHeaderBar extends StatelessWidget {
  const AppSectionHeaderBar({
    required this.current,
    required this.onSelected,
    this.leading,
    this.trailing,
    super.key,
  });

  final AppNavSection current;
  final ValueChanged<AppNavSection> onSelected;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: leading ?? const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppBottomNav(current: current, onSelected: onSelected),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    required this.current,
    required this.onSelected,
    super.key,
  });

  final AppNavSection current;
  final ValueChanged<AppNavSection> onSelected;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  static const _selectionAnimationDuration = Duration(milliseconds: 180);

  late AppNavSection _visualCurrent;
  bool _isAnimatingSelection = false;

  @override
  void initState() {
    super.initState();
    _visualCurrent = widget.current;
  }

  @override
  void didUpdateWidget(covariant AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current && !_isAnimatingSelection) {
      _visualCurrent = widget.current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabelStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
    final unselectedLabelStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    );

    return SizedBox(
      height: 36,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavItem(
              label: '视频总结',
              selected: _visualCurrent == AppNavSection.videoSummary,
              selectedLabelStyle: selectedLabelStyle,
              unselectedLabelStyle: unselectedLabelStyle,
              onTap: () => _handleTap(AppNavSection.videoSummary),
            ),
            const SizedBox(width: 20),
            _NavItem(
              label: '知识库',
              selected: _visualCurrent == AppNavSection.knowledgeBase,
              selectedLabelStyle: selectedLabelStyle,
              unselectedLabelStyle: unselectedLabelStyle,
              onTap: () => _handleTap(AppNavSection.knowledgeBase),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(AppNavSection section) async {
    if (_isAnimatingSelection || section == widget.current) {
      return;
    }

    setState(() {
      _isAnimatingSelection = true;
      _visualCurrent = section;
    });

    await Future<void>.delayed(_selectionAnimationDuration);
    if (!mounted) {
      return;
    }

    widget.onSelected(section);

    if (!mounted) {
      return;
    }

    setState(() {
      _isAnimatingSelection = false;
    });
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.selectedLabelStyle,
    required this.unselectedLabelStyle,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: selected
                ? (selectedLabelStyle ?? const TextStyle())
                : (unselectedLabelStyle ?? const TextStyle()),
            child: Text(label),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: selected ? 26 : 10,
            height: 2.5,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
