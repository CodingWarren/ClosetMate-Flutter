import 'package:closetmate/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ClosetMate app boots and shows closet tab', (WidgetTester tester) async {
    await tester.pumpWidget(const ClosetMateApp());
    await tester.pumpAndSettle();

    expect(find.text('我的衣橱'), findsWidgets);
    expect(find.text('衣橱'), findsOneWidget);
    expect(find.text('搭配'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
