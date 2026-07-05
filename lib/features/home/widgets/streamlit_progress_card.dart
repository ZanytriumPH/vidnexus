import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../video_summary_presentation_models.dart';
import 'video_summary_processing_widgets.dart';

/// 对标 Streamlit app.py 的分片进度面板。
///
/// 渲染 3 条并行进度条（音频/视觉/融合）+ 状态日志区。
class StreamlitProgressCard extends StatelessWidget {
  const StreamlitProgressCard({
    required this.snapshot,
    this.onTap,
    this.onRefresh,
    super.key,
  });

  final ProcessingSnapshot snapshot;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    // chunkProgress 由 ChunkProgressEstimator 保证永不为 null
    final chunk = snapshot.chunkProgress!;
    final statusLog = chunk.statusLog;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 头部：标题 + 刷新按钮 + 收起按钮 ──
            _Header(onTap: onTap, onRefresh: onRefresh),

            const SizedBox(height: 6),

            // ── 分片面板状态提示 ──
            Text(
              '📊 分片进度面板：Send API 实时 fan-out/fan-in',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 12),

            // ── 状态日志 ──
            if (statusLog.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 8),
              _StatusLogSection(log: statusLog),
            ],

            // ── 底部提示 ──
            const SizedBox(height: 10),
            _FooterHint(),
          ],
        ),
      ),
    );
  }
}

/// 头部：标题 "详细处理信息" + 刷新按钮 + 收起标签。
class _Header extends StatelessWidget {
  const _Header({this.onTap, this.onRefresh});

  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '详细处理信息',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        if (onRefresh != null) ...[
          AnimatedRefreshButton(onRefresh: onRefresh!),
          const SizedBox(width: 6),
        ],
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '点击收起',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部提示条：完成后自动进入总结初稿页。
class _FooterHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
              '完成后自动进入总结初稿页\n后续可按需编辑初稿与补充终稿总结指导',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条分片进度条（对标 Streamlit st.progress + st.write）。
class ChunkProgressBarTile extends StatelessWidget {
  const ChunkProgressBarTile({
    required this.bar,
    super.key,
  });

  final ChunkProgressBar bar;

  @override
  Widget build(BuildContext context) {
    final progressValue = (bar.percent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行：图标 + 名称 + 计数 + 百分比
          Row(
            children: [
              Text(
                bar.icon,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bar.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${bar.percent}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // 进度条
          AnimatedProgressBar(
            value: progressValue,
            minHeight: 4,
            backgroundColor: const Color(0xFFE3E9EF),
          ),
        ],
      ),
    );
  }
}

/// 状态日志区：展示全部后端消息。
class _StatusLogSection extends StatelessWidget {
  const _StatusLogSection({required this.log});

  final List<String> log;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '状态日志',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        ...log.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              line,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textHint,
                    height: 1.3,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
