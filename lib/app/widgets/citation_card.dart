import 'package:flutter/material.dart';

import '../../../services/models/global_chat_dto.dart';
import '../theme/app_colors.dart';

/// 单条引用来源卡片，展示检索到的文本片段、时间范围和来源信息。
class CitationCard extends StatelessWidget {
  const CitationCard({
    required this.source,
    this.onTap,
    super.key,
  });

  final CitedSource source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasQuote = source.quote != null && source.quote!.isNotEmpty;
    final hasTimeRange = source.timeRange != null && source.timeRange!.isNotEmpty;
    final videoLabel = source.videoName != null && source.videoName!.isNotEmpty
        ? source.videoName!
        : source.videoId;
    final hasVideoLabel = videoLabel != null && videoLabel.isNotEmpty;

    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 引用文本行
          if (hasQuote)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    source.quote!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          // 标签行：时间范围 + 来源
          if (hasTimeRange || hasVideoLabel) ...[
            if (hasQuote) const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (hasTimeRange)
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    label: source.timeRange!,
                  ),
                if (hasVideoLabel)
                  _InfoChip(
                    icon: Icons.videocam_outlined,
                    label: videoLabel,
                  ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

/// 引用来源列表容器，纵向排列多条 [CitationCard]。
///
/// 默认收起，点击标题栏可展开/收起，提升浏览体验。
class CitationCards extends StatefulWidget {
  const CitationCards({
    required this.citedSources,
    this.onCitationTap,
    super.key,
  });

  final List<CitedSource> citedSources;
  final void Function(CitedSource)? onCitationTap;

  @override
  State<CitationCards> createState() => _CitationCardsState();
}

class _CitationCardsState extends State<CitationCards> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.citedSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行：可点击切换展开/收起
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '参考来源 (${widget.citedSources.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开后的卡片列表
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: List.generate(widget.citedSources.length, (index) {
                final source = widget.citedSources[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < widget.citedSources.length - 1 ? 6 : 0,
                  ),
                  child: CitationCard(
                    source: source,
                    onTap: widget.onCitationTap != null
                        ? () => widget.onCitationTap!(source)
                        : null,
                  ),
                );
              }),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// 小型标签，用于展示时间范围或来源视频名称。
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
