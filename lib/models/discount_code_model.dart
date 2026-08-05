class DiscountCodeModel {
  final String id;
  final String restaurantId;
  final String code;
  final String description;
  final DateTime expiryDate;
  final String createdBy;

  final double discountPercentage;
  final bool isActive;

  DiscountCodeModel({
    required this.id,
    required this.restaurantId,
    required this.code,
    required this.description,
    required this.expiryDate,
    required this.createdBy,
    this.discountPercentage = 0.0,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  bool get isUsable => isActive && !isExpired;

  Map<String, dynamic> toMap() => {
        'id': id,
        'restaurant_id': restaurantId,
        'code': code,
        'description': description,
        'expiry_date': expiryDate.toIso8601String(),
        'created_by': createdBy,
        'discount_percentage': discountPercentage,
        'is_active': isActive,
      };

  factory DiscountCodeModel.fromMap(Map<String, dynamic> map) {
    return DiscountCodeModel(
      id: map['id'] ?? '',
      restaurantId: map['restaurant_id'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      expiryDate: DateTime.tryParse(
            map['expiry_date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      createdBy: map['created_by'] ?? '',
      discountPercentage:
          (map['discount_percentage'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
