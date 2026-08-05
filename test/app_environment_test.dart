import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/core/config/app_environment.dart';
import 'package:live_local/controllers/auth_controller.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/repositories/supabase_repository.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  group('AppConfiguration', () {
    test('unconfigured repository does not fall back to fixtures', () async {
      await expectLater(
        SupabaseRepository().fetchSpots(),
        throwsA(isA<StateError>()),
      );
    });

    test('requires an explicit environment', () {
      expect(
        () => AppConfiguration.fromValues(
          environment: '',
          isRelease: false,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('rejects demo mode in release builds', () {
      expect(
        () => AppConfiguration.fromValues(
          environment: 'demo',
          isRelease: true,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('requires Supabase values outside demo mode', () {
      expect(
        () => AppConfiguration.fromValues(
          environment: 'production',
          isRelease: true,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('accepts a fully specified production configuration', () {
      final configuration = AppConfiguration.fromValues(
        environment: 'production',
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'public-test-key',
        isRelease: true,
      );

      expect(configuration.environment, AppEnvironment.production);
      expect(configuration.isDemo, isFalse);
    });

    test('rejects cleartext remote backends', () {
      expect(
        () => AppConfiguration.fromValues(
          environment: 'staging',
          supabaseUrl: 'http://staging.example.test',
          supabasePublishableKey: 'public-test-key',
          isRelease: false,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('allows loopback HTTP only outside release builds', () {
      final development = AppConfiguration.fromValues(
        environment: 'staging',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: 'public-test-key',
        isRelease: false,
      );
      expect(development.environment, AppEnvironment.staging);
      expect(
        () => AppConfiguration.fromValues(
          environment: 'staging',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'public-test-key',
          isRelease: true,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('rejects Supabase service-role and secret keys', () {
      for (final key in [
        'sb_secret_should-never-be-mobile',
        'e30.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature',
      ]) {
        expect(
          () => AppConfiguration.fromValues(
            environment: 'production',
            supabaseUrl: 'https://example.supabase.co',
            supabasePublishableKey: key,
            isRelease: true,
          ),
          throwsA(isA<AppConfigurationException>()),
        );
      }
    });

    test('requires the registered authentication callback', () {
      for (final redirect in [
        'https://example.test/callback',
        'io.livelocal.app://attacker/callback',
        'io.livelocal.app://auth/other',
      ]) {
        expect(
          () => AppConfiguration.fromValues(
            environment: 'production',
            supabaseUrl: 'https://example.supabase.co',
            supabasePublishableKey: 'public-test-key',
            authRedirectUrl: redirect,
            isRelease: true,
          ),
          throwsA(isA<AppConfigurationException>()),
        );
      }
    });
  });

  group('explicit demo authentication', () {
    setUpAll(() {
      SupabaseRepository().configureForDemo();
    });

    test('rejects an arbitrary password for a fixture email', () async {
      final controller = AuthController(repository: DemoAuthRepository());

      final success = await controller.login(
        'tourist@livelocal.my',
        'not-the-demo-password',
      );

      expect(success, isFalse);
      expect(controller.isAuthenticated, isFalse);
    });

    test('accepts only the documented fixture password', () async {
      final controller = AuthController(repository: DemoAuthRepository());

      final success = await controller.login(
        'tourist@livelocal.my',
        SeedDataService.demoPassword,
      );

      expect(success, isTrue);
      expect(controller.currentUser?.role, 'tourist');
    });

    test('all demo registrations create tourist profiles', () async {
      final controller = AuthController(repository: DemoAuthRepository());
      final email =
          'new-tourist-${DateTime.now().microsecondsSinceEpoch}@example.test';

      final success = await controller.register(
        email,
        SeedDataService.demoPassword,
        'New Tourist',
      );

      expect(success, isTrue);
      expect(controller.currentUser?.role, 'tourist');
    });
  });
}
