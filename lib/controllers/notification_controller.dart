import 'package:flutter/material.dart';

class NotificationController with ChangeNotifier {
  bool _hasUnread = true; // Set to true by default for testing

  bool get hasUnread => _hasUnread;

  // Call this when the user clicks the notification icon
  void markAsRead() {
    if (_hasUnread) {
      _hasUnread = false;
      notifyListeners();
    }
  }

  // Call this when a new notification is received
  void addNewNotification() {
    _hasUnread = true;
    notifyListeners();
  }
}
