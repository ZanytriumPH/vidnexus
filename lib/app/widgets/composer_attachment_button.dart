import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'app_header_add_button.dart';

/// 输入框附件按钮，点击后弹出拍照/相册选项。
/// 在视频总结最终稿与知识库问答中共用。
class ComposerAttachmentButton extends StatefulWidget {
  const ComposerAttachmentButton({
    super.key,
    required this.onImagePicked,
    this.enabled = true,
  });

  /// 选取图片成功后的回调，返回本地文件。
  final void Function(File imageFile) onImagePicked;

  /// 是否可用（上传中时禁用）。
  final bool enabled;

  @override
  State<ComposerAttachmentButton> createState() => _ComposerAttachmentButtonState();
}

class _ComposerAttachmentButtonState extends State<ComposerAttachmentButton> {
  final _picker = ImagePicker();
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    return AppHeaderAddButton(
      onPressed: (!widget.enabled || _picking) ? () {} : () => _showAttachmentSheet(context),
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
                  '添加图片',
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
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _AttachmentAction.camera:
        await _pickImage(ImageSource.camera);
      case _AttachmentAction.gallery:
        await _pickImage(ImageSource.gallery);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (xFile == null) return;

      final file = File(xFile.path);
      final sizeBytes = await file.length();
      const maxSize = 10 * 1024 * 1024; // 10 MB
      if (sizeBytes > maxSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片大小不能超过 10MB')),
          );
        }
        return;
      }

      widget.onImagePicked(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选取图片失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}

enum _AttachmentAction { camera, gallery }

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
