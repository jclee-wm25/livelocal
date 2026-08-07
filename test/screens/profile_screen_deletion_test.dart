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
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAuthController fakeAuth;
  late FakeAccountController fakeAccount;
  late FakeModerationController fakeModeration;

  setUp(() {
    fakeAuth = FakeAuthController();
    fakeAuth.setAuthenticated();
    fakeAccount = FakeAccountController();
    fakeModeration = FakeModerationController();
  });

  Widget createSubject() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: fakeAuth),
        ChangeNotifierProvider<AccountController>.value(value: fakeAccount),
        ChangeNotifierProvider<ModerationController>.value(
          value: fakeModeration,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ProfileScreen(),
        ),
      ),
    );
  }

  testWidgets(
      'Account deletion dialog shows privacy disclosures and handles cancel/confirm',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Scroll and tap 'Delete account'
    final deleteAccountFinder = find.text('Delete account');
    await tester.scrollUntilVisible(
      deleteAccountFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(deleteAccountFinder, findsOneWidget);
    await tester.tap(deleteAccountFinder);
    await tester.pumpAndSettle();

    // Verify dialog title
    expect(find.text('Schedule account deletion?'), findsOneWidget);

    // Verify disclosures
    expect(
        find.textContaining('scheduled for permanent deletion after 14 days'),
        findsOneWidget);
    expect(find.textContaining('recover your account during this grace period'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Your profile information, saved places, itineraries, and unapproved submissions will be permanently removed.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'To preserve community history, your published reviews and approved submissions may remain visible but will be anonymized and unlinked from you.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Moderation cases, safety reports, and audit logs related to your account may be retained for trust and safety purposes.'),
        findsOneWidget);

    // Verify cancel action
    final keepAccountFinder = find.text('Keep account');
    expect(keepAccountFinder, findsOneWidget);
    await tester.tap(keepAccountFinder);
    await tester.pumpAndSettle();

    // Dialog should be closed, backend not called
    expect(find.text('Schedule account deletion?'), findsNothing);
    expect(fakeAccount.requestDeletionCalled, isFalse);

    // Reopen dialog to test confirm
    await tester.tap(deleteAccountFinder);
    await tester.pumpAndSettle();

    // Fill password and confirmation
    await tester.enterText(
        find.widgetWithText(TextField, 'Current password'), 'mypassword');
    await tester.enterText(
        find.widgetWithText(TextField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pumpAndSettle();

    // Confirm deletion
    final confirmFinder = find.text('Schedule deletion');
    expect(confirmFinder, findsOneWidget);
    await tester.tap(confirmFinder);

    // Verify backend invocation synchronously (it was called via Future, but might have completed immediately)
    // Wait for the microtask queue to process the tap callback
    await Future.microtask(() {});

    expect(fakeAccount.requestDeletionCalled, isTrue);
    expect(fakeAccount.lastPasswordProvided, 'mypassword');
  });
}
