import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/app/theme/app_theme.dart';
import 'package:vidnexus/features/home/video_summary_presentation_models.dart';
import 'package:vidnexus/features/home/widgets/video_summary_draft_stage_workspace.dart';
import 'package:vidnexus/features/home/widgets/video_summary_final_chat_widgets.dart';

void main() {
  group('video summary markdown rendering', () {
    testWidgets('draft body renders markdown preview when not editing', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController(
        text: '# 标题\n\n- 第一项\n- 第二项\n\n**重点**',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: DraftBodyCard(
            draftBodyController: controller,
            isEditMode: false,
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('标题'), findsOneWidget);
      expect(find.text('第一项'), findsOneWidget);
      expect(find.text('第二项'), findsOneWidget);
      expect(find.text('重点'), findsOneWidget);
      expect(find.text('# 标题'), findsNothing);
    });

    testWidgets('draft body keeps raw markdown in edit mode', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController(text: '# 标题\n\n**重点**');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: DraftBodyCard(
            draftBodyController: controller,
            isEditMode: true,
            onModeChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('# 标题\n\n**重点**'), findsOneWidget);
    });

    testWidgets('final summary bubble renders markdown content', (
      WidgetTester tester,
    ) async {
      const summary = FinalSummaryData(
        summaryTitle: '最终稿',
        summaryBody: '## 小结\n\n1. 结论一\n2. 结论二\n\n> 引用内容',
        timestampChips: [],
        messages: [],
      );

      await tester.pumpWidget(
        const _TestApp(
          child: ChatThread(summary: summary, messages: []),
        ),
      );

      expect(find.text('小结'), findsOneWidget);
      expect(find.text('结论一'), findsOneWidget);
      expect(find.text('结论二'), findsOneWidget);
      expect(find.text('引用内容'), findsOneWidget);
      expect(find.text('## 小结'), findsNothing);
    });

    testWidgets('system chat message renders markdown content', (
      WidgetTester tester,
    ) async {
      const summary = FinalSummaryData(
        summaryTitle: '最终稿',
        summaryBody: '正文',
        timestampChips: [],
        messages: [],
      );

      const messages = [
        ChatMessage(
          sender: SummaryChatSender.system,
          text: '### 补充说明\n\n- 第一条\n- 第二条\n\n**重点提醒**',
          timestampLabel: '12:30 - 14:00',
        ),
      ];

      await tester.pumpWidget(
        const _TestApp(
          child: ChatThread(summary: summary, messages: messages),
        ),
      );

      expect(find.text('补充说明'), findsOneWidget);
      expect(find.text('第一条'), findsOneWidget);
      expect(find.text('第二条'), findsOneWidget);
      expect(find.text('重点提醒'), findsOneWidget);
      expect(find.text('### 补充说明'), findsNothing);
      expect(find.text('12:30 - 14:00'), findsOneWidget);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }
}