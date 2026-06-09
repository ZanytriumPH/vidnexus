import 'package:flutter/material.dart';

import '../../features/knowledge_base/knowledge_base_models.dart';
import '../theme/app_colors.dart';

/// 可折叠的"思考过程"组件，展示 ReAct agent 的每一步进度。
///
/// 复用 [CitationCards] 的折叠交互模式：点击标题栏切换展开/收起，
/// 使用 [AnimatedCrossFade] 过渡。默认收起。
class ThinkingProcessSection extends StatefulWidget {
  const ThinkingProcessSection({
    required this.steps,
    this.totalDuration,
    super.key,
  });

  /// 进度步骤列表。
  final List<KnowledgeProgressStep> steps;

  /// 总耗时（从第一个 progress 到 done），用于在标题栏展示。
  final Duration? totalDuration;

  @override
  State<ThinkingProcessSection> createState() => _ThinkingProcessSectionState();
}

class _ThinkingProcessSectionState extends State<ThinkingProcessSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final durationText =
        widget.totalDuration != null ? _formatDuration(widget.totalDuration!) : '';

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
                  '思考过程 (${widget.steps.length} 步)'
                      '${durationText.isNotEmpty ? ' · $durationText' : ''}',
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
        // 展开后的步骤列表
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: List.generate(widget.steps.length, (index) {
                final step = widget.steps[index];
                final relativeTime = index == 0
                    ? ''
                    : _stepDelta(widget.steps[index], widget.steps[index - 1]);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < widget.steps.length - 1 ? 4 : 0,
                  ),
                  child: _ThinkingStepRow(
                    icon: _iconForPhase(step.phase),
                    message: step.message,
                    timeLabel: relativeTime,
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

  /// 计算步骤间相对耗时（如 "+1.2s"）。
  String _stepDelta(KnowledgeProgressStep current, KnowledgeProgressStep previous) {
    final delta = current.timestamp.difference(previous.timestamp);
    return _formatDelta(delta);
  }

  String _formatDelta(Duration d) {
    if (d.inSeconds < 1) return '';
    if (d.inSeconds < 60) return '+${d.inSeconds}s';
    return '+${d.inMinutes}m${d.inSeconds % 60}s';
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 1) return '';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m${d.inSeconds % 60}s';
  }

  /// phase → 图标映射。
  static IconData _iconForPhase(String phase) {
    switch (phase) {
      case 'thinking':
        return Icons.psychology;
      case 'searching':
        return Icons.search;
      case 'retrieved':
        return Icons.check_circle_outline;
      case 'loading':
        return Icons.hourglass_bottom;
      case 'generating':
        return Icons.auto_awesome;
      default:
        return Icons.info_outline;
    }
  }
}

/// 单条思考步骤行：图标 + 文案 + 耗时标签。
class _ThinkingStepRow extends StatelessWidget {
  const _ThinkingStepRow({
    required this.icon,
    required this.message,
    this.timeLabel,
  });

  final IconData icon;
  final String message;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ),
        if (timeLabel != null && timeLabel!.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            timeLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
          ),
        ],
      ],
    );
  }
}
