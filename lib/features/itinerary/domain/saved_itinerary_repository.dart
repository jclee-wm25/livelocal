import '../../../models/saved_place_model.dart';

class RouteOrigin {
  const RouteOrigin({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.mode,
    this.state,
    this.city,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String mode;
  final String? state;
  final String? city;
}

class ItineraryTarget {
  const ItineraryTarget({required this.type, required this.id});

  final String type;
  final String id;

  Map<String, String> toMap() => {'type': type, 'id': id};
}

class SavedItinerary {
  const SavedItinerary({
    required this.id,
    required this.title,
    required this.originLabel,
    required this.version,
    required this.createdAt,
    required this.targets,
  });

  final String id;
  final String title;
  final String originLabel;
  final int version;
  final DateTime createdAt;
  final List<ItineraryTarget> targets;
}

abstract interface class SavedItineraryRepository {
  Future<List<SavedPlaceModel>> fetchSavedPlaces();
  Future<bool> setSaved({
    required String targetType,
    required String targetId,
    required bool saved,
  });

  Future<List<SavedItinerary>> fetchItineraries();
  Future<SavedItinerary> createItinerary({
    required String title,
    required RouteOrigin origin,
    required List<ItineraryTarget> orderedTargets,
  });

  Future<void> saveLocationPreference(RouteOrigin origin);
}
