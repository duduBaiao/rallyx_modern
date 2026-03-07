import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/main.dart';

void main() {
  testWidgets('App boots with game root widget', (WidgetTester tester) async {
    await tester.pumpWidget(const RallyXApp());
    expect(find.byType(RallyXApp), findsOneWidget);
  });
}
