import 'dart:async';

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidnexus/features/auth/auth_controller.dart';
import 'package:vidnexus/features/auth/auth_state.dart';
import 'package:vidnexus/features/home/domain/video_summary_domain_models.dart';
import 'package:vidnexus/features/home/video_summary_models.dart';
import 'package:vidnexus/features/home/video_summary_repository.dart';
import 'package:vidnexus/main.dart';

void main() {
  testWidgets('stage one video summary entry renders and opens processing view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoSummaryRepositoryProvider.overrideWithValue(
            _WidgetTestVideoSummaryRepository(),
          ),
          authControllerProvider.overrideWith(
            () => _TestAuthController.loggedIn(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('本地上传'), findsOneWidget);
    expect(find.text('总结偏好（可选）'), findsOneWidget);
    expect(find.text('开始生成初稿'), findsOneWidget);

    await tester.tap(find.text('开始生成初稿'));
    await tester.pump();

    expect(find.text('正在生成结构化初稿'), findsOneWidget);
    expect(find.text('正在获取并保存视频文件，准备进入本地预处理。'), findsWidgets);
    
    // ProcessingDetailCard is visible by default (defaultProcessingExpanded = true)
    expect(find.text('详细处理信息'), findsOneWidget);
    
    // Tap to collapse
    await tester.tap(find.text('详细处理信息'));
    await tester.pumpAndSettle();
    
    // ProcessingCollapsedHintCard is visible after clicking
    expect(find.text('详细处理信息已收起'), findsOneWidget);
  });

  testWidgets('drawer search button opens the search page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoSummaryRepositoryProvider.overrideWithValue(
            _WidgetTestVideoSummaryRepository(),
          ),
          authControllerProvider.overrideWith(
            () => _TestAuthController.loggedIn(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('会话中心'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('搜索历史会话...'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}

class _WidgetTestVideoSummaryRepository extends VideoSummaryRepository {
  _WidgetTestVideoSummaryRepository();

  static const VideoSummaryProcessingData _processingData =
      VideoSummaryProcessingData(
        progress: 0.18,
        currentStage: VideoSummaryProcessingStage.acquiringVideo,
        currentMessage: '正在获取并保存视频文件，准备进入本地预处理。',
        steps: [
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.preprocessing,
            progress: 18,
            completedUnits: 0,
            totalUnits: 4,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.analysis,
            progress: 0,
            completedUnits: 0,
            totalUnits: 16,
          ),
          VideoSummaryProcessingStepData(
            phase: VideoSummaryProcessingPhase.synthesis,
            progress: 0,
            completedUnits: 0,
            totalUnits: 10,
          ),
        ],
      );

  @override
  VideoAssetInfo getVideoAsset() {
    return const VideoAssetInfo(
      title: 'widget-test.mp4',
      durationLabel: '18m 24s',
      sourceLabel: '测试视频',
      fileName: 'widget-test.mp4',
    );
  }

  @override
  Stream<VideoSummaryProcessingData> startDraftGeneration() {
    final controller = StreamController<VideoSummaryProcessingData>();
    controller.onListen = () {
      controller.add(_processingData);
    };
    return controller.stream;
  }

  @override
  Future<VideoSummaryDraftData> fetchDraftResult() async {
    return const VideoSummaryDraftData(paragraphs: ['draft']);
  }

  @override
  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  }) async {
    return const VideoSummaryFinalResultData(body: 'final', references: []);
  }

  @override
  Future<List<VideoSummaryTaskInfo>> listTaskHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    return const [];
  }

  @override
  Future<VideoSummaryChatReplyData> sendSummaryChatMessage(String message) async {
    return const VideoSummaryChatReplyData(text: 'reply');
  }
}

/// 测试用 AuthController：直接返回已登录状态，跳过启动时的 _restoreSession() 流程。
class _TestAuthController extends AuthController {
  _TestAuthController.loggedIn();

  @override
  AuthState build() {
    // 初始化 _authService 避免 LateInitializationError
    ref.read(authServiceProvider);
    return const AuthState(isLoggedIn: true);
  }
}
