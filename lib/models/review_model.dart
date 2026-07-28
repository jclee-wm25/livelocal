class ReviewModel {
  final String id;
  final String? spotId;
  final String? restaurantId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final String? photoUrl;
  final bool isFlagged;
  final String? flagReason;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    this.spotId,
    this.restaurantId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.photoUrl,
    this.isFlagged = false,
    this.flagReason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'spot_id': spotId,
    'restaurant_id': restaurantId,
    'user_id': userId,
    'user_name': userName,
    'rating': rating,
    'comment': comment,
    'photo_url': photoUrl,
    'is_flagged': isFlagged,
    'flag_reason': flagReason,
    'created_at': createdAt.toIso8601String(),
  };

  factory ReviewModel.fromMap(Map<String, dynamic> map) => ReviewModel(
    id: map['id'] ?? '',
    spotId: map['spot_id'],
    restaurantId: map['restaurant_id'],
    userId: map['user_id'] ?? '',
    userName: map['user_name'] ?? 'Anonymous',
    rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    comment: map['comment'] ?? '',
    photoUrl: map['photo_url'],
    isFlagged: map['is_flagged'] ?? false,
    flagReason: map['flag_reason'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );
}
