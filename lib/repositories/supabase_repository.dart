import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/seed_data_service.dart';
import '../models/profile_model.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../models/discount_code_model.dart';
import '../models/saved_place_model.dart';
import '../models/guide_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';

enum RepositoryMode { unconfigured, demo, supabase }

class SupabaseRepository {
  static final SupabaseRepository _instance = SupabaseRepository._internal();
  factory SupabaseRepository() => _instance;
  SupabaseRepository._internal();

  RepositoryMode _mode = RepositoryMode.unconfigured;
  bool get isLiveSupabase => _mode == RepositoryMode.supabase;

  bool get _usesSupabase {
    switch (_mode) {
      case RepositoryMode.supabase:
        return true;
      case RepositoryMode.demo:
        return false;
      case RepositoryMode.unconfigured:
        throw StateError(
          'SupabaseRepository is unconfigured. Select an explicit environment before use.',
        );
    }
  }

  void configureForDemo() {
    if (kReleaseMode) {
      throw StateError('Demo fixtures are disabled in release builds.');
    }
    _mode = RepositoryMode.demo;
  }

  // In-memory fixture store for explicit local/demo mode. This is not durable
  // offline persistence. Phase 2 will replace the runtime switch with separate
  // environment-specific adapters.
  final List<ProfileModel> _localProfiles =
      SeedDataService.getInitialProfiles();
  final List<SpotModel> _localSpots = SeedDataService.getInitialSpots();
  final List<RestaurantModel> _localRestaurants =
      SeedDataService.getInitialRestaurants();
  final List<DiscountCodeModel> _localDiscounts =
      SeedDataService.getInitialDiscountCodes();
  final List<SavedPlaceModel> _localSavedPlaces = [];
  final List<GuideModel> _localGuides = SeedDataService.getInitialGuides();
  final List<ReviewModel> _localReviews = SeedDataService.getInitialReviews();
  final List<NotificationModel> _localNotifications =
      SeedDataService.getInitialNotifications();

