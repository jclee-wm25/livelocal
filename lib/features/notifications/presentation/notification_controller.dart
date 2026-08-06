import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/notification_model.dart';
import '../domain/notification_repository.dart';

class NotificationController with ChangeNotifier {
  NotificationController({required NotificationRepository repository})
      : _repository = repository;

  final NotificationRepository _repository;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _notifications = await _repository.fetchMine();
    } catch (error) {
      _errorMessage = _message(error, 'Notifications could not be loaded.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markRead(String notificationId) async {
    return _mark(notificationId);
  }

  Future<bool> markAllRead() async {
    return _mark(null);
  }

  Future<bool> _mark(String? notificationId) async {
    try {
      await _repository.markRead(notificationId);
      _notifications = await _repository.fetchMine();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _message(
        error,
        'Notification status could not be updated.',
      );
      notifyListeners();
      return false;
    }
  }

  String _message(Object error, String fallback) {
    return error is AppException ? error.userMessage : fallback;
  }
}
