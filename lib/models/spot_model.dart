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
  final double rating;
  final int reviewCount;
  final String submittedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final double? latitude;
  final double? longitude;

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
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.submittedBy,
    this.status = 'pending',
    this.rejectionReason,
    this.latitude,
    this.longitude,
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
    'rating': rating,
    'review_count': reviewCount,
    'submitted_by': submittedBy,
    'status': status,
    'rejection_reason': rejectionReason,
    'latitude': latitude,
    'longitude': longitude,
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
    rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: map['review_count'] ?? 0,
    submittedBy: map['submitted_by'] ?? '',
    status: map['status'] ?? 'pending',
    rejectionReason: map['rejection_reason'],
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
  );
}
