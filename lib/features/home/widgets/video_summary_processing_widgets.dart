import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.stage,
    required this.highlighted,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.processingExpanded,
    required this.onTap,
    super.key,
  });

  final VideoSummaryStage stage;
  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final bool processingExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isReady = stage == VideoSummaryStage.ready;
    if (isReady) {
      return _ReadyUploadHeroCard(
        highlighted: highlighted,
        videoAsset: videoAsset,
        onTap: onTap,
      );
    }

    final bool isProcessing = stage == VideoSummaryStage.processing;
    final bool isDraft = stage == VideoSummaryStage.draft;
    final bool isFinal = stage == VideoSummaryStage.finalChat;
    final String pillLabel = switch (stage) {
      VideoSummaryStage.ready => '本地上传',
      VideoSummaryStage.processing => processingSnapshot?.statusLabel ?? '处理中',
      VideoSummaryStage.draft => '处理已完成',
      VideoSummaryStage.finalChat => '终稿已生成',
    };
    final String title = switch (stage) {
      VideoSummaryStage.ready => '本地上传',
      VideoSummaryStage.processing => '正在生成结构化初稿',
      VideoSummaryStage.draft => '初稿已生成，处理详情已自动折叠',
      VideoSummaryStage.finalChat => '当前会话已切换为可追问对话窗口',
    };
    final String subtitle = switch (stage) {
      VideoSummaryStage.ready => '从设备选择文件',
      VideoSummaryStage.processing =>
        processingSnapshot?.etaLabel ?? '正在准备处理内容。',
      VideoSummaryStage.draft => '你现在可以调整偏好指令，再补充摘要层次。',
      VideoSummaryStage.finalChat => '先展示系统总结，再决定是否用时间范围追问。',
    };

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDE2FF), Color(0xFFE9F5FF)],
      ),
      borderColor: const Color(0xFFD3E7F8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(label: pillLabel),
                const Spacer(),
                if (isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      processingExpanded ? '点击收起详情' : '点击展开详情',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: const Color(0xFF384A59),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            if (isProcessing && processingSnapshot != null) ...[
              Text(
                '${videoAsset.fileName} · ${videoAsset.durationLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: const Color(0xFF51606D),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AnimatedProgressBar(
                      value: processingSnapshot!.progress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFD9EAF8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(processingSnapshot!.progress * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: processingSnapshot!.badges
                    .map((badge) => ProcessingBadgeChip(badge: badge))
                    .toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    processingExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    processingExpanded ? '点击蓝色卡片可收起详细处理信息' : '点击蓝色卡片可展开详细处理信息',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (isDraft || isFinal)
              const WhiteButtonBar(
                label: '视频回放',
                leadingIcon: Icons.play_arrow_rounded,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadyUploadHeroCard extends StatelessWidget {
  const _ReadyUploadHeroCard({
    required this.highlighted,
    required this.videoAsset,
    required this.onTap,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFAEDCFF), Color(0xFFF3FAFF)],
      ),
      borderColor: const Color(0xFFD4E7F7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 140,
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text(
                '本地上传',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              _ReadyUploadCallout(
                highlighted: highlighted,
                videoAsset: videoAsset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyUploadCallout extends StatelessWidget {
  const _ReadyUploadCallout({
    required this.highlighted,
    required this.videoAsset,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            highlighted ? '✓' : '+',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            highlighted ? '已选择 ${videoAsset.fileName}' : '点击从设备选择文件',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCFF),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class WhiteButtonBar extends StatelessWidget {
  const WhiteButtonBar({
    required this.label,
    required this.leadingIcon,
    super.key,
  });

  final String label;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4DCE5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(leadingIcon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingBadgeChip extends StatelessWidget {
  const ProcessingBadgeChip({required this.badge, super.key});

  final ProcessingBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.active ? const Color(0xFF1F5BEA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.active
              ? const Color(0xFF1F5BEA)
              : const Color(0xFFD7E0E8),
        ),
      ),
      child: Text(
        badge.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: badge.active ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class ProcessingDetailCard extends StatelessWidget {
  const ProcessingDetailCard({required this.snapshot, super.key});

  final ProcessingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '详细处理信息',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '实时刷新',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '展开后显示实时任务进度',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          ...snapshot.steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ProcessingStepTile(step: step),
            ),
          ),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '完成后自动进入总结草稿\n展示摘要、结构大纲和建议指令入口',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingCollapsedHintCard extends StatelessWidget {
  const ProcessingCollapsedHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '详细处理信息已收起',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '点击上方蓝色卡片可再次展开，查看各步骤实时进度。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingStepTile extends StatelessWidget {
  const ProcessingStepTile({required this.step, super.key});

  final ProcessingStep step;

  @override
  Widget build(BuildContext context) {
    final progressValue = step.progress / 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '${step.progress}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedProgressBar(
            value: progressValue,
            minHeight: 4,
            backgroundColor: const Color(0xFFE3E9EF),
          ),
          const SizedBox(height: 6),
          Text(
            step.detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
    super.key,
  });

  final double value;
  final double minHeight;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: safeValue),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor(animatedValue),
            ),
          ),
        );
      },
    );
  }
}

Color progressColor(double value) {
  final safeValue = value.clamp(0.0, 1.0);
  return Color.lerp(
        const Color(0xFFAED8FF),
        const Color(0xFF1F5BEA),
        safeValue,
      ) ??
      AppColors.primary;
}
