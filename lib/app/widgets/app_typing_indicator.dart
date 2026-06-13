import 'package:flutter/material.dart';

/// 全局统一的 "AI 正在思考" 呼吸动画指示器。
///
/// 用于视频总结 QA、知识库 QA、最终稿生成等待态等所有 AI 处理中的等待场景。
/// 文字在前，三点动画在后，无末尾省略号。
class AppTypingIndicator extends StatefulWidget {
  const AppTypingIndicator({this.message, super.key});

  /// 动态状态文案。null 时回退默认"AI 正在思考"。
  final String? message;

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            widget.message ?? 'AI 正在思考...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
