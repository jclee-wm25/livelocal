import 'package:flutter/foundation.dart';
import '../models/saved_place_model.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../services/supabase_service.dart';

class ItineraryController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  List<SavedPlaceModel> _savedPlaces = [];
  bool _isLoading = false;

  List<SavedPlaceModel> get savedPlaces => _savedPlaces;
  bool get isLoading => _isLoading;

  Future<void> loadSavedPlaces(String userId) async {
    _isLoading = true;
    notifyListeners();
    _savedPlaces = await _db.fetchSavedPlaces(userId);
    _isLoading = false;
    notifyListeners();
  }

  bool isSaved(String userId, {String? spotId, String? restaurantId}) {
    return _savedPlaces.any((p) => p.userId == userId && ((spotId != null && p.spotId == spotId) || (restaurantId != null && p.restaurantId == restaurantId)));
  }

  Future<void> toggleSave(String userId, {String? spotId, String? restaurantId}) async {
    if (isSaved(userId, spotId: spotId, restaurantId: restaurantId)) {
      await _db.removeSavedPlace(userId, spotId: spotId, restaurantId: restaurantId);
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
    await loadSavedPlaces(userId);
  }

  // Generates proximity-grouped itinerary schedule
  List<Map<String, String>> generateProximityItinerary(List<SpotModel> allSpots, List<RestaurantModel> allRestaurants) {
    final List<Map<String, String>> itinerary = [];
    int stepNumber = 1;

    for (var saved in _savedPlaces) {
      if (saved.spotId != null) {
        final matches = allSpots.where((s) => s.id == saved.spotId).toList();
        if (matches.isNotEmpty) {
          final spot = matches.first;
          itinerary.add({
            'step': 'Stop $stepNumber',
            'title': spot.name,
            'location': '${spot.city}, ${spot.state}',
            'best_time': spot.bestTime,
            'activity': spot.thingsToDo,
            'type': 'Spot (${spot.category})',
          });
          stepNumber++;
        }
      } else if (saved.restaurantId != null) {
        final matches = allRestaurants.where((r) => r.id == saved.restaurantId).toList();
        if (matches.isNotEmpty) {
          final rest = matches.first;
          itinerary.add({
            'step': 'Stop $stepNumber',
            'title': rest.name,
            'location': '${rest.city}, ${rest.state}',
            'best_time': 'Meal Stop',
            'activity': 'Try: ${rest.reviewedDishes}',
            'type': 'Restaurant (${rest.cuisineType})',
          });
          stepNumber++;
        }
      }
    }
    return itinerary;
  }
}
