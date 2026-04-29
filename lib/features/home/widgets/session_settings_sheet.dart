import 'package:flutter/material.dart';

Future<void> showSessionSettingsSheet({
  required BuildContext context,
  required bool defaultTimestampScoped,
  required bool defaultProcessingExpanded,
  required ValueChanged<bool> onDefaultTimestampScopedChanged,
  required ValueChanged<bool> onDefaultProcessingExpandedChanged,
}) async {
  var timestampScopedValue = defaultTimestampScoped;
  var processingExpandedValue = defaultProcessingExpanded;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '会话设置',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '这里控制新会话打开时的默认行为。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsTile(
                  title: '新会话默认开启时间区间追问',
                  subtitle: '进入最终稿后默认显示时间区间选择条。',
                  value: timestampScopedValue,
                  onChanged: (value) {
                    timestampScopedValue = value;
                    onDefaultTimestampScopedChanged(value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _SettingsTile(
                  title: '处理中默认展开详细信息',
                  subtitle: '新会话进入处理中时自动展开步骤进度。',
                  value: processingExpandedValue,
                  onChanged: (value) {
                    processingExpandedValue = value;
                    onDefaultProcessingExpandedChanged(value);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFD8DEE7),
            ),
          ),
        ],
      ),
    );
  }
}