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

  int _syncPauseCount = 0;

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
  /// 使用计数器支持嵌套调用。
  T runWithoutSync<T>(T Function() action) {
    _syncPauseCount++;
    try {
      return action();
    } finally {
      _syncPauseCount--;
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

    // 仅在关键字段变化时打印日志（避免每帧/每次按键刷屏）
    if (previous?.isUploading != next.isUploading ||
        previous?.taskId != next.taskId ||
        previous?.stage != next.stage) {
      debugPrint(
        '[TextEditCtrl] handleFlowStateChanged —'
        ' isUploading ${previous?.isUploading}→${next.isUploading}'
        ' taskId ${previous?.taskId}→${next.taskId}'
        ' stage ${previous?.stage}→${next.stage}'
        ' syncPauseCount=$_syncPauseCount'
        ' videoTitle=${next.videoAsset.title}',
      );
    }

    if (_syncPauseCount > 0) {
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
    if (_syncPauseCount > 0) {
      return;
    }

    _ref
        .read(videoSummarySessionHistoryProvider.notifier)
        .syncActiveSession(captureSnapshot());
  }
}