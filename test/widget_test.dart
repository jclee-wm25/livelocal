import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/core/config/app_environment.dart';
import 'package:live_local/main.dart';
import 'package:live_local/repositories/supabase_repository.dart';

void main() {
  setUpAll(() {
    SupabaseRepository().configureForDemo();
  });

  testWidgets('LiveLocal App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      LiveLocalApp(configuration: AppConfiguration.demoForTesting()),
    );
    expect(find.byType(LiveLocalApp), findsOneWidget);
    expect(find.byType(Banner), findsOneWidget);
  });
}
