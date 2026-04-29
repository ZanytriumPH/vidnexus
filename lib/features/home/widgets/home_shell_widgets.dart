import 'package:flutter/material.dart';

import '../../../app/widgets/app_bottom_nav.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_card.dart';

class HomeHeaderRow extends StatelessWidget {
  const HomeHeaderRow({
    required this.currentSection,
    required this.onSectionSelected,
    required this.onMenuPressed,
    required this.onNewSessionPressed,
    super.key,
  });

  final AppNavSection currentSection;
  final ValueChanged<AppNavSection> onSectionSelected;
  final VoidCallback onMenuPressed;
  final VoidCallback onNewSessionPressed;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeaderBar(
      current: currentSection,
      onSelected: onSectionSelected,
      leading: RoundGhostButton(
        size: 44,
        onPressed: onMenuPressed,
        child: const Icon(Icons.menu_rounded, size: 20),
      ),
      trailing: RoundGhostButton(
        outlined: true,
        size: 35,
        onPressed: onNewSessionPressed,
        child: const Icon(Icons.add_rounded, size: 18),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.title, required this.centered, super.key});

  final String title;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class PreferenceCard extends StatelessWidget {
  const PreferenceCard({
    required this.controller,
    required this.hintText,
    this.singleLine = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        height: singleLine ? 50 : 86,
        child: TextField(
          controller: controller,
          maxLines: singleLine ? 1 : 4,
          minLines: singleLine ? 1 : 4,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textHint,
              height: 1.45,
            ),
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.45),
        ),
      ),
    );
  }
}

class RoundGhostButton extends StatelessWidget {
  const RoundGhostButton({
    required this.child,
    required this.onPressed,
    this.outlined = false,
    this.size = 44,
    super.key,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool outlined;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 2),
        side: outlined
            ? const BorderSide(color: AppColors.borderStrong)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}
