class SpotModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String state;
  final String city;
  final String address;
  final String priceRange;
  final String bestTime;
  final String thingsToDo;
  final String imageUrl;
  final String? imagePath;
  final double rating;
  final int reviewCount;
  final String submittedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final double? latitude;
  final double? longitude;
  final String? revisionId;
  final int moderationVersion;
  final String? decisionReason;
  final bool hasApprovedRevision;

  SpotModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.state,
    required this.city,
    required this.address,
    required this.priceRange,
    required this.bestTime,
    required this.thingsToDo,
    required this.imageUrl,
    this.imagePath,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.submittedBy,
    this.status = 'pending',
    this.rejectionReason,
    this.latitude,
    this.longitude,
    this.revisionId,
    this.moderationVersion = 1,
    this.decisionReason,
    this.hasApprovedRevision = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'state': state,
        'city': city,
        'address': address,
        'price_range': priceRange,
        'best_time': bestTime,
        'things_to_do': thingsToDo,
        'image_url': imageUrl,
        'image_path': imagePath,
        'rating': rating,
        'review_count': reviewCount,
        'submitted_by': submittedBy,
        'status': status,
        'rejection_reason': rejectionReason,
        'latitude': latitude,
        'longitude': longitude,
        'revision_id': revisionId,
        'moderation_version': moderationVersion,
        'decision_reason': decisionReason,
        'has_approved_revision': hasApprovedRevision,
      };

  factory SpotModel.fromMap(Map<String, dynamic> map) => SpotModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        category: map['category'] ?? '',
        description: map['description'] ?? '',
        state: map['state'] ?? '',
        city: map['city'] ?? '',
        address: map['address'] ?? '',
        priceRange: map['price_range'] ?? '\$',
        bestTime: map['best_time'] ?? '',
        thingsToDo: map['things_to_do'] ?? '',
        imageUrl: map['image_url'] ?? '',
        imagePath: map['image_path'],
        rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: map['review_count'] ?? 0,
        submittedBy: map['submitted_by'] ?? '',
        status: map['status'] ?? 'pending',
        rejectionReason: map['rejection_reason'],
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        revisionId: map['revision_id'],
        moderationVersion: (map['moderation_version'] as num?)?.toInt() ?? 1,
        decisionReason: map['decision_reason'],
        hasApprovedRevision: map['has_approved_revision'] ?? false,
      );
}
