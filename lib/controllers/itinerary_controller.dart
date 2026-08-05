import 'package:flutter/foundation.dart';
import '../models/saved_place_model.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../repositories/supabase_repository.dart';
import '../services/location_service.dart';

class ItineraryController with ChangeNotifier {
  final SupabaseRepository _db = SupabaseRepository();
  final LocationService _locationService = LocationService();

  List<SavedPlaceModel> _savedPlaces = [];
  List<Map<String, Object>> _itinerarySteps = [];
  bool _isLoading = false;
  bool _isGeneratingItinerary = false;
  String? _itineraryError;

  List<SavedPlaceModel> get savedPlaces => _savedPlaces;
  List<Map<String, Object>> get itinerarySteps => _itinerarySteps;
  bool get isLoading => _isLoading;
  bool get isGeneratingItinerary => _isGeneratingItinerary;
  String? get itineraryError => _itineraryError;

  Future<void> loadSavedPlaces(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _savedPlaces = await _db.fetchSavedPlaces(userId);
    } catch (e) {
      debugPrint('ItineraryController: loadSavedPlaces failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isSaved(String userId, {String? spotId, String? restaurantId}) {
    return _savedPlaces.any((p) =>
        p.userId == userId &&
        ((spotId != null && p.spotId == spotId) ||
            (restaurantId != null && p.restaurantId == restaurantId)));
  }

  Future<void> toggleSave(String userId,
      {String? spotId, String? restaurantId}) async {
    try {
      if (isSaved(userId, spotId: spotId, restaurantId: restaurantId)) {
        await _db.removeSavedPlace(userId,
            spotId: spotId, restaurantId: restaurantId);
      } else {
        final newItem = SavedPlaceModel(
          id: 'save-${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          spotId: spotId,
          restaurantId: restaurantId,
          savedAt: DateTime.now(),
        );
        await _db.savePlace(newItem);
      }
    } catch (e) {
      debugPrint('ItineraryController: toggleSave failed: $e');
      rethrow;
    }
    await loadSavedPlaces(userId);
  }

  /// Generates a coordinate-based proximity itinerary using LocationService.
  Future<void> generateProximityItinerary(
      List<SpotModel> allSpots, List<RestaurantModel> allRestaurants) async {
    _isGeneratingItinerary = true;
    _itineraryError = null;
    notifyListeners();

    try {
      final List<SpotModel> savedSpots = [];
      final List<RestaurantModel> savedRestaurants = [];

      for (var saved in _savedPlaces) {
        if (saved.spotId != null) {
          final matches = allSpots.where((s) => s.id == saved.spotId).toList();
          if (matches.isNotEmpty) {
            // Geocode and save if missing coordinates
            final spot =
                await _locationService.ensureSpotCoordinates(matches.first);
            savedSpots.add(spot);
          }
        } else if (saved.restaurantId != null) {
          final matches =
              allRestaurants.where((r) => r.id == saved.restaurantId).toList();
          if (matches.isNotEmpty) {
            // Geocode and save if missing coordinates
            final rest = await _locationService
                .ensureRestaurantCoordinates(matches.first);
            savedRestaurants.add(rest);
          }
        }
      }

      if (savedSpots.isEmpty && savedRestaurants.isEmpty) {
        _itinerarySteps = [];
        return;
      }

      // Manual starting-location selection is an approved later-phase feature.
      // Until then, do not silently substitute a hard-coded location.
      final userPos = await _locationService.getCurrentLocation();
      if (userPos == null) {
        _itinerarySteps = [];
        _itineraryError =
            'Location is unavailable. Manual starting location is not yet implemented.';
        return;
      }

      final startLat = userPos.latitude;
      final startLng = userPos.longitude;

      final sortedRoute = _locationService.sortLocationsByProximity(
          startLat, startLng, savedSpots, savedRestaurants);

      final List<Map<String, Object>> itinerary = [];
      int stepNumber = 1;

      for (int i = 0; i < sortedRoute.length; i++) {
        final stop = sortedRoute[i];
        final isSpot = stop['type'] == 'Spot';

        String title = '';
        String location = '';
        String bestTime = '';
        String activity = '';
        String displayType = '';

        if (isSpot) {
          final s = stop['item'] as SpotModel;
          title = s.name;
          location = '${s.city}, ${s.state}';
          bestTime = s.bestTime;
          activity = s.thingsToDo;
          displayType = 'Spot (${s.category})';
        } else {
          final r = stop['item'] as RestaurantModel;
          title = r.name;
          location = '${r.city}, ${r.state}';
          bestTime = 'Meal Stop';
          activity = 'Try: ${r.reviewedDishes}';
          displayType = 'Restaurant (${r.cuisineType})';
        }

        itinerary.add({
          'title': title,
          'location': location,
          'best_time': bestTime,
          'activity': activity,
          'type': displayType,
          'step': 'Stop $stepNumber',
          'lat': stop['lat']!,
          'lng': stop['lng']!,
          if (i == 0) 'day_label': 'Route Overview',
        });
        stepNumber++;
      }

      _itinerarySteps = itinerary;
    } catch (e) {
      debugPrint('ItineraryController: generateProximityItinerary failed: $e');
      _itinerarySteps = [];
      _itineraryError = 'Could not generate the itinerary. Please try again.';
    } finally {
      _isGeneratingItinerary = false;
      notifyListeners();
    }
  }
}
