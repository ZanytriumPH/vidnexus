import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class VideoSummaryDrawerSessionItem {
  const VideoSummaryDrawerSessionItem({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.detail,
    required this.isActive,
  });

  final String id;
  final String title;
  final String durationLabel;
  final String detail;
  final bool isActive;
}

class VideoSummaryDrawerSessionCard extends StatelessWidget {
  const VideoSummaryDrawerSessionCard({
    required this.session,
    required this.onTap,
    super.key,
  });

  final VideoSummaryDrawerSessionItem session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: session.isActive ? const Color(0xFFF3F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: session.isActive
                ? const Color(0xFFBFD3FF)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.durationLabel.isNotEmpty
                        ? '${session.title} / ${session.durationLabel}'
                        : session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (session.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '当前',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              session.detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}