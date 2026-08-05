import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/auth/presentation/auth_controller.dart';
import 'package:live_local/features/profile/data/demo_account_repository.dart';
import 'package:live_local/features/profile/presentation/account_controller.dart';
import 'package:live_local/services/seed_data_service.dart';
import 'package:live_local/features/profile/domain/account_repository.dart';

void main() {
  test('deletion requires reauthentication and can be recovered', () async {
    final authRepository = DemoAuthRepository();
    final authController = AuthController(repository: authRepository);
    final accountController = AccountController(
      repository: DemoAccountRepository(authRepository),
      authController: authController,
    );
    await authController.login(
      'tourist@livelocal.my',
      SeedDataService.demoPassword,
    );

    expect(await accountController.requestDeletion('wrong-password'), isFalse);
    expect(authController.status, AuthStatus.authenticated);

    expect(
      await accountController.requestDeletion(SeedDataService.demoPassword),
      isTrue,
    );
    expect(authController.status, AuthStatus.deletionPending);
    expect(authController.canWrite, isFalse);

    expect(
      await accountController.cancelDeletion(SeedDataService.demoPassword),
      isTrue,
    );
    expect(authController.status, AuthStatus.authenticated);
  });

  test('appeal status reloads and duplicate active appeals are rejected',
      () async {
    final authRepository = DemoAuthRepository();
    final accountRepository = DemoAccountRepository(authRepository);
    final authController = AuthController(repository: authRepository);
    final controller = AccountController(
      repository: accountRepository,
      authController: authController,
    );
    await authController.login(
      'tourist@livelocal.my',
      SeedDataService.demoPassword,
    );

    expect(
      await controller.submitAppeal(
        decisionId: 'demo-access-decision',
        reason: 'context',
        explanation: 'Important context was not included.',
      ),
      isTrue,
    );
    expect(controller.submittedAppeal?.status, AppealStatus.submitted);
    expect(
      await controller.submitAppeal(
        decisionId: 'demo-access-decision',
        reason: 'context',
      ),
      isFalse,
    );
    expect(controller.errorMessage, contains('active appeal'));

    await controller.loadAppeal('demo-access-decision');
    expect(controller.submittedAppeal?.version, 1);
  });
}
