import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/moderation/data/demo_moderation_repository.dart';
import 'package:live_local/features/moderation/presentation/moderation_controller.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  test('content reports require an account and prevent duplicate active cases',
      () async {
    final authRepository = DemoAuthRepository();
    final controller = ModerationController(
      repository: DemoModerationRepository(authRepository),
    );

    expect(
      await controller.reportContent(
        targetType: 'restaurant',
        targetId: 'rest-001',
        reason: 'broken_link',
        explanation: 'The profile no longer exists.',
        hideForReporter: false,
      ),
      isFalse,
    );
    expect(controller.errorMessage, contains('Sign in'));

    await authRepository.signIn(
      email: 'tourist@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    expect(
      await controller.reportContent(
        targetType: 'restaurant',
        targetId: 'rest-001',
        reason: 'broken_link',
        explanation: 'The profile no longer exists.',
        hideForReporter: false,
      ),
      isTrue,
    );
    expect(controller.lastReceipt?.status, 'pending');
    expect(
      await controller.reportContent(
        targetType: 'restaurant',
        targetId: 'rest-001',
        reason: 'broken_link',
        hideForReporter: false,
      ),
      isFalse,
    );
    expect(controller.errorMessage, contains('active report'));
  });
}
