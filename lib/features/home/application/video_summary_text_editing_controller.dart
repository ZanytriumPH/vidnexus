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

/// 统一管理首页内多个 TextEditingController，并负责把文本状态同步进 session snapshot。
class VideoSummaryTextEditingController {
  VideoSummaryTextEditingController(this._ref) {
    readyPreferenceController.addListener(_syncEditableSnapshot);
    draftGuidanceController.addListener(_syncEditableSnapshot);
    draftBodyController.addListener(_syncEditableSnapshot);
  }

  final Ref _ref;

  final TextEditingController readyPreferenceController = TextEditingController();
  final TextEditingController draftGuidanceController = TextEditingController();
  final TextEditingController chatController = TextEditingController();
  final TextEditingController draftBodyController = TextEditingController();

  bool _syncPaused = false;

  String get readyPreferenceText => readyPreferenceController.text;
  String get draftGuidanceText => draftGuidanceController.text;
  String get draftBodyText => draftBodyController.text;

  /// 发送后直接清空聊天输入框，页面层只拿消费后的消息结果。
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
      readyPreferenceController.clear();
      draftGuidanceController.clear();
      chatController.clear();
      draftBodyController.clear();
    });
  }

  void applySessionSnapshot(VideoSummarySessionSnapshot snapshot) {
    runWithoutSync(() {
      readyPreferenceController.text = snapshot.readyPreferenceText;
      draftGuidanceController.text = snapshot.draftGuidanceText;
      draftBodyController.text = snapshot.draftBodyText;
      chatController.clear();
    });
  }

  VideoSummarySessionSnapshot captureSnapshot() {
    return VideoSummarySessionSnapshot(
      flowSnapshot:
          _ref.read(videoSummaryFlowControllerProvider.notifier).captureSnapshot(),
      readyPreferenceText: readyPreferenceController.text,
      draftGuidanceText: draftGuidanceController.text,
      draftBodyText: draftBodyController.text,
    );
  }

  /// 批量写入文本时暂时关闭同步，避免“恢复会话”又被误判为用户手动编辑。
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
    // 草稿第一次生成出来时，把结果注入可编辑文本框，后续用户就编辑这份文本。
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
    readyPreferenceController.dispose();
    draftGuidanceController.dispose();
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