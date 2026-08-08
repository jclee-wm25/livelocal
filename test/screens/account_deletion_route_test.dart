import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:live_local/features/auth/presentation/auth_controller.dart';
import 'package:live_local/features/profile/presentation/account_controller.dart';
import 'package:live_local/features/moderation/presentation/moderation_controller.dart';
import 'package:live_local/features/auth/domain/account_identity.dart';
import 'package:live_local/screens/profile_screen.dart';

class FakeAuthController extends ChangeNotifier implements AuthController {
  AccountIdentity? _currentUser;

  @override
  AccountIdentity? get currentUser => _currentUser;

  void setAuthenticated() {
    _currentUser = const AccountIdentity(
      id: '123',
      email: 'test@example.com',
      fullName: 'Test User',
      role: AppRole.tourist,
      accessStatus: AccountAccessStatus.active,
      emailVerified: true,
    );
    notifyListeners();
  }

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAccountController extends ChangeNotifier
    implements AccountController {
  bool requestDeletionCalled = false;
  String? lastPasswordProvided;

  @override
  Future<bool> requestDeletion(String password) async {
    requestDeletionCalled = true;
    lastPasswordProvided = password;
    return true;
  }

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeModerationController extends ChangeNotifier
    implements ModerationController {
  @override
  bool get supportsUserBlocking => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAuthController fakeAuth;
  late FakeAccountController fakeAccount;
  late FakeModerationController fakeMod;

  setUp(() {
    fakeAuth = FakeAuthController();
    fakeAccount = FakeAccountController();
    fakeMod = FakeModerationController();
  });

  Widget createSubject({required bool loggedIn}) {
    if (loggedIn) fakeAuth.setAuthenticated();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: fakeAuth),
        ChangeNotifierProvider<AccountController>.value(value: fakeAccount),
        ChangeNotifierProvider<ModerationController>.value(value: fakeMod),
      ],
      child: MaterialApp(
        initialRoute: '/account-deletion',
        routes: {
          '/account-deletion': (context) => const ProfileScreen(),
        },
      ),
    );
  }

  testWidgets('/account-deletion route resolves to ProfileScreen (Guest)',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject(loggedIn: false));
    await tester.pumpAndSettle();

    // Verify it resolves to ProfileScreen
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Verify guest state: Sign in prompt is visible, no Delete account
    expect(find.text('Sign in for personal features'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets(
      '/account-deletion route resolves to ProfileScreen (Authenticated)',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject(loggedIn: true));
    await tester.pumpAndSettle();

    // Verify it resolves to ProfileScreen
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Verify authenticated state: Delete account is available
    expect(find.text('Sign in for personal features'), findsNothing);

    // Scroll to the bottom to find Delete account
    final deleteAccountFinder = find.text('Delete account');
    await tester.scrollUntilVisible(
      deleteAccountFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(deleteAccountFinder, findsOneWidget);
  });
}
