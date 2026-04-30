import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.labelStyle,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = labelStyle == null
        ? null
        : Theme.of(context).elevatedButtonTheme.style?.copyWith(
                textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
              ) ??
              ButtonStyle(
                textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
              );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Text(label),
      ),
    );
  }
}

class AppSecondaryPillButton extends StatelessWidget {
  const AppSecondaryPillButton({
    required this.label,
    this.leading,
    this.onPressed,
    super.key,
  });

  final String label;
  final Widget? leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: leading ?? const SizedBox.shrink(),
      label: Text(label),
      style: leading == null
          ? OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            )
          : null,
    );
  }
}

class AppInlineSubmitButton extends StatelessWidget {
  const AppInlineSubmitButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: isLoading
            ? const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                size: 15,
                color: Colors.white,
              ),
      ),
    );
  }
}
