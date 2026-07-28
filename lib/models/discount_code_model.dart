class DiscountCodeModel {
  final String id;
  final String restaurantId;
  final String code;
  final String description;
  final DateTime expiryDate;
  final String createdBy;

  DiscountCodeModel({
    required this.id,
    required this.restaurantId,
    required this.code,
    required this.description,
    required this.expiryDate,
    required this.createdBy,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  Map<String, dynamic> toMap() => {
    'id': id,
    'restaurant_id': restaurantId,
    'code': code,
    'description': description,
    'expiry_date': expiryDate.toIso8601String(),
    'created_by': createdBy,
  };

  factory DiscountCodeModel.fromMap(Map<String, dynamic> map) => DiscountCodeModel(
    id: map['id'] ?? '',
    restaurantId: map['restaurant_id'] ?? '',
    code: map['code'] ?? '',
    description: map['description'] ?? '',
    expiryDate: DateTime.parse(map['expiry_date'] ?? DateTime.now().toIso8601String()),
    createdBy: map['created_by'] ?? '',
  );
}
