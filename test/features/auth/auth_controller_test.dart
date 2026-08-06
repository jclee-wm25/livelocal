import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/auth/presentation/auth_controller.dart';
import 'package:live_local/models/profile_model.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  group('AuthController session and access states', () {
    test('restores a guest session explicitly', () async {
      final controller = AuthController(repository: DemoAuthRepository());

      await controller.initialize();

      expect(controller.status, AuthStatus.guest);
      expect(controller.currentUser, isNull);
    });

    test('maps a restricted account to a restricted gate', () async {
      final repository = DemoAuthRepository(
        initialProfiles: [
          ProfileModel(
            id: 'restricted-user',
            email: 'restricted@example.test',
            fullName: 'Restricted User',
            role: 'tourist',
            isSuspended: true,
          ),
        ],
      );
      final controller = AuthController(repository: repository);

      final signedIn = await controller.login(
        'restricted@example.test',
        SeedDataService.demoPassword,
      );

      expect(signedIn, isTrue);
      expect(controller.status, AuthStatus.restricted);
      expect(controller.canWrite, isFalse);
    });

    test('logout clears account state', () async {
      final controller = AuthController(repository: DemoAuthRepository());
      await controller.login(
        'tourist@livelocal.com',
        SeedDataService.demoPassword,
      );

      await controller.logout();

      expect(controller.status, AuthStatus.guest);
      expect(controller.currentUser, isNull);
    });
  });
}
