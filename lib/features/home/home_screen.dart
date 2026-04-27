import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_buttons.dart';
import '../../app/widgets/app_card.dart';
import '../module_placeholder/module_placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _preferenceController = TextEditingController();
  bool _uploadHighlighted = false;

  @override
  void dispose() {
    _preferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderRow(
                      onMenuPressed: () {},
                      onNewSessionPressed: _resetPageState,
                    ),
                    const SizedBox(height: 18),
                    _UploadCard(
                      highlighted: _uploadHighlighted,
                      onTap: () {
                        setState(() {
                          _uploadHighlighted = !_uploadHighlighted;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '总结偏好（可选）',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PreferenceCard(controller: _preferenceController),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AppPrimaryButton(
                label: '开始生成初稿',
                onPressed: () => Navigator.pushNamed(
                  context,
                  ModulePlaceholderScreen.processingRouteName,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _StageOneBottomNav(
                onKnowledgeBasePressed: () => _handleSectionSelection(
                  context,
                  _StageOneNavSection.knowledgeBase,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSectionSelection(
    BuildContext context,
    _StageOneNavSection section,
  ) {
    switch (section) {
      case _StageOneNavSection.videoSummary:
        return;
      case _StageOneNavSection.knowledgeBase:
        Navigator.pushNamed(
          context,
          ModulePlaceholderScreen.knowledgeRouteName,
        );
    }
  }

  void _resetPageState() {
    _preferenceController.clear();
    setState(() {
      _uploadHighlighted = false;
    });
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.onMenuPressed,
    required this.onNewSessionPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onNewSessionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundGhostButton(
          size: 44,
          onPressed: onMenuPressed,
          child: const Icon(Icons.menu_rounded, size: 22),
        ),
        Expanded(
          child: Text(
            '视频总结',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 24,
            ),
          ),
        ),
        _RoundGhostButton(
          outlined: true,
          size: 35,
          onPressed: onNewSessionPressed,
          child: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.highlighted, required this.onTap});

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: highlighted
            ? const [Color(0xFFD6EEFF), Color(0xFFF6FCFF)]
            : const [Color(0xFFF6FCFF), Color(0xFFB0E1FF)],
      ),
      borderColor: highlighted ? AppColors.primary : AppColors.borderStrong,
      child: SizedBox(
        height: 220,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '本地上传',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '从设备选择文件',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.borderStrong,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    highlighted ? '+ 已选中视频模拟项' : '+ 点击或拖拽视频到这里',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 85,
        child: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 4,
          decoration: const InputDecoration(
            hintText: '例如：关注产品定位、架构设计与关键结论',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
            fillColor: Colors.transparent,
            filled: false,
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _RoundGhostButton extends StatelessWidget {
  const _RoundGhostButton({
    required this.child,
    required this.onPressed,
    this.outlined = false,
    this.size = 44,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool outlined;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: outlined
            ? const BorderSide(color: AppColors.borderStrong)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

enum _StageOneNavSection { videoSummary, knowledgeBase }

class _StageOneBottomNav extends StatelessWidget {
  const _StageOneBottomNav({required this.onKnowledgeBasePressed});

  final VoidCallback onKnowledgeBasePressed;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('视频总结', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onKnowledgeBasePressed,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14),
                    const SizedBox(width: 6),
                    Text('知识库', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
