import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppHeaderAddButton extends StatelessWidget {
  const AppHeaderAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const double _size = 22;
  static const double _borderWidth = 1.6;
  static const double _iconSize = 18;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(_size / 2),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textPrimary,
            width: _borderWidth,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            size: _iconSize,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}