import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/notifications/data/demo_notification_repository.dart';
import 'package:live_local/features/notifications/presentation/notification_controller.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  test('notification history is user-scoped and read state is persisted',
      () async {
    final authRepository = DemoAuthRepository();
    final repository = DemoNotificationRepository(authRepository);
    final controller = NotificationController(repository: repository);

    await authRepository.signIn(
      email: 'tourist@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    await controller.load();
    expect(controller.notifications, hasLength(2));
    expect(controller.unreadCount, 2);

    final firstId = controller.notifications.first.id;
    expect(await controller.markRead(firstId), isTrue);
    expect(controller.unreadCount, 1);
    expect(
      controller.notifications.singleWhere((item) => item.id == firstId).readAt,
      isNotNull,
    );

    expect(await controller.markAllRead(), isTrue);
    expect(controller.unreadCount, 0);

    await authRepository.registerTourist(
      email: 'another-tourist@example.test',
      password: SeedDataService.demoPassword,
      displayName: 'Another Tourist',
    );
    await controller.load();
    expect(controller.notifications, isEmpty);
  });

  test('guest notification access fails honestly', () async {
    final authRepository = DemoAuthRepository();
    final controller = NotificationController(
      repository: DemoNotificationRepository(authRepository),
    );

    await controller.load();

    expect(controller.notifications, isEmpty);
    expect(controller.errorMessage, contains('Sign in'));
  });
}
