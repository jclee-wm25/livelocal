import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/controllers/auth_controller.dart';
import 'package:live_local/core/config/app_environment.dart';
import 'package:live_local/core/routing/protected_navigation.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/screens/login_screen.dart';
import 'package:live_local/screens/register_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login validates email structure before repository access',
      (tester) async {
    final auth = await _pumpAuthScreen(tester, const LoginScreen());
    addTearDown(auth.dispose);

    await tester.enterText(find.byType(TextFormField).first, 'user@example.c');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(auth.errorMessage, isNull);
  });

  testWidgets('editing login fields clears a stale authentication error',
      (tester) async {
    final auth = await _pumpAuthScreen(tester, const LoginScreen());
    addTearDown(auth.dispose);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'tourist@livelocal.my');
    await tester.enterText(fields.last, 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password.'), findsOneWidget);

    await tester.enterText(fields.first, 'tourist2@livelocal.my');
    await tester.pump();
    expect(find.text('Invalid email or password.'), findsNothing);
  });

  testWidgets('registration uses the same strict email validation',
      (tester) async {
    final auth = await _pumpAuthScreen(tester, const RegisterScreen());
    addTearDown(auth.dispose);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Demo Tourist');
    await tester.enterText(fields.at(1), 'user@example.c');
    await tester.enterText(fields.at(2), 'DemoOnly123!');
    await tester.enterText(fields.at(3), 'DemoOnly123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(auth.errorMessage, isNull);
  });
}

Future<AuthController> _pumpAuthScreen(
  WidgetTester tester,
  Widget screen,
) async {
  final auth = AuthController(repository: DemoAuthRepository());
  await auth.initialize();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: AppConfiguration.demoForTesting()),
        Provider(create: (_) => ProtectedNavigation()),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}
