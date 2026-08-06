class SavedPlaceModel {
  final String id;
  final String userId;
  final String? spotId;
  final String? restaurantId;
  final DateTime savedAt;

  SavedPlaceModel({
    required this.id,
    required this.userId,
    this.spotId,
    this.restaurantId,
    required this.savedAt,
  });

  factory SavedPlaceModel.fromMap(Map<String, dynamic> map) => SavedPlaceModel(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        spotId: map['spot_id'],
        restaurantId: map['restaurant_id'],
        savedAt:
            DateTime.parse(map['saved_at'] ?? DateTime.now().toIso8601String()),
      );
}
