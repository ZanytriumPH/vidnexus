enum VideoSummaryStage { ready, processing, draft, finalChat }

class VideoAssetInfo {
  const VideoAssetInfo({
    required this.title,
    required this.durationLabel,
    required this.sourceLabel,
    required this.fileName,
    this.kbName,
  });

  final String title;
  final String durationLabel;
  final String sourceLabel;
  final String fileName;
  final String? kbName;
}

class TimestampRangeSelection {
  const TimestampRangeSelection({
    required this.startSeconds,
    required this.endSeconds,
  });

  final int startSeconds;
  final int endSeconds;
}
