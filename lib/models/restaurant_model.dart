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
  final String? coverImagePath;
  final double rating;
  final int reviewCount;
  final double? latitude;
  final double? longitude;
  final String? revisionId;
  final int moderationVersion;
  final String status;
  final String ownershipStatus;
  final String socialLinkStatus;
  final bool isOwnedByCurrentUser;
  final String? decisionReason;
  final bool hasApprovedRevision;

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
    this.coverImagePath,
    this.rating = 0,
    this.reviewCount = 0,
    this.latitude,
    this.longitude,
    this.revisionId,
    this.moderationVersion = 1,
    this.status = 'approved',
    this.ownershipStatus = 'creator_owned',
    this.socialLinkStatus = 'active',
    this.isOwnedByCurrentUser = false,
    this.decisionReason,
    this.hasApprovedRevision = false,
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
        'cover_image_path': coverImagePath,
        'rating': rating,
        'review_count': reviewCount,
        'latitude': latitude,
        'longitude': longitude,
        'revision_id': revisionId,
        'moderation_version': moderationVersion,
        'status': status,
        'ownership_status': ownershipStatus,
        'social_link_status': socialLinkStatus,
        'decision_reason': decisionReason,
        'has_approved_revision': hasApprovedRevision,
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
        coverImagePath: map['cover_image_path'],
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        revisionId: map['revision_id'],
        moderationVersion: (map['moderation_version'] as num?)?.toInt() ?? 1,
        status: map['status'] ?? 'approved',
        ownershipStatus: map['ownership_status'] ?? 'creator_owned',
        socialLinkStatus: map['social_link_status'] ?? 'active',
        isOwnedByCurrentUser: map['is_owned_by_current_user'] ?? false,
        decisionReason: map['decision_reason'],
        hasApprovedRevision: map['has_approved_revision'] ?? false,
      );
}
