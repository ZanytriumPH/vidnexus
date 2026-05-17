import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidnexus/app/theme/app_theme.dart';
import 'package:vidnexus/features/knowledge_base/application/knowledge_base_controller.dart';
import 'package:vidnexus/features/knowledge_base/knowledge_base_chat_screen.dart';
import 'package:vidnexus/features/knowledge_base/knowledge_base_models.dart';

void main() {
  testWidgets('knowledge base system message renders markdown', (
    WidgetTester tester,
  ) async {
    const testLibrary = KnowledgeBaseLibrary(
      id: 'kb-test',
      title: '测试知识库',
      meta: '测试元信息',
      description: '测试描述',
      sourceCount: 0,
      sources: [],
      conversations: [],
    );

    const conversation = KnowledgeConversationPreview(
      id: 'conv-test',
      title: '测试会话',
      preview: '测试预览',
      dateLabel: '今天',
      messages: [
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '### 系统结论\n\n- 第一条\n- 第二条\n\n**重点说明**',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedLibraryControllerProvider.overrideWith(
            () => _TestSelectedLibraryController(testLibrary),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const KnowledgeBaseChatScreen(
            kbid: 'kb-test',
            initialConversation: conversation,
          ),
        ),
      ),
    );

    expect(find.text('系统结论'), findsOneWidget);
    expect(find.text('第一条'), findsOneWidget);
    expect(find.text('第二条'), findsOneWidget);
    expect(find.text('重点说明'), findsOneWidget);
    expect(find.text('### 系统结论'), findsNothing);
  });
}

class _TestSelectedLibraryController extends SelectedLibraryController {
  _TestSelectedLibraryController(this.library);
  final KnowledgeBaseLibrary library;

  @override
  SelectedLibraryState build() {
    return SelectedLibraryState(selectedLibrary: library);
  }
}