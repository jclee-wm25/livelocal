class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? targetType;
  final String? targetId;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.targetType,
    this.targetId,
    this.readAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        title: map['title'] ?? '',
        message: map['message'] ?? map['body'] ?? '',
        type: map['type'] ?? 'general',
        isRead: map['is_read'] ?? map['read_at'] != null,
        createdAt: DateTime.parse(
            map['created_at'] ?? DateTime.now().toIso8601String()),
        targetType: map['target_type'],
        targetId: map['target_id'],
        readAt: map['read_at'] == null
            ? null
            : DateTime.parse(map['read_at'] as String),
      );
}
