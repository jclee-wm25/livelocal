import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/guide_model.dart';
import '../domain/guide_repository.dart';

class SupabaseGuideRepository implements GuideRepository {
  SupabaseGuideRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuideModel>> fetchPublishedGuides() async {
    try {
      final rows = await _client
          .from('published_guides')
          .select()
          .order('updated_at', ascending: false);
      return rows.map((row) => _map(row, status: 'approved')).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Neighbourhood guides could not be loaded.');
    }
  }

  @override
  Future<List<GuideModel>> fetchAdminDrafts() async {
    try {
      final rows = await _client
          .from('guide_revisions')
          .select('*, guides!inner(id, version)')
          .eq('status', 'draft')
          .order('updated_at', ascending: false);
      return rows.map((row) {
        final guide = Map<String, dynamic>.from(row['guides'] as Map);
        return _map(
          {
            ...row,
            'id': guide['id'],
            'revision_id': row['id'],
            'version': guide['version'],
          },
          status: 'draft',
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Guide drafts could not be loaded.');
    }
  }

  @override
  Future<GuideModel> saveAdminDraft(GuideDraftInput input) async {
    try {
      final response = await _client.rpc('admin_save_guide_draft', params: {
        'p_guide_id': null,
        'p_title': input.title,
        'p_location_name': input.locationName,
        'p_state': input.state,
        'p_route_overview': input.routeOverview,
        'p_stops': input.stops,
        'p_walking_sequence': input.walkingSequence,
        'p_estimated_duration': input.estimatedDuration,
        'p_expected_version': null,
      });
      final result = Map<String, dynamic>.from(response as Map);
      return GuideModel(
        id: result['guide_id'] as String,
        revisionId: result['revision_id'] as String,
        version: (result['version'] as num).toInt(),
        title: input.title,
        locationName: input.locationName,
        state: input.state,
        routeOverview: input.routeOverview,
        stops: input.stops,
        walkingSequence: input.walkingSequence,
        estimatedDuration: input.estimatedDuration,
        status: 'draft',
      );
    } on PostgrestException catch (error) {
      throw _error(error, 'The guide draft could not be saved.');
    }
  }

  @override
  Future<void> publishAdminDraft(GuideModel draft, String reason) async {
    try {
      await _client.rpc('admin_publish_guide_revision', params: {
        'p_revision_id': draft.revisionId,
        'p_reason': reason,
        'p_expected_version': draft.version,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'The guide could not be published.');
    }
  }

  GuideModel _map(Map<String, dynamic> row, {required String status}) {
    return GuideModel(
      id: row['id'] as String,
      revisionId: row['revision_id'] as String?,
      version: (row['version'] as num?)?.toInt() ?? 1,
      title: row['title'] as String,
      locationName: row['location_name'] as String,
      state: row['state'] as String,
      routeOverview: row['route_overview'] as String,
      stops: List<String>.from(row['stops'] as List),
      walkingSequence: List<String>.from(row['walking_sequence'] as List),
      estimatedDuration: row['estimated_duration'] as String,
      status: status,
    );
  }

  AppException _error(PostgrestException error, String fallback) {
    return AppException(
      code: error.code == '40001'
          ? AppErrorCode.conflict
          : error.code == '42501'
              ? AppErrorCode.forbidden
              : AppErrorCode.unexpected,
      userMessage: error.code == '40001'
          ? 'The guide changed. Refresh and try again.'
          : fallback,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
