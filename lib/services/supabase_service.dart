import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seed_data_service.dart';
import '../models/profile_model.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../models/discount_code_model.dart';
import '../models/saved_place_model.dart';
import '../models/guide_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isSupabaseInitialized = false;
  bool get isLiveSupabase => _isSupabaseInitialized;

  // In-memory persistent data store for local/demo mode
  final List<ProfileModel> _localProfiles = SeedDataService.getInitialProfiles();
  final List<SpotModel> _localSpots = SeedDataService.getInitialSpots();
  final List<RestaurantModel> _localRestaurants = SeedDataService.getInitialRestaurants();
  final List<DiscountCodeModel> _localDiscounts = SeedDataService.getInitialDiscountCodes();
  final List<SavedPlaceModel> _localSavedPlaces = [];
  final List<GuideModel> _localGuides = SeedDataService.getInitialGuides();
  final List<ReviewModel> _localReviews = SeedDataService.getInitialReviews();
  final List<NotificationModel> _localNotifications = SeedDataService.getInitialNotifications();

  Future<void> initialize({String? url, String? anonKey}) async {
    if (url != null && anonKey != null && url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _isSupabaseInitialized = true;
        if (kDebugMode) print('LiveLocal: Supabase initialized successfully.');
      } catch (e) {
        if (kDebugMode) print('LiveLocal: Supabase init fallback to local seed data store. Error: $e');
        _isSupabaseInitialized = false;
      }
    } else {
      if (kDebugMode) print('LiveLocal: Running in standalone local seed mode (Supabase ready).');
      _isSupabaseInitialized = false;
    }
  }

  // --- Profiles / Auth ---
  Future<List<ProfileModel>> fetchProfiles() async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('profiles').select();
      return (res as List).map((e) => ProfileModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localProfiles);
  }

  Future<void> saveProfile(ProfileModel profile) async {
    if (_isSupabaseInitialized) {
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

  // --- Local Spots ---
  Future<List<SpotModel>> fetchSpots() async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('spots').select();
      return (res as List).map((e) => SpotModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localSpots);
  }

  Future<void> addSpot(SpotModel spot) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('spots').insert(spot.toMap());
    } else {
      _localSpots.add(spot);
    }
  }

  Future<void> updateSpotStatus(String spotId, String status, {String? rejectionReason}) async {
    if (_isSupabaseInitialized) {
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

  // --- Restaurants / LocalEats ---
  Future<List<RestaurantModel>> fetchRestaurants() async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('restaurants').select();
      return (res as List).map((e) => RestaurantModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localRestaurants);
  }

  Future<void> addRestaurant(RestaurantModel restaurant) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('restaurants').insert(restaurant.toMap());
    } else {
      _localRestaurants.add(restaurant);
    }
  }

  // --- Discount Codes ---
  Future<List<DiscountCodeModel>> fetchDiscountCodes() async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('discount_codes').select();
      return (res as List).map((e) => DiscountCodeModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localDiscounts);
  }

  Future<void> addDiscountCode(DiscountCodeModel code) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('discount_codes').insert(code.toMap());
    } else {
      _localDiscounts.add(code);
    }
  }

  // --- Saved Places ---
  Future<List<SavedPlaceModel>> fetchSavedPlaces(String userId) async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('saved_places').select().eq('user_id', userId);
      return (res as List).map((e) => SavedPlaceModel.fromMap(e)).toList();
    }
    return _localSavedPlaces.where((p) => p.userId == userId).toList();
  }

  Future<void> savePlace(SavedPlaceModel item) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('saved_places').insert(item.toMap());
    } else {
      _localSavedPlaces.removeWhere((p) => p.userId == item.userId && (p.spotId == item.spotId || p.restaurantId == item.restaurantId));
      _localSavedPlaces.add(item);
    }
  }

  Future<void> removeSavedPlace(String userId, {String? spotId, String? restaurantId}) async {
    if (_isSupabaseInitialized) {
      if (spotId != null) {
        await Supabase.instance.client.from('saved_places').delete().match({'user_id': userId, 'spot_id': spotId});
      } else if (restaurantId != null) {
        await Supabase.instance.client.from('saved_places').delete().match({'user_id': userId, 'restaurant_id': restaurantId});
      }
    } else {
      _localSavedPlaces.removeWhere((p) => p.userId == userId && (p.spotId == spotId || p.restaurantId == restaurantId));
    }
  }

  // --- Guides ---
  Future<List<GuideModel>> fetchGuides() async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('neighbourhood_guides').select();
      return (res as List).map((e) => GuideModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localGuides);
  }

  Future<void> updateGuideStatus(String guideId, String status, {String? rejectionReason}) async {
    if (_isSupabaseInitialized) {
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
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('reviews').select();
      return (res as List).map((e) => ReviewModel.fromMap(e)).toList();
    }
    return List.unmodifiable(_localReviews);
  }

  Future<void> addReview(ReviewModel review) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('reviews').insert(review.toMap());
    } else {
      _localReviews.add(review);
    }
  }

  Future<void> flagReview(String reviewId, String reason) async {
    if (_isSupabaseInitialized) {
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
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('reviews').delete().eq('id', reviewId);
    } else {
      _localReviews.removeWhere((r) => r.id == reviewId);
    }
  }

  // --- Notifications ---
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    if (_isSupabaseInitialized) {
      final res = await Supabase.instance.client.from('notifications').select().eq('user_id', userId);
      return (res as List).map((e) => NotificationModel.fromMap(e)).toList();
    }
    return _localNotifications.where((n) => n.userId == userId || n.userId == 'all').toList();
  }

  Future<void> addNotification(NotificationModel notification) async {
    if (_isSupabaseInitialized) {
      await Supabase.instance.client.from('notifications').insert(notification.toMap());
    } else {
      _localNotifications.add(notification);
    }
  }
}
