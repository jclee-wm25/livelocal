import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../repositories/supabase_repository.dart';

/// Abstract strategy for calculating proximity-based itineraries.
abstract class RoutingStrategy {
  List<Map<String, dynamic>> calculateRoute(
    double startLat,
    double startLng,
    List<SpotModel> spots,
    List<RestaurantModel> restaurants,
  );
}

/// A basic implementation that visits the next geographically closest point.
class NearestNeighborRouting implements RoutingStrategy {
  @override
  List<Map<String, dynamic>> calculateRoute(
    double startLat,
    double startLng,
    List<SpotModel> spots,
    List<RestaurantModel> restaurants,
  ) {
    final List<Map<String, dynamic>> unvisited = [];
    
    for (var s in spots) {
      if (s.latitude != null && s.longitude != null) {
        unvisited.add({'type': 'Spot', 'item': s, 'lat': s.latitude!, 'lng': s.longitude!});
      }
    }
    for (var r in restaurants) {
      if (r.latitude != null && r.longitude != null) {
        unvisited.add({'type': 'Restaurant', 'item': r, 'lat': r.latitude!, 'lng': r.longitude!});
      }
    }

    if (unvisited.isEmpty) return [];

    final List<Map<String, dynamic>> route = [];
    double currentLat = startLat;
    double currentLng = startLng;

    while (unvisited.isNotEmpty) {
      int closestIndex = 0;
      double minDistance = double.maxFinite;

      for (int i = 0; i < unvisited.length; i++) {
        final dist = _calculateHaversineDistance(
          currentLat, currentLng, unvisited[i]['lat'], unvisited[i]['lng']
        );
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }

      final nextStop = unvisited.removeAt(closestIndex);
      route.add(nextStop);
      currentLat = nextStop['lat'];
      currentLng = nextStop['lng'];
    }

    return route;
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
        
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

class LocationService {
  final SupabaseRepository _repo = SupabaseRepository();
  final RoutingStrategy _routingStrategy;

  // Injection allows easy swapping of routing logic in the future
  LocationService({RoutingStrategy? routingStrategy}) 
    : _routingStrategy = routingStrategy ?? NearestNeighborRouting();

  String get _mapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Fetches the user's current GPS location, handling permissions gracefully.
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: Location permissions are denied');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('LocationService: Location permissions are permanently denied.');
      return null;
    } 

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('LocationService: Error getting location: $e');
      return null;
    }
  }

  /// Geocodes an address string into latitude and longitude using Google Maps.
  Future<Map<String, double>?> geocodeAddress(String address) async {
    if (_mapsApiKey.isEmpty) {
      debugPrint('LocationService: Missing Google Maps API Key in .env. Geocoding aborted.');
      return null;
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_mapsApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'latitude': location['lat'],
            'longitude': location['lng'],
          };
        }
      }
    } catch (e) {
      debugPrint('LocationService: Geocoding HTTP request failed: $e');
    }
    return null;
  }

  /// Ensures a Spot has coordinates. If not, attempts to geocode and save it.
  Future<SpotModel> ensureSpotCoordinates(SpotModel spot) async {
    if (spot.latitude != null && spot.longitude != null) return spot;
    
    final coords = await geocodeAddress('${spot.address}, ${spot.city}, ${spot.state}');
    if (coords != null) {
      final updatedSpot = SpotModel(
        id: spot.id,
        name: spot.name,
        category: spot.category,
        description: spot.description,
        state: spot.state,
        city: spot.city,
        address: spot.address,
        priceRange: spot.priceRange,
        bestTime: spot.bestTime,
        thingsToDo: spot.thingsToDo,
        imageUrl: spot.imageUrl,
        rating: spot.rating,
        reviewCount: spot.reviewCount,
        submittedBy: spot.submittedBy,
        status: spot.status,
        rejectionReason: spot.rejectionReason,
        latitude: coords['latitude'],
        longitude: coords['longitude'],
      );
      await _repo.updateSpot(updatedSpot);
      return updatedSpot;
    }
    // If geocoding fails, return the original spot (which lacks coordinates)
    return spot;
  }

  /// Ensures a Restaurant has coordinates. If not, attempts to geocode and save it.
  Future<RestaurantModel> ensureRestaurantCoordinates(RestaurantModel restaurant) async {
    if (restaurant.latitude != null && restaurant.longitude != null) return restaurant;
    
    final coords = await geocodeAddress('${restaurant.address}, ${restaurant.city}, ${restaurant.state}');
    if (coords != null) {
      final updatedRestaurant = RestaurantModel(
        id: restaurant.id,
        name: restaurant.name,
        address: restaurant.address,
        state: restaurant.state,
        city: restaurant.city,
        cuisineType: restaurant.cuisineType,
        priceRange: restaurant.priceRange,
        reviewedDishes: restaurant.reviewedDishes,
        influencerId: restaurant.influencerId,
        influencerName: restaurant.influencerName,
        socialMediaUrl: restaurant.socialMediaUrl,
        coverPhotoUrl: restaurant.coverPhotoUrl,
        latitude: coords['latitude'],
        longitude: coords['longitude'],
      );
      // Assuming updateRestaurant is available
      // await _repo.updateRestaurant(updatedRestaurant);
      return updatedRestaurant;
    }
    return restaurant;
  }

  /// Calculates the optimized route using the injected RoutingStrategy.
  List<Map<String, dynamic>> sortLocationsByProximity(
    double startLat,
    double startLng,
    List<SpotModel> spots,
    List<RestaurantModel> restaurants,
  ) {
    return _routingStrategy.calculateRoute(startLat, startLng, spots, restaurants);
  }
}
