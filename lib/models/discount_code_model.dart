class DiscountCodeModel {
  final String id;
  final String restaurantId;
  final String code;
  final String description;
  final DateTime expiryDate;
  final String createdBy;
  final bool isActive;
  final DateTime? startDate;
  final String redemptionTerms;
  final String status;
  final int version;

  DiscountCodeModel({
    required this.id,
    required this.restaurantId,
    required this.code,
    required this.description,
    required this.expiryDate,
    required this.createdBy,
    this.isActive = true,
    this.startDate,
    this.redemptionTerms = '',
    this.status = 'active',
    this.version = 1,
  });

  bool get isExpired =>
      status == 'expired' || DateTime.now().isAfter(expiryDate);
  bool get isCurrentlyActive =>
      isActive &&
      status == 'active' &&
      (startDate == null || !DateTime.now().isBefore(startDate!)) &&
      !isExpired;

  Map<String, dynamic> toMap() => {
        'id': id,
        'restaurant_id': restaurantId,
        'code': code,
        'description': description,
        'expiry_date': expiryDate.toIso8601String(),
        'created_by': createdBy,
        // Phase 7 replaces this compatibility flag with the approved discount
        // lifecycle: draft, scheduled, active, paused, expired, or revoked.
        'is_active': isActive,
        'starts_at': startDate?.toIso8601String(),
        'redemption_terms': redemptionTerms,
        'status': status,
        'version': version,
      };

  factory DiscountCodeModel.fromMap(Map<String, dynamic> map) =>
      DiscountCodeModel(
        id: map['id'] ?? '',
        restaurantId: map['restaurant_id'] ?? '',
        code: map['code'] ?? '',
        description: map['description'] ?? '',
        expiryDate: DateTime.parse(
            map['expiry_date'] ?? DateTime.now().toIso8601String()),
        createdBy: map['created_by'] ?? '',
        isActive: map['is_active'] ?? true,
        startDate: map['starts_at'] == null
            ? null
            : DateTime.parse(map['starts_at'] as String),
        redemptionTerms: map['redemption_terms'] ?? '',
        status: map['status'] ?? map['effective_status'] ?? 'active',
        version: (map['version'] as num?)?.toInt() ?? 1,
      );
}
