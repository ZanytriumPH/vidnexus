import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_card.dart';
import '../video_summary_models.dart';
import '../video_summary_presentation_models.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.stage,
    required this.videoAsset,
    required this.processingSnapshot,
    required this.processingExpanded,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isFinalGenerating = false,
    this.finalDraftProgressMessage,
    this.onTap,
    this.onVideoPlayback,
    super.key,
  });

  final VideoSummaryStage stage;
  final VideoAssetInfo videoAsset;
  final ProcessingSnapshot? processingSnapshot;
  final bool processingExpanded;
  final bool isUploading;
  final double uploadProgress;
  final bool isFinalGenerating;
  final String? finalDraftProgressMessage;
  final VoidCallback? onTap;
  final VoidCallback? onVideoPlayback;

  @override
  Widget build(BuildContext context) {
    final bool isReady = stage == VideoSummaryStage.ready;
    if (isReady) {
      return _ReadyUploadHeroCard(
        videoAsset: videoAsset,
        isUploading: isUploading,
        uploadProgress: uploadProgress,
        onTap: onTap,
      );
    }

    final bool isProcessing = stage == VideoSummaryStage.processing;
    final bool isDraft = stage == VideoSummaryStage.draft;
    final bool isFinal = stage == VideoSummaryStage.finalChat;
    final bool disableTapOverlay = isDraft || isFinal;
    final String pillLabel = isFinalGenerating
        ? '生成中'
        : switch (stage) {
            VideoSummaryStage.ready => '本地上传',
            VideoSummaryStage.processing =>
              processingSnapshot?.statusLabel ?? '处理中',
            VideoSummaryStage.draft => '处理已完成',
            VideoSummaryStage.finalChat => '终稿已生成',
          };
    final String title = isFinalGenerating
        ? '最终稿生成中...'
        : switch (stage) {
            VideoSummaryStage.ready => '本地上传',
            VideoSummaryStage.processing => '正在生成结构化初稿',
            VideoSummaryStage.draft => '初稿已生成，处理详情已自动折叠',
            VideoSummaryStage.finalChat => '当前会话已切换为可追问对话窗口',
          };
    final String? subtitle = isFinalGenerating
        ? (finalDraftProgressMessage ?? '正在提交审批...')
        : switch (stage) {
            VideoSummaryStage.ready => '从设备选择文件',
            VideoSummaryStage.processing =>
              processingSnapshot?.etaLabel ?? '正在准备处理内容。',
            VideoSummaryStage.draft => '你现在可以按需编辑初稿与补充终稿的总结指导。',
            VideoSummaryStage.finalChat => null,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashFactory: disableTapOverlay ? NoSplash.splashFactory : null,
          overlayColor: disableTapOverlay
              ? WidgetStateProperty.all(Colors.transparent)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    label: videoAsset.kbName?.isNotEmpty == true
                        ? videoAsset.kbName!
                        : pillLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF384A59),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (isProcessing && processingSnapshot != null) ...[
                Text(
                  '${videoAsset.fileName} · ${videoAsset.durationLabel}',
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
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
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              if (isDraft || isFinal)
                WhiteButtonBar(
                  label: '视频回放',
                  leadingIcon: Icons.play_arrow_rounded,
                  onTap: onVideoPlayback,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyUploadHeroCard extends StatelessWidget {
  const _ReadyUploadHeroCard({
    required this.videoAsset,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.onTap,
  });

  final VideoAssetInfo videoAsset;
  final bool isUploading;
  final double uploadProgress;
  final VoidCallback? onTap;

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isUploading ? null : onTap, // 正在上传时禁止点击触发新的上传
          borderRadius: BorderRadius.circular(14),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: SizedBox(
            height: 140,
            child: Column(
              children: [
                const SizedBox(height: 28),
                Text(
                  '本地上传',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                _ReadyUploadCallout(
                  videoAsset: videoAsset,
                  isUploading: isUploading,
                  uploadProgress: uploadProgress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyUploadCallout extends StatelessWidget {
  const _ReadyUploadCallout({
    required this.videoAsset,
    this.isUploading = false,
    this.uploadProgress = 0.0,
  });

  final VideoAssetInfo videoAsset;
  final bool isUploading;
  final double uploadProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isUploading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                uploadProgress >= 1.0
                    ? '正在处理视频，请稍候...'
                    : '正在上传: ${(uploadProgress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Text(
                '点击从设备选择文件',
                textAlign: TextAlign.center,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCFF),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
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
    this.onTap,
    super.key,
  });

  final String label;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD4DCE5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(leadingIcon, size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ProcessingCollapsedHintCard extends StatelessWidget {
  const ProcessingCollapsedHintCard({this.onTap, this.onRefresh, super.key});

  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '点击此处可再次展开，查看各步骤实时进度。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final targetWidth = maxWidth * safeValue;

        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(
                height: minHeight,
                width: double.infinity,
                color: backgroundColor,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                height: minHeight,
                width: targetWidth,
                decoration: BoxDecoration(
                  color: progressColor(safeValue),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
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

/// 知识库名称标签，在 HeroCard / 视频详情 / 侧边栏复用。
class KbNameTag extends StatelessWidget {
  const KbNameTag({required this.kbName, this.kbid, super.key});

  final String kbName;
  final String? kbid;

  @override
  Widget build(BuildContext context) {
    final displayText = kbName.isNotEmpty ? kbName : (kbid ?? '知识库');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD), // 黄色背景
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFC107), width: 0.5),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF856404), // 深黄色文字
        ),
      ),
    );
  }
}
