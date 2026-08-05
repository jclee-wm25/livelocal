import '../../../models/notification_model.dart';

abstract interface class NotificationRepository {
  Future<List<NotificationModel>> fetchMine();
  Future<void> markRead(String? notificationId);
}
