class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        type: map['type'] ?? 'general',
        isRead: map['is_read'] ?? false,
        createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String()),
      );
}
