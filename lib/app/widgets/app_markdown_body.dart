import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppMarkdownBody extends StatelessWidget {
  const AppMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = context.appTextStyles.summaryContentBody;
    final theme = Theme.of(context);

    if (data.trim().isEmpty) {
      return Text('', style: bodyStyle);
    }

    return MarkdownBody(
      data: data,
      shrinkWrap: true,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: bodyStyle,
        h1: bodyStyle.copyWith(
          fontSize: 22,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        h2: bodyStyle.copyWith(
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        h3: bodyStyle.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        strong: bodyStyle.copyWith(fontWeight: FontWeight.w800),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        blockquote: bodyStyle.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7DFE7)),
        ),
        code: bodyStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.45,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        listBullet: bodyStyle,
        listIndent: 20,
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFD7DFE7)),
          ),
        ),
        a: bodyStyle.copyWith(
          color: const Color(0xFF275FD8),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF275FD8),
        ),
      ),
      onTapLink: (text, href, title) {},
    );
  }
}