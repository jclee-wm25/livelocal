import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';

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
        unvisited.add({
          'type': 'Spot',
          'item': s,
          'lat': s.latitude!,
          'lng': s.longitude!
        });
      }
    }
    for (var r in restaurants) {
      if (r.latitude != null && r.longitude != null) {
        unvisited.add({
          'type': 'Restaurant',
          'item': r,
          'lat': r.latitude!,
          'lng': r.longitude!
        });
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
            currentLat, currentLng, unvisited[i]['lat'], unvisited[i]['lng']);
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

  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

class LocationService {
  final RoutingStrategy _routingStrategy;

  // Injection allows easy swapping of routing logic in the future
  LocationService({RoutingStrategy? routingStrategy})
      : _routingStrategy = routingStrategy ?? NearestNeighborRouting();

  /// Fetches the user's current GPS location, handling permissions gracefully.
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates the optimized route using the injected RoutingStrategy.
  List<Map<String, dynamic>> sortLocationsByProximity(
    double startLat,
    double startLng,
    List<SpotModel> spots,
    List<RestaurantModel> restaurants,
  ) {
    return _routingStrategy.calculateRoute(
        startLat, startLng, spots, restaurants);
  }
}
