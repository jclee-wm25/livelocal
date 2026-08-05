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
