import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_header_add_button.dart';

/// 输入框附件按钮，点击后弹出拍照/相册/文件选项。
/// 在视频总结最终稿与知识库问答中共用。
class ComposerAttachmentButton extends StatelessWidget {
  const ComposerAttachmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppHeaderAddButton(
      onPressed: () => _showAttachmentSheet(context),
    );
  }

  Future<void> _showAttachmentSheet(BuildContext context) async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加内容',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _AttachmentActionTile(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentAction.camera),
                ),
                const SizedBox(height: 8),
                _AttachmentActionTile(
                  icon: Icons.photo_library_outlined,
                  label: '相册',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentAction.gallery),
                ),
                const SizedBox(height: 8),
                _AttachmentActionTile(
                  icon: Icons.insert_drive_file_outlined,
                  label: '文件',
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentAction.file),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) {
      return;
    }

    final message = switch (action) {
      _AttachmentAction.camera => '拍照功能将在下一阶段接入。',
      _AttachmentAction.gallery => '相册功能将在下一阶段接入。',
      _AttachmentAction.file => '文件功能将在下一阶段接入。',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AttachmentAction { camera, gallery, file }

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7DFE7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
