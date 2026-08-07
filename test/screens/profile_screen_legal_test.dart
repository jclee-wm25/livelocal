import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:live_local/core/config/legal_urls.dart';
import 'package:live_local/features/auth/presentation/auth_controller.dart';
import 'package:live_local/features/profile/presentation/account_controller.dart';
import 'package:live_local/features/moderation/presentation/moderation_controller.dart';
import 'package:live_local/features/auth/domain/account_identity.dart';
import 'package:live_local/screens/profile_screen.dart';

class FakeAppLauncher implements AppLauncher {
  Uri? lastLaunched;
  bool shouldSucceed = true;
  bool shouldThrow = false;

  @override
  Future<bool> launch(Uri url) async {
    lastLaunched = url;
    if (shouldThrow) throw Exception('Launch failed');
    return shouldSucceed;
  }
}

class FakeAuthController extends ChangeNotifier implements AuthController {
  AccountIdentity? _currentUser;

  @override
  AccountIdentity? get currentUser => _currentUser;

  void setGuest() {
    _currentUser = null;
    notifyListeners();
  }

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

  bool logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAccountController extends ChangeNotifier
    implements AccountController {
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
  late FakeAppLauncher fakeLauncher;
  late FakeAuthController fakeAuth;
  late FakeAccountController fakeAccount;
  late FakeModerationController fakeModeration;

  setUp(() {
    fakeLauncher = FakeAppLauncher();
    fakeAuth = FakeAuthController();
    fakeAccount = FakeAccountController();
    fakeModeration = FakeModerationController();
  });

  Widget buildScreen(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: fakeAuth),
        ChangeNotifierProvider<AccountController>.value(value: fakeAccount),
        ChangeNotifierProvider<ModerationController>.value(
            value: fakeModeration),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ProfileScreen Legal Footer (Guest User)', () {
    setUp(() {
      fakeAuth.setGuest();
    });

    testWidgets('all four links are visible for guests', (tester) async {
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));
      expect(find.byKey(const Key('legal_terms')), findsOneWidget);
      expect(find.byKey(const Key('legal_privacy')), findsOneWidget);
      expect(find.byKey(const Key('legal_rules')), findsOneWidget);
      expect(find.byKey(const Key('legal_support')), findsOneWidget);
    });

    testWidgets('guest user can access the links and sends exact URI',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));
      await tester.tap(find.byKey(const Key('legal_terms')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastLaunched,
          Uri.parse('https://livelocal.app/placeholder-terms'));
    });
  });

  group('ProfileScreen Legal Footer (Authenticated User)', () {
    setUp(() {
      fakeAuth.setAuthenticated();
    });

    testWidgets('all four links are visible for authenticated users',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));

      // Scroll to bottom to ensure they are visible in ListView
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('legal_terms')), findsOneWidget);
      expect(find.byKey(const Key('legal_privacy')), findsOneWidget);
      expect(find.byKey(const Key('legal_rules')), findsOneWidget);
      expect(find.byKey(const Key('legal_support')), findsOneWidget);
    });

    testWidgets('authenticated user can access the links and sends exact URI',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('legal_support')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastLaunched,
          Uri.parse('https://livelocal.app/placeholder-support'));
    });
  });

  group('LegalUrls Configuration', () {
    test('non-HTTPS links are rejected by LegalUrls', () {
      expect(
        () => LegalUrls.fromValues(
          termsUrl: 'http://livelocal.app/terms',
          privacyUrl: 'https://livelocal.app/privacy',
          rulesUrl: 'https://livelocal.app/rules',
          supportUrl: 'https://livelocal.app/support',
          isRelease: false,
        ),
        throwsFormatException,
      );
    });

    test('DefaultAppLauncher rejects non-HTTPS links', () async {
      const launcher = DefaultAppLauncher();
      final result = await launcher.launch(Uri.parse('http://example.com'));
      expect(result, isFalse);
    });
  });

  group('Launcher Failure Scenarios', () {
    setUp(() {
      fakeAuth.setGuest();
    });

    testWidgets('false launcher results show an error', (tester) async {
      fakeLauncher.shouldSucceed = false;
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));

      await tester.tap(find.byKey(const Key('legal_privacy')));
      await tester.pump();
      await tester
          .pump(const Duration(milliseconds: 100)); // allow snackbar animation

      expect(find.textContaining('Could not open the link'), findsOneWidget);
    });

    testWidgets('launcher exceptions show an error', (tester) async {
      fakeLauncher.shouldThrow = true;
      await tester
          .pumpWidget(buildScreen(ProfileScreen(launcher: fakeLauncher)));

      await tester.tap(find.byKey(const Key('legal_rules')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('An error occurred'), findsOneWidget);
    });
  });

  group('Existing Profile Behavior', () {
    setUp(() {
      fakeAuth.setAuthenticated();
    });

    testWidgets('existing profile behavior remains intact (sign out)',
        (tester) async {
      await tester.pumpWidget(buildScreen(const ProfileScreen()));

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      final signOutFinder = find.text('Sign out');
      expect(signOutFinder, findsOneWidget);

      await tester.tap(signOutFinder);
      await tester.pumpAndSettle();

      expect(fakeAuth.logoutCalled, isTrue);
    });
  });
}
