import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/notification_model.dart';
import '../domain/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NotificationModel>> fetchMine() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map(NotificationModel.fromMap).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Notifications could not be loaded.');
    }
  }

  @override
  Future<void> markRead(String? notificationId) async {
    try {
      await _client.rpc('mark_notifications_read', params: {
        'p_notification_id': notificationId,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'Notification status could not be updated.');
    }
  }

  AppException _error(PostgrestException error, String fallback) {
    return AppException(
      code: error.code == '42501'
          ? AppErrorCode.forbidden
          : AppErrorCode.unexpected,
      userMessage: fallback,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
