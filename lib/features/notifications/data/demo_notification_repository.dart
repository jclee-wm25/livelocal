import '../../../core/errors/app_exception.dart';
import '../../../models/notification_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../domain/notification_repository.dart';

class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository(this._authRepository)
      : _notifications = List.of(SeedDataService.getInitialNotifications());

  final DemoAuthRepository _authRepository;
  final List<NotificationModel> _notifications;

  @override
  Future<List<NotificationModel>> fetchMine() async {
    final userId = _requireUser();
    return _notifications
        .where((notification) => notification.userId == userId)
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  @override
  Future<void> markRead(String? notificationId) async {
    final userId = _requireUser();
    for (var index = 0; index < _notifications.length; index++) {
      final value = _notifications[index];
      if (value.userId == userId &&
          !value.isRead &&
          (notificationId == null || value.id == notificationId)) {
        _notifications[index] = NotificationModel(
          id: value.id,
          userId: value.userId,
          title: value.title,
          message: value.message,
          type: value.type,
          isRead: true,
          createdAt: value.createdAt,
          targetType: value.targetType,
          targetId: value.targetId,
          readAt: DateTime.now(),
        );
      }
    }
  }

  String _requireUser() {
    final userId = _authRepository.currentAccountForDemo?.id;
    if (userId == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to view notifications.',
      );
    }
    return userId;
  }
}
