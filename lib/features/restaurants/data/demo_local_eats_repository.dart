import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/validation/social_url_validator.dart';
import '../../../models/discount_code_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/local_eats_repository.dart';

class DemoLocalEatsRepository implements LocalEatsRepository {
  DemoLocalEatsRepository(this._authRepository)
      : _restaurants = List.of(SeedDataService.getInitialRestaurants()),
        _discounts = List.of(SeedDataService.getInitialDiscountCodes());

  final DemoAuthRepository _authRepository;
  final List<RestaurantModel> _restaurants;
  final List<DiscountCodeModel> _discounts;

  @override
  Future<List<RestaurantModel>> fetchPublicRestaurants() async {
    final userId = _authRepository.currentAccountForDemo?.id;
    return _restaurants
        .where((restaurant) => restaurant.status == 'approved')
        .map(
          (restaurant) => _copyRestaurant(
            restaurant,
            isOwnedByCurrentUser: restaurant.influencerId == userId,
          ),
        )
        .toList();
  }

  @override
  Future<List<DiscountCodeModel>> fetchActiveDiscounts() async {
    return _discounts.where((discount) => discount.isCurrentlyActive).toList();
  }

  @override
  Future<List<RestaurantModel>> fetchPendingRestaurants() async {
    _requireAdmin();
    return _restaurants
        .where((restaurant) => restaurant.status == 'submitted')
        .toList();
  }

  @override
  Future<RestaurantDraftResult> createRestaurantDraft({
    required RestaurantDraftInput input,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    final account = _requireInfluencer();
    _validateImage(imageBytes, imageMimeType);
    if (!SocialUrlValidator.isSupported(input.socialMediaUrl)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Use a supported TikTok or Instagram HTTPS URL.',
      );
    }
    final id = 'demo-restaurant-${DateTime.now().microsecondsSinceEpoch}';
    final revisionId =
        'demo-restaurant-revision-${DateTime.now().microsecondsSinceEpoch}';
    final duplicates = _restaurants
        .where(
          (restaurant) =>
              restaurant.status == 'approved' &&
              (restaurant.name.toLowerCase() == input.name.toLowerCase() ||
                  restaurant.address.toLowerCase() ==
                      input.address.toLowerCase()),
        )
        .toList();
    _restaurants.add(
      RestaurantModel(
        id: id,
        revisionId: revisionId,
        name: input.name,
        address: input.address,
        state: input.state,
        city: input.city,
        cuisineType: input.cuisineType,
        priceRange: input.priceRange,
        reviewedDishes: input.reviewedDishes,
        influencerId: account.id,
        influencerName: account.fullName,
        socialMediaUrl: input.socialMediaUrl,
        coverPhotoUrl: 'demo://restaurant-image/$revisionId',
        latitude: input.latitude,
        longitude: input.longitude,
        status: 'draft',
        isOwnedByCurrentUser: true,
      ),
    );
    return RestaurantDraftResult(
      restaurantId: id,
      revisionId: revisionId,
      probableDuplicates: duplicates,
      imagePath: 'demo://restaurant-image/$revisionId',
    );
  }

  @override
  Future<void> submitRestaurant({
    required String revisionId,
    String? duplicateOverrideReason,
  }) async {
    _requireInfluencer();
    final index = _restaurants.indexWhere(
      (restaurant) => restaurant.revisionId == revisionId,
    );
    if (index < 0 || _restaurants[index].status != 'draft') {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The restaurant draft is no longer available.',
      );
    }
    _restaurants[index] = _copyRestaurant(
      _restaurants[index],
      status: 'submitted',
    );
  }

  @override
  Future<void> deleteRestaurantDraft(RestaurantDraftResult draft) async {
    _requireInfluencer();
    _restaurants.removeWhere(
      (restaurant) =>
          restaurant.revisionId == draft.revisionId &&
          restaurant.status == 'draft',
    );
  }

  @override
  Future<void> moderateRestaurant({
    required RestaurantModel restaurant,
    required String decision,
    required String reason,
  }) async {
    _requireAdmin();
    if (!{'approved', 'rejected'}.contains(decision) ||
        reason.trim().length < 3) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a valid decision and record a reason.',
      );
    }
    final index = _restaurants.indexWhere(
      (item) => item.revisionId == restaurant.revisionId,
    );
    if (index < 0 ||
        _restaurants[index].moderationVersion != restaurant.moderationVersion) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'This restaurant changed. Refresh and try again.',
      );
    }
    _restaurants[index] = _copyRestaurant(
      _restaurants[index],
      status: decision,
      moderationVersion: restaurant.moderationVersion + 1,
    );
  }

  @override
  Future<DiscountCodeModel> createAndPublishDiscount(
    DiscountDraftInput input,
  ) async {
    final account = _requireInfluencer();
    if (!RegExp(r'^[A-Z0-9_-]{3,32}$').hasMatch(input.code.toUpperCase()) ||
        input.description.trim().length < 3 ||
        input.redemptionTerms.trim().length < 3 ||
        !input.expiresAt.isAfter(input.startsAt)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Check the code, offer terms, and validity dates.',
      );
    }
    final restaurant = _restaurants.where(
      (item) =>
          item.id == input.restaurantId &&
          item.influencerId == account.id &&
          item.status == 'approved',
    );
    if (restaurant.isEmpty) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Choose one of your approved restaurants.',
      );
    }
    final discount = DiscountCodeModel(
      id: 'demo-discount-${DateTime.now().microsecondsSinceEpoch}',
      restaurantId: input.restaurantId,
      code: input.code.toUpperCase(),
      description: input.description,
      expiryDate: input.expiresAt,
      startDate: input.startsAt,
      redemptionTerms: input.redemptionTerms,
      createdBy: account.id,
      status: input.startsAt.isAfter(DateTime.now()) ? 'scheduled' : 'active',
    );
    _discounts.add(discount);
    return discount;
  }

  AccountIdentity _requireInfluencer() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.influencer ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Approved creator access is required.',
      );
    }
    return account!;
  }

  void _requireAdmin() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.admin ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Administrator permission is required.',
      );
    }
  }

  void _validateImage(Uint8List bytes, String mimeType) {
    final validMime =
        {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType);
    final hasMagic = switch (mimeType) {
      'image/jpeg' => bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff,
      'image/png' => bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47,
      'image/webp' => bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
      _ => false,
    };
    if (bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024 ||
        !validMime ||
        !hasMagic) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a JPEG, PNG or WebP photo up to 8 MB.',
      );
    }
  }

  RestaurantModel _copyRestaurant(
    RestaurantModel value, {
    String? status,
    int? moderationVersion,
    bool? isOwnedByCurrentUser,
  }) {
    return RestaurantModel(
      id: value.id,
      revisionId: value.revisionId,
      moderationVersion: moderationVersion ?? value.moderationVersion,
      name: value.name,
      address: value.address,
      state: value.state,
      city: value.city,
      cuisineType: value.cuisineType,
      priceRange: value.priceRange,
      reviewedDishes: value.reviewedDishes,
      influencerId: value.influencerId,
      influencerName: value.influencerName,
      socialMediaUrl: value.socialMediaUrl,
      coverPhotoUrl: value.coverPhotoUrl,
      rating: value.rating,
      reviewCount: value.reviewCount,
      latitude: value.latitude,
      longitude: value.longitude,
      status: status ?? value.status,
      ownershipStatus: value.ownershipStatus,
      isOwnedByCurrentUser: isOwnedByCurrentUser ?? value.isOwnedByCurrentUser,
    );
  }
}
