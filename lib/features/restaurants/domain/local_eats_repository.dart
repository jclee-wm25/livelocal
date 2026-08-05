import 'dart:typed_data';

import '../../../models/discount_code_model.dart';
import '../../../models/restaurant_model.dart';

class RestaurantDraftInput {
  const RestaurantDraftInput({
    required this.name,
    required this.address,
    required this.state,
    required this.city,
    required this.cuisineType,
    required this.priceRange,
    required this.reviewedDishes,
    required this.socialMediaUrl,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final String state;
  final String city;
  final String cuisineType;
  final String priceRange;
  final String reviewedDishes;
  final String socialMediaUrl;
  final double? latitude;
  final double? longitude;
}

class RestaurantDraftResult {
  const RestaurantDraftResult({
    required this.restaurantId,
    required this.revisionId,
    required this.probableDuplicates,
    this.imagePath,
  });

  final String restaurantId;
  final String revisionId;
  final List<RestaurantModel> probableDuplicates;
  final String? imagePath;
}

class DiscountDraftInput {
  const DiscountDraftInput({
    required this.restaurantId,
    required this.code,
    required this.description,
    required this.redemptionTerms,
    required this.startsAt,
    required this.expiresAt,
  });

  final String restaurantId;
  final String code;
  final String description;
  final String redemptionTerms;
  final DateTime startsAt;
  final DateTime expiresAt;
}

abstract interface class LocalEatsRepository {
  Future<List<RestaurantModel>> fetchPublicRestaurants();
  Future<List<DiscountCodeModel>> fetchActiveDiscounts();
  Future<List<RestaurantModel>> fetchPendingRestaurants();

  Future<RestaurantDraftResult> createRestaurantDraft({
    required RestaurantDraftInput input,
    required Uint8List imageBytes,
    required String imageMimeType,
  });
  Future<void> submitRestaurant({
    required String revisionId,
    String? duplicateOverrideReason,
  });
  Future<void> deleteRestaurantDraft(RestaurantDraftResult draft);
  Future<void> moderateRestaurant({
    required RestaurantModel restaurant,
    required String decision,
    required String reason,
  });

  Future<DiscountCodeModel> createAndPublishDiscount(DiscountDraftInput input);
}
