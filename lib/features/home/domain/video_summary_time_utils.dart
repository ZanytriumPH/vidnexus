import '../video_summary_models.dart';

String formatVideoSummaryTimestampRange(int startSeconds, int endSeconds) {
  return '${formatVideoSummaryClockLabel(startSeconds)} - ${formatVideoSummaryClockLabel(endSeconds)}';
}

String formatVideoSummaryClockLabel(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatVideoSummaryRangeLength(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes == 0) {
    return '$seconds秒';
  }
  if (seconds == 0) {
    return '$minutes分';
  }
  return '$minutes分$seconds秒';
}

int parseVideoSummaryClockLabel(String value) {
  final parts = value.split(':').map(int.parse).toList();
  if (parts.length == 2) {
    return parts[0] * 60 + parts[1];
  }
  return parts[0] * 3600 + parts[1] * 60 + parts[2];
}

int parseVideoSummaryDurationLabel({
  required String label,
  required int minimumSeconds,
}) {
  final compact = label.trim();
  if (compact.contains(':')) {
    return parseVideoSummaryClockLabel(compact);
  }

  final minuteMatch = RegExp(r'(\d+)\s*m').firstMatch(compact);
  final secondMatch = RegExp(r'(\d+)\s*s').firstMatch(compact);
  final minutes = int.tryParse(minuteMatch?.group(1) ?? '0') ?? 0;
  final seconds = int.tryParse(secondMatch?.group(1) ?? '0') ?? 0;
  final total = minutes * 60 + seconds;
  return total >= minimumSeconds ? total : minimumSeconds;
}

TimestampRangeSelection? tryParseVideoSummaryTimestampRange({
  required String raw,
  required int minimumSeconds,
}) {
  final matches = RegExp(r'(\d{2}:\d{2}(?::\d{2})?)').allMatches(raw).toList();
  if (matches.length < 2) {
    return null;
  }

  final start = parseVideoSummaryClockLabel(matches.first.group(0)!);
  final end = parseVideoSummaryClockLabel(matches[1].group(0)!);
  if (end - start < minimumSeconds) {
    return null;
  }

  return TimestampRangeSelection(startSeconds: start, endSeconds: end);
}