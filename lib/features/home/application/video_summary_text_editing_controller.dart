import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_summary_flow_controller.dart';
import 'video_summary_session_history_controller.dart';

final videoSummaryTextEditingControllerProvider =
    Provider<VideoSummaryTextEditingController>((ref) {
      final controller = VideoSummaryTextEditingController(ref);
      ref.onDispose(controller.dispose);
      ref.listen<VideoSummaryFlowState>(videoSummaryFlowControllerProvider, (
        previous,
        next,
      ) {
        controller.handleFlowStateChanged(previous, next);
      });
      return controller;
    });

class VideoSummaryTextEditingController {
  VideoSummaryTextEditingController(this._ref) {
    preferenceController.addListener(_syncEditableSnapshot);
    draftBodyController.addListener(_syncEditableSnapshot);
  }

  final Ref _ref;

  final TextEditingController preferenceController = TextEditingController();
  final TextEditingController chatController = TextEditingController();
  final TextEditingController draftBodyController = TextEditingController();

  bool _syncPaused = false;

  String get preferenceText => preferenceController.text;
  String get draftBodyText => draftBodyController.text;

  String? consumeChatMessage() {
    final message = chatController.text.trim();
    if (message.isEmpty) {
      return null;
    }
    chatController.clear();
    return message;
  }

  void clearForNewSession() {
    runWithoutSync(() {
      preferenceController.clear();
      chatController.clear();
      draftBodyController.clear();
    });
  }

  void applySessionSnapshot(VideoSummarySessionSnapshot snapshot) {
    runWithoutSync(() {
      preferenceController.text = snapshot.preferenceText;
      draftBodyController.text = snapshot.draftBodyText;
      chatController.clear();
    });
  }

  VideoSummarySessionSnapshot captureSnapshot() {
    return VideoSummarySessionSnapshot(
      flowSnapshot:
          _ref.read(videoSummaryFlowControllerProvider.notifier).captureSnapshot(),
      preferenceText: preferenceController.text,
      draftBodyText: draftBodyController.text,
    );
  }

  T runWithoutSync<T>(T Function() action) {
    _syncPaused = true;
    try {
      return action();
    } finally {
      _syncPaused = false;
    }
  }

  void handleFlowStateChanged(
    VideoSummaryFlowState? previous,
    VideoSummaryFlowState next,
  ) {
    if (previous?.draftResult == null && next.draftResult != null) {
      runWithoutSync(() {
        draftBodyController.text = next.draftResult!.paragraphs.join('\n\n');
      });
    }

    if (_syncPaused) {
      return;
    }

    _ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .syncActiveSession(captureSnapshot());
  }

  void dispose() {
    preferenceController.dispose();
    chatController.dispose();
    draftBodyController.dispose();
  }

  void _syncEditableSnapshot() {
    if (_syncPaused) {
      return;
    }

    _ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .syncActiveSession(captureSnapshot());
  }
}