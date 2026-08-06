import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/admin/data/demo_admin_repository.dart';
import 'package:live_local/features/admin/presentation/admin_controller.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  test('admin cannot change their own account access', () async {
    final authRepository = DemoAuthRepository();
    await authRepository.signIn(
      email: 'admin@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    final controller = AdminController(
      repository: DemoAdminRepository(authRepository),
    );
    await controller.loadDashboard();
    final self = controller.accounts.singleWhere(
      (account) => account.email == 'admin@livelocal.com',
    );

    final saved = await controller.setAccountAccess(
      account: self,
      status: 'restricted',
      publicMessage: 'Temporary restriction',
      internalReason: 'Self restriction test',
      endsAt: DateTime.now().add(const Duration(days: 1)),
    );

    expect(saved, isFalse);
    expect(controller.errorMessage, contains('own access'));
  });
}
