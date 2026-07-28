class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String state;
  final String city;
  final String cuisineType;
  final String priceRange;
  final String reviewedDishes;
  final String influencerId;
  final String influencerName;
  final String socialMediaUrl;
  final String coverPhotoUrl;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.state,
    required this.city,
    required this.cuisineType,
    required this.priceRange,
    required this.reviewedDishes,
    required this.influencerId,
    required this.influencerName,
    required this.socialMediaUrl,
    required this.coverPhotoUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'state': state,
    'city': city,
    'cuisine_type': cuisineType,
    'price_range': priceRange,
    'reviewed_dishes': reviewedDishes,
    'influencer_id': influencerId,
    'influencer_name': influencerName,
    'social_media_url': socialMediaUrl,
    'cover_photo_url': coverPhotoUrl,
  };

  factory RestaurantModel.fromMap(Map<String, dynamic> map) => RestaurantModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    address: map['address'] ?? '',
    state: map['state'] ?? '',
    city: map['city'] ?? '',
    cuisineType: map['cuisine_type'] ?? '',
    priceRange: map['price_range'] ?? '\$',
    reviewedDishes: map['reviewed_dishes'] ?? '',
    influencerId: map['influencer_id'] ?? '',
    influencerName: map['influencer_name'] ?? '',
    socialMediaUrl: map['social_media_url'] ?? '',
    coverPhotoUrl: map['cover_photo_url'] ?? '',
  );
}
