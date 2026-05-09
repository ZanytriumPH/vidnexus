import 'package:flutter/material.dart';
import '../../../app/widgets/app_markdown_body.dart';

class VideoSummaryMarkdownBody extends StatelessWidget {
  const VideoSummaryMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return AppMarkdownBody(data: data);
  }
}