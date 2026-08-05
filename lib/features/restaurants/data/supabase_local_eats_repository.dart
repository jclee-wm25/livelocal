import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/discount_code_model.dart';
import '../../../models/restaurant_model.dart';
import '../domain/local_eats_repository.dart';

class SupabaseLocalEatsRepository implements LocalEatsRepository {
  SupabaseLocalEatsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RestaurantModel>> fetchPublicRestaurants() async {
    try {
      final rows = await _client
          .from('published_restaurants')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);
      final ownIds = _client.auth.currentUser == null
          ? const <String>{}
          : (await _client.from('restaurants').select('id'))
              .map((row) => row['id'] as String)
              .toSet();
      return Future.wait(
        rows.map((row) => _mapPublished(row, ownIds.contains(row['id']))),
      );
    } on PostgrestException catch (error) {
      throw _error(error, 'Restaurants could not be loaded.');
    }
  }

  @override
  Future<List<DiscountCodeModel>> fetchActiveDiscounts() async {
    try {
      final response = await _client.rpc('list_active_discounts');
      return (response as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['expiry_date'] = row['expires_at'];
        row['created_by'] = '';
        return DiscountCodeModel.fromMap(row);
      }).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Discounts could not be loaded.');
    }
  }

  @override
  Future<List<DiscountCodeModel>> fetchOwnedDiscounts() async {
    try {
      final response = await _client.rpc('list_my_discounts');
      return (response as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['expiry_date'] = row['expires_at'];
        row['created_by'] = _client.auth.currentUser?.id ?? '';
        return DiscountCodeModel.fromMap(row);
      }).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Your discounts could not be loaded.');
    }
  }

  @override
  Future<List<RestaurantModel>> fetchPendingRestaurants() async {
    try {
      final rows = await _client
          .from('restaurant_revisions')
          .select('*, restaurants!inner(id, moderation_version, owner_id)')
          .inFilter(
              'status', ['submitted', 'under_review']).order('submitted_at');
      return Future.wait(rows.map((row) async {
        final entity = Map<String, dynamic>.from(row['restaurants'] as Map);
        return RestaurantModel(
          id: entity['id'] as String,
          revisionId: row['id'] as String,
          moderationVersion: (entity['moderation_version'] as num).toInt(),
          name: row['name'] as String,
          address: row['address'] as String,
          state: row['state'] as String,
          city: row['city'] as String,
          cuisineType: row['cuisine_type'] as String,
          priceRange: row['price_range'] as String,
          reviewedDishes: row['reviewed_dishes'] as String,
          influencerId: entity['owner_id'] as String? ?? '',
          influencerName: '',
          socialMediaUrl: row['social_media_url'] as String,
          coverPhotoUrl: await _signedImage(row['cover_image_path'] as String?),
          status: row['status'] as String,
        );
      }));
    } on PostgrestException catch (error) {
      throw _error(error, 'Restaurant submissions could not be loaded.');
    }
  }

  @override
  Future<List<RestaurantModel>> fetchOwnedRestaurantSubmissions() async {
    try {
      final response = await _client.rpc('list_my_restaurant_submissions');
      return Future.wait((response as List<dynamic>).map((raw) async {
        final row = Map<String, dynamic>.from(raw as Map);
        return RestaurantModel(
          id: row['restaurant_id'] as String,
          revisionId: row['revision_id'] as String,
          moderationVersion: (row['moderation_version'] as num?)?.toInt() ?? 1,
          name: row['name'] as String,
          address: row['address'] as String,
          state: row['state'] as String,
          city: row['city'] as String,
          cuisineType: row['cuisine_type'] as String,
          priceRange: row['price_range'] as String,
          reviewedDishes: row['reviewed_dishes'] as String,
          influencerId: _client.auth.currentUser?.id ?? '',
          influencerName: '',
          socialMediaUrl: row['social_media_url'] as String,
          coverPhotoUrl: await _signedImage(row['cover_image_path'] as String?),
          coverImagePath: row['cover_image_path'] as String?,
          status: row['status'] as String,
          isOwnedByCurrentUser: true,
          decisionReason: row['decision_reason'] as String?,
          hasApprovedRevision: row['has_approved_revision'] as bool? ?? false,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
        );
      }));
    } on PostgrestException catch (error) {
      throw _error(error, 'Your restaurant submissions could not be loaded.');
    }
  }

  @override
  Future<RestaurantDraftResult> createRestaurantDraft({
    required RestaurantDraftInput input,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    late final String imagePath;
    try {
      imagePath = await _uploadImage(imageBytes, imageMimeType);
      final response = await _client.rpc('create_restaurant_draft', params: {
        'p_name': input.name,
        'p_address': input.address,
        'p_state': input.state,
        'p_city': input.city,
        'p_cuisine_type': input.cuisineType,
        'p_price_range': input.priceRange,
        'p_reviewed_dishes': input.reviewedDishes,
        'p_social_media_url': input.socialMediaUrl,
        'p_cover_image_path': imagePath,
        'p_latitude': input.latitude,
        'p_longitude': input.longitude,
      });
      final row = Map<String, dynamic>.from(response as Map);
      final duplicates =
          (row['probable_duplicates'] as List<dynamic>? ?? []).map((raw) {
        final duplicate = Map<String, dynamic>.from(raw as Map);
        return RestaurantModel(
          id: duplicate['id'] as String,
          name: duplicate['name'] as String,
          address: duplicate['address'] as String,
          state: duplicate['state'] as String,
          city: duplicate['city'] as String,
          cuisineType: '',
          priceRange: r'$',
          reviewedDishes: '',
          influencerId: '',
          influencerName: '',
          socialMediaUrl: '',
          coverPhotoUrl: '',
        );
      }).toList();
      return RestaurantDraftResult(
        restaurantId: row['restaurant_id'] as String,
        revisionId: row['revision_id'] as String,
        probableDuplicates: duplicates,
        imagePath: imagePath,
      );
    } on StorageException catch (error) {
      throw AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'The restaurant photo could not be uploaded.',
        technicalMessage: error.message,
        cause: error,
      );
    } on PostgrestException catch (error) {
      try {
        await _client.storage.from('restaurant-images').remove([imagePath]);
      } catch (cleanupError) {
        if (kDebugMode) {
          debugPrint('Restaurant image cleanup failed: $cleanupError');
        }
      }
      throw _error(error, 'The restaurant draft could not be saved.');
    }
  }

  @override
  Future<RestaurantDraftResult> saveRestaurantRevisionDraft({
    required RestaurantModel source,
    required RestaurantDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    String? uploadedPath;
    try {
      if (imageBytes != null) {
        uploadedPath = await _uploadImage(imageBytes, imageMimeType ?? '');
      }
      final response =
          await _client.rpc('save_restaurant_revision_draft', params: {
        'p_source_revision_id': source.revisionId,
        'p_name': input.name,
        'p_address': input.address,
        'p_state': input.state,
        'p_city': input.city,
        'p_cuisine_type': input.cuisineType,
        'p_price_range': input.priceRange,
        'p_reviewed_dishes': input.reviewedDishes,
        'p_social_media_url': input.socialMediaUrl,
        'p_cover_image_path': uploadedPath,
        'p_latitude': input.latitude,
        'p_longitude': input.longitude,
      });
      return _draftResult(Map<String, dynamic>.from(response as Map));
    } on StorageException catch (error) {
      throw AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'The revised restaurant photo could not be uploaded.',
        technicalMessage: error.message,
        cause: error,
      );
    } on PostgrestException catch (error) {
      if (uploadedPath != null) {
        await _removeFailedUpload(uploadedPath);
      }
      throw _error(error, 'The restaurant revision could not be saved.');
    }
  }

  @override
  Future<void> submitRestaurant({
    required String revisionId,
    String? duplicateOverrideReason,
  }) async {
    try {
      await _client.rpc('submit_restaurant_revision', params: {
        'p_revision_id': revisionId,
        'p_duplicate_override_reason': duplicateOverrideReason,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'The restaurant could not be submitted.');
    }
  }

  @override
  Future<void> deleteRestaurantDraft(RestaurantDraftResult draft) async {
    try {
      await _client.rpc(
        'delete_restaurant_draft',
        params: {'p_revision_id': draft.revisionId},
      );
    } on PostgrestException catch (error) {
      throw _error(error, 'The restaurant draft could not be discarded.');
    }
  }

  @override
  Future<void> withdrawRestaurantRevision(String revisionId) async {
    try {
      await _client.rpc(
        'withdraw_my_restaurant_revision',
        params: {'p_revision_id': revisionId},
      );
    } on PostgrestException catch (error) {
      throw _error(error, 'The restaurant submission could not be withdrawn.');
    }
  }

  @override
  Future<void> moderateRestaurant({
    required RestaurantModel restaurant,
    required String decision,
    required String reason,
  }) async {
    try {
      await _client.rpc('admin_moderate_restaurant_revision', params: {
        'p_revision_id': restaurant.revisionId,
        'p_decision': decision,
        'p_reason': reason,
        'p_expected_version': restaurant.moderationVersion,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'The restaurant decision could not be saved.');
    }
  }

  @override
  Future<DiscountCodeModel> createAndPublishDiscount(
    DiscountDraftInput input,
  ) async {
    try {
      final draftResponse = await _client.rpc('create_discount_draft', params: {
        'p_restaurant_id': input.restaurantId,
        'p_code': input.code,
        'p_description': input.description,
        'p_redemption_terms': input.redemptionTerms,
        'p_starts_at': input.startsAt.toUtc().toIso8601String(),
        'p_expires_at': input.expiresAt.toUtc().toIso8601String(),
      });
      final draft = Map<String, dynamic>.from(draftResponse as Map);
      final publishedResponse =
          await _client.rpc('transition_discount', params: {
        'p_discount_id': draft['id'],
        'p_action': 'publish',
        'p_expected_version': draft['version'],
      });
      final published = Map<String, dynamic>.from(publishedResponse as Map);
      published['expiry_date'] = published['expires_at'];
      return DiscountCodeModel.fromMap(published);
    } on PostgrestException catch (error) {
      throw _error(error, 'The discount could not be created.');
    }
  }

  @override
  Future<DiscountCodeModel> transitionDiscount({
    required DiscountCodeModel discount,
    required String action,
  }) async {
    try {
      final response = await _client.rpc('transition_discount', params: {
        'p_discount_id': discount.id,
        'p_action': action,
        'p_expected_version': discount.version,
      });
      final row = Map<String, dynamic>.from(response as Map);
      row['expiry_date'] = row['expires_at'];
      return DiscountCodeModel.fromMap(row);
    } on PostgrestException catch (error) {
      throw _error(error, 'The discount status could not be updated.');
    }
  }

  Future<RestaurantModel> _mapPublished(
    Map<String, dynamic> row,
    bool isOwned,
  ) async {
    return RestaurantModel(
      id: row['id'] as String,
      revisionId: row['revision_id'] as String,
      name: row['name'] as String,
      address: row['address'] as String,
      state: row['state'] as String,
      city: row['city'] as String,
      cuisineType: row['cuisine_type'] as String,
      priceRange: row['price_range'] as String,
      reviewedDishes: row['reviewed_dishes'] as String,
      influencerId: '',
      influencerName: row['creator_display_name'] as String? ?? 'LiveLocal',
      socialMediaUrl: row['social_media_url'] as String,
      coverPhotoUrl: await _signedImage(row['cover_image_path'] as String?),
      rating: (row['rating_average'] as num?)?.toDouble() ?? 0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      ownershipStatus: row['ownership_status'] as String,
      socialLinkStatus: row['social_link_status'] as String? ?? 'active',
      isOwnedByCurrentUser: isOwned,
    );
  }

  Future<String> _signedImage(String? path) async {
    if (path == null || path.isEmpty) return '';
    return _client.storage
        .from('restaurant-images')
        .createSignedUrl(path, 3600);
  }

  Future<String> _uploadImage(Uint8List bytes, String mimeType) async {
    _validateImage(bytes, mimeType);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to submit a restaurant.',
      );
    }
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage.from('restaurant-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );
    return path;
  }

  RestaurantDraftResult _draftResult(Map<String, dynamic> row) {
    final duplicates =
        (row['probable_duplicates'] as List<dynamic>? ?? []).map((raw) {
      final duplicate = Map<String, dynamic>.from(raw as Map);
      return RestaurantModel(
        id: duplicate['id'] as String,
        name: duplicate['name'] as String,
        address: duplicate['address'] as String,
        state: duplicate['state'] as String,
        city: duplicate['city'] as String,
        cuisineType: '',
        priceRange: r'$',
        reviewedDishes: '',
        influencerId: '',
        influencerName: '',
        socialMediaUrl: '',
        coverPhotoUrl: '',
      );
    }).toList();
    return RestaurantDraftResult(
      restaurantId: row['restaurant_id'] as String,
      revisionId: row['revision_id'] as String,
      probableDuplicates: duplicates,
      imagePath: row['image_path'] as String?,
    );
  }

  Future<void> _removeFailedUpload(String path) async {
    try {
      await _client.storage.from('restaurant-images').remove([path]);
    } catch (cleanupError) {
      if (kDebugMode) {
        debugPrint('Restaurant image cleanup failed: $cleanupError');
      }
    }
  }

  void _validateImage(Uint8List bytes, String mimeType) {
    if (bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024 ||
        !{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType) ||
        !_matchesMagicBytes(bytes, mimeType)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a JPEG, PNG or WebP photo up to 8 MB.',
      );
    }
  }

  bool _matchesMagicBytes(Uint8List bytes, String mimeType) {
    if (mimeType == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mimeType == 'image/png') {
      return bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
    }
    return bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }

  AppException _error(PostgrestException error, String message) {
    return AppException(
      code: error.code == '40001'
          ? AppErrorCode.conflict
          : error.code == '42501'
              ? AppErrorCode.forbidden
              : AppErrorCode.unexpected,
      userMessage: error.code == '40001'
          ? 'This item changed. Refresh and try again.'
          : message,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