  Future<void> initialize({String? url, String? publishableKey}) async {
    if (url == null ||
        publishableKey == null ||
        url.isEmpty ||
        publishableKey.isEmpty) {
      throw ArgumentError(
        'Supabase URL and publishable key are required.',
      );
    }

    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _mode = RepositoryMode.supabase;
      if (kDebugMode) {
        debugPrint('LiveLocal: Supabase initialized successfully.');
      }
    } catch (_) {
      _mode = RepositoryMode.unconfigured;
      rethrow;
    }
  }

  // --- Profiles / Auth ---
  Future<List<ProfileModel>> fetchProfiles() async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client.from('profiles').select();
      return (res as List).map((e) => ProfileModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localProfiles);
  }

  Future<void> saveProfile(ProfileModel profile) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('profiles').upsert(profile.toMap());
    } else {
      final index = _localProfiles.indexWhere((p) => p.id == profile.id);
      if (index >= 0) {
        _localProfiles[index] = profile;
      } else {
        _localProfiles.add(profile);
      }
    }
  }

  Future<AuthResponse?> signIn(String email, String password) async {
    if (_usesSupabase) {
      return await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    }
    // Explicit demo authentication is handled by AuthService.
    return null;
  }

  Future<AuthResponse?> signUp(String email, String password) async {
    if (_usesSupabase) {
      return await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
    }
    // Explicit demo registration is handled by AuthService.
    return null;
  }

  Future<void> signOut() async {
    if (_usesSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  // --- Local Spots ---
  Future<List<SpotModel>> fetchSpots() async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client.from('spots').select();
      return (res as List).map((e) => SpotModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localSpots);
  }

  Future<void> addSpot(SpotModel spot) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('spots').insert(spot.toMap());
    } else {
      _localSpots.add(spot);
    }
  }

  Future<void> updateSpot(SpotModel spot) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('spots')
          .update(spot.toMap())
          .eq('id', spot.id);
    } else {
      final idx = _localSpots.indexWhere((s) => s.id == spot.id);
      if (idx >= 0) {
        _localSpots[idx] = spot;
      }
    }
  }

  Future<void> updateSpotStatus(String spotId, String status,
      {String? rejectionReason}) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('spots').update({
        'status': status,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      }).eq('id', spotId);
    } else {
      final idx = _localSpots.indexWhere((s) => s.id == spotId);
      if (idx >= 0) {
        final existing = _localSpots[idx];
        _localSpots[idx] = SpotModel(
          id: existing.id,
          name: existing.name,
          category: existing.category,
          description: existing.description,
          state: existing.state,
          city: existing.city,
          address: existing.address,
          priceRange: existing.priceRange,
          bestTime: existing.bestTime,
          thingsToDo: existing.thingsToDo,
          imageUrl: existing.imageUrl,
          rating: existing.rating,
          reviewCount: existing.reviewCount,
          submittedBy: existing.submittedBy,
          status: status,
          rejectionReason: rejectionReason,
        );
      }
    }
  }

  Future<void> updateSpotRating(
      String spotId, double rating, int reviewCount) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('spots').update({
        'rating': rating,
        'review_count': reviewCount,
      }).eq('id', spotId);
    } else {
      final idx = _localSpots.indexWhere((s) => s.id == spotId);
      if (idx >= 0) {
        final existing = _localSpots[idx];
        _localSpots[idx] = SpotModel(
          id: existing.id,
          name: existing.name,
          category: existing.category,
          description: existing.description,
          state: existing.state,
          city: existing.city,
          address: existing.address,
          priceRange: existing.priceRange,
          bestTime: existing.bestTime,
          thingsToDo: existing.thingsToDo,
          imageUrl: existing.imageUrl,
          rating: rating,
          reviewCount: reviewCount,
          submittedBy: existing.submittedBy,
          status: existing.status,
          rejectionReason: existing.rejectionReason,
        );
      }
    }
  }

  // --- Restaurants / LocalEats ---
  Future<List<RestaurantModel>> fetchRestaurants() async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client.from('restaurants').select();
      return (res as List).map((e) => RestaurantModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localRestaurants);
  }

  Future<void> addRestaurant(RestaurantModel restaurant) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('restaurants')
          .insert(restaurant.toMap());
    } else {
      _localRestaurants.add(restaurant);
    }
  }

  Future<void> updateRestaurantRating(
      String restaurantId, double rating, int reviewCount) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('restaurants').update({
        'rating': rating,
        'review_count': reviewCount,
      }).eq('id', restaurantId);
    } else {
      final idx = _localRestaurants.indexWhere((r) => r.id == restaurantId);
      if (idx >= 0) {
        final existing = _localRestaurants[idx];
        _localRestaurants[idx] = RestaurantModel(
          id: existing.id,
          name: existing.name,
          cuisineType: existing.cuisineType,
          state: existing.state,
          city: existing.city,
          address: existing.address,
          priceRange: existing.priceRange,
          reviewedDishes: existing.reviewedDishes,
          rating: rating,
          reviewCount: reviewCount,
          influencerId: existing.influencerId,
          influencerName: existing.influencerName,
          socialMediaUrl: existing.socialMediaUrl,
          coverPhotoUrl: existing.coverPhotoUrl,
          latitude: existing.latitude,
          longitude: existing.longitude,
        );
      }
    }
  }

  // --- Discount Codes ---
  Future<List<DiscountCodeModel>> fetchDiscountCodes() async {
    if (_usesSupabase) {
      final res =
          await Supabase.instance.client.from('discount_codes').select();
      return (res as List).map((e) => DiscountCodeModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localDiscounts);
  }

  Future<void> addDiscountCode(DiscountCodeModel code) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('discount_codes')
          .insert(code.toMap());
    } else {
      _localDiscounts.add(code);
    }
  }

  Future<void> updateDiscountCodeStatus(String codeId, bool isActive) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('discount_codes').update({
        'is_active': isActive,
      }).eq('id', codeId);
    } else {
      final idx = _localDiscounts.indexWhere((c) => c.id == codeId);
      if (idx >= 0) {
        final existing = _localDiscounts[idx];
        _localDiscounts[idx] = DiscountCodeModel(
          id: existing.id,
          code: existing.code,
          description: existing.description,
          restaurantId: existing.restaurantId,
          expiryDate: existing.expiryDate,
          createdBy: existing.createdBy,
          isActive: isActive,
        );
      }
    }
  }

  // --- Saved Places ---
  Future<List<SavedPlaceModel>> fetchSavedPlaces(String userId) async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client
          .from('saved_places')
          .select()
          .eq('user_id', userId);
      return (res as List).map((e) => SavedPlaceModel.fromMap(e)).toList();
    }
    return _localSavedPlaces.where((p) => p.userId == userId).toList();
  }

  Future<void> savePlace(SavedPlaceModel item) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('saved_places').insert(item.toMap());
    } else {
      _localSavedPlaces.removeWhere((p) =>
          p.userId == item.userId &&
          (p.spotId == item.spotId || p.restaurantId == item.restaurantId));
      _localSavedPlaces.add(item);
    }
  }

  Future<void> removeSavedPlace(String userId,
      {String? spotId, String? restaurantId}) async {
    if (_usesSupabase) {
      if (spotId != null) {
        await Supabase.instance.client
            .from('saved_places')
            .delete()
            .match({'user_id': userId, 'spot_id': spotId});
      } else if (restaurantId != null) {
        await Supabase.instance.client
            .from('saved_places')
            .delete()
            .match({'user_id': userId, 'restaurant_id': restaurantId});
      }
    } else {
      _localSavedPlaces.removeWhere((p) =>
          p.userId == userId &&
          (p.spotId == spotId || p.restaurantId == restaurantId));
    }
  }

  // --- Guides ---
  Future<List<GuideModel>> fetchGuides() async {
    if (_usesSupabase) {
      final res =
          await Supabase.instance.client.from('neighbourhood_guides').select();
      return (res as List).map((e) => GuideModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localGuides);
  }

  Future<void> updateGuideStatus(String guideId, String status,
      {String? rejectionReason}) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('neighbourhood_guides').update({
        'status': status,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      }).eq('id', guideId);
    } else {
      final idx = _localGuides.indexWhere((g) => g.id == guideId);
      if (idx >= 0) {
        final existing = _localGuides[idx];
        _localGuides[idx] = GuideModel(
          id: existing.id,
          title: existing.title,
          locationName: existing.locationName,
          state: existing.state,
          routeOverview: existing.routeOverview,
          stops: existing.stops,
          walkingSequence: existing.walkingSequence,
          estimatedDuration: existing.estimatedDuration,
          status: status,
          rejectionReason: rejectionReason,
        );
      }
    }
  }

  // --- Reviews ---
  Future<List<ReviewModel>> fetchReviews() async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client.from('reviews').select();
      return (res as List).map((e) => ReviewModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localReviews);
  }

  Future<void> addReview(ReviewModel review) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('reviews').insert(review.toMap());
    } else {
      _localReviews.add(review);
    }
  }

  Future<void> flagReview(String reviewId, String reason) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('reviews').update({
        'is_flagged': true,
        'flag_reason': reason,
      }).eq('id', reviewId);
    } else {
      final idx = _localReviews.indexWhere((r) => r.id == reviewId);
      if (idx >= 0) {
        final e = _localReviews[idx];
        _localReviews[idx] = ReviewModel(
          id: e.id,
          spotId: e.spotId,
          restaurantId: e.restaurantId,
          userId: e.userId,
          userName: e.userName,
          rating: e.rating,
          comment: e.comment,
          photoUrl: e.photoUrl,
          isFlagged: true,
          flagReason: reason,
          createdAt: e.createdAt,
        );
      }
    }
  }

  Future<void> deleteReview(String reviewId) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('reviews')
          .delete()
          .eq('id', reviewId);
    } else {
      _localReviews.removeWhere((r) => r.id == reviewId);
    }
  }

  // --- Notifications ---
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId);
      return (res as List).map((e) => NotificationModel.fromMap(e)).toList();
    }
    return _localNotifications
        .where((n) => n.userId == userId || n.userId == 'all')
        .toList();
  }

  Future<void> addNotification(NotificationModel notification) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('notifications')
          .insert(notification.toMap());
    } else {
      _localNotifications.add(notification);
    }
  }

  // --- Phase 9: Moderation ---
  Future<void> submitReport(String reporterId, String targetId,
      String targetType, String reason) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': reporterId,
        'target_id': targetId,
        'target_type': targetType,
        'reason': reason,
        'status': 'pending',
      });
    } else {
      if (kDebugMode) {
        debugPrint('Local mode: report submitted for $targetType $targetId');
      }
    }
  }

  Future<void> blockUser(String blockerId, String blockedId) async {
    if (_usesSupabase) {
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
    } else {
      if (kDebugMode) {
        debugPrint('Local mode: user $blockerId blocked $blockedId');
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingReports() async {
    if (_usesSupabase) {
      final res = await Supabase.instance.client
          .from('reports')
          .select()
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(res);
    }
    return [];
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    if (_usesSupabase) {
      await Supabase.instance.client
          .from('reports')
          .update({'status': status}).eq('id', reportId);
    }
  }
}
