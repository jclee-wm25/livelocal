import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/main.dart';

void main() {
  testWidgets('LiveLocal App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveLocalApp());
    expect(find.byType(LiveLocalApp), findsOneWidget);
  });
}
