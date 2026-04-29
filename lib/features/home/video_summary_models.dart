enum VideoSummaryStage { ready, processing, draft, finalChat }

class VideoAssetInfo {
  const VideoAssetInfo({
    required this.title,
    required this.durationLabel,
    required this.sourceLabel,
    required this.fileName,
  });

  final String title;
  final String durationLabel;
  final String sourceLabel;
  final String fileName;
}

class TimestampRangeSelection {
  const TimestampRangeSelection({
    required this.startSeconds,
    required this.endSeconds,
  });

  final int startSeconds;
  final int endSeconds;
}
