import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/saved_place_model.dart';
import '../domain/saved_itinerary_repository.dart';

class SupabaseSavedItineraryRepository implements SavedItineraryRepository {
  SupabaseSavedItineraryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SavedPlaceModel>> fetchSavedPlaces() async {
    try {
      final rows = await _client
          .from('saved_places')
          .select()
          .order('saved_at', ascending: false);
      return rows.map(SavedPlaceModel.fromMap).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Saved places could not be loaded.');
    }
  }

  @override
  Future<bool> setSaved({
    required String targetType,
    required String targetId,
    required bool saved,
  }) async {
    try {
      final response = await _client.rpc('set_saved_place', params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_saved': saved,
      });
      return Map<String, dynamic>.from(response as Map)['saved'] as bool;
    } on PostgrestException catch (error) {
      throw _error(error, 'The saved-place change could not be completed.');
    }
  }

  @override
  Future<List<SavedItinerary>> fetchItineraries() async {
    try {
      final rows = await _client
          .from('itineraries')
          .select('*, itinerary_items(*)')
          .isFilter('archived_at', null)
          .order('updated_at', ascending: false);
      return rows.map((row) {
        final items = (row['itinerary_items'] as List<dynamic>? ?? [])
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .toList()
          ..sort(
            (left, right) =>
                (left['position'] as num).compareTo(right['position'] as num),
          );
        return SavedItinerary(
          id: row['id'] as String,
          title: row['title'] as String,
          originLabel: row['origin_label'] as String,
          version: (row['version'] as num).toInt(),
          createdAt: DateTime.parse(row['created_at'] as String),
          targets: items
              .map(
                (item) => ItineraryTarget(
                  type: item['spot_id'] == null ? 'restaurant' : 'spot',
                  id: (item['spot_id'] ?? item['restaurant_id']) as String,
                ),
              )
              .toList(),
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Saved itineraries could not be loaded.');
    }
  }

  @override
  Future<SavedItinerary> createItinerary({
    required String title,
    required RouteOrigin origin,
    required List<ItineraryTarget> orderedTargets,
  }) async {
    try {
      final response = await _client.rpc(
        'create_itinerary_from_saved',
        params: {
          'p_title': title,
          'p_origin_label': origin.label,
          'p_origin_latitude': origin.latitude,
          'p_origin_longitude': origin.longitude,
          'p_ordered_targets':
              orderedTargets.map((item) => item.toMap()).toList(),
        },
      );
      final row = Map<String, dynamic>.from(response as Map);
      return SavedItinerary(
        id: row['id'] as String,
        title: row['title'] as String,
        originLabel: origin.label,
        version: (row['version'] as num).toInt(),
        createdAt: DateTime.parse(row['created_at'] as String),
        targets: List.unmodifiable(orderedTargets),
      );
    } on PostgrestException catch (error) {
      throw _error(error, 'The itinerary could not be saved.');
    }
  }

  @override
  Future<void> saveLocationPreference(RouteOrigin origin) async {
    try {
      await _client.rpc('update_my_discovery_location', params: {
        'p_location_mode': origin.mode,
        'p_state': origin.state,
        'p_city': origin.city,
        'p_latitude': origin.latitude,
        'p_longitude': origin.longitude,
        'p_expected_version': null,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'The location preference could not be saved.');
    }
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
