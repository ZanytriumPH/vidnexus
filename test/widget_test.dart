// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:vidnexus/main.dart';

void main() {
  testWidgets('stage one video summary entry renders and opens processing placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('本地上传'), findsOneWidget);
    expect(find.text('总结偏好（可选）'), findsOneWidget);
    expect(find.text('开始生成初稿'), findsOneWidget);

    await tester.tap(find.text('开始生成初稿'));
    await tester.pumpAndSettle();

    expect(find.text('处理中占位'), findsOneWidget);
    expect(find.text('渐变高亮区'), findsOneWidget);
  });
}
