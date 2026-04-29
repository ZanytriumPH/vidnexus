import 'package:flutter_riverpod/flutter_riverpod.dart';

final videoSummarySettingsProvider =
    NotifierProvider<VideoSummarySettingsController, VideoSummarySettingsState>(
      VideoSummarySettingsController.new,
    );

class VideoSummarySettingsState {
  const VideoSummarySettingsState({
    required this.defaultTimestampScoped,
    required this.defaultProcessingExpanded,
  });

  final bool defaultTimestampScoped;
  final bool defaultProcessingExpanded;

  VideoSummarySettingsState copyWith({
    bool? defaultTimestampScoped,
    bool? defaultProcessingExpanded,
  }) {
    return VideoSummarySettingsState(
      defaultTimestampScoped:
          defaultTimestampScoped ?? this.defaultTimestampScoped,
      defaultProcessingExpanded:
          defaultProcessingExpanded ?? this.defaultProcessingExpanded,
    );
  }
}

class VideoSummarySettingsController
    extends Notifier<VideoSummarySettingsState> {
  @override
  VideoSummarySettingsState build() {
    return const VideoSummarySettingsState(
      defaultTimestampScoped: false,
      defaultProcessingExpanded: true,
    );
  }

  void setDefaultTimestampScoped(bool value) {
    state = state.copyWith(defaultTimestampScoped: value);
  }

  void setDefaultProcessingExpanded(bool value) {
    state = state.copyWith(defaultProcessingExpanded: value);
  }
}