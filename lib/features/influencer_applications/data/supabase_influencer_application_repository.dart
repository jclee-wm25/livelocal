import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/influencer_application_repository.dart';

class SupabaseInfluencerApplicationRepository
    implements InfluencerApplicationRepository {
  SupabaseInfluencerApplicationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InfluencerApplication?> fetchMine() async {
    try {
      final rows = await _client
          .from('influencer_applications')
          .select()
          .order('created_at', ascending: false)
          .limit(1);
      return rows.isEmpty ? null : _map(rows.first);
    } on PostgrestException catch (error) {
      throw _error(error, 'Your creator application could not be loaded.');
    }
  }

  @override
  Future<List<InfluencerApplication>> fetchPendingForAdmin() async {
    try {
      final rows = await _client
          .from('influencer_applications')
          .select()
          .inFilter(
              'status', ['submitted', 'under_review']).order('submitted_at');
      return rows.map(_map).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Creator applications could not be loaded.');
    }
  }

  @override
  Future<InfluencerApplication> saveDraft({
    InfluencerApplication? existing,
    required InfluencerApplicationDraft draft,
  }) async {
    final response = await _rpc('save_influencer_application_draft', {
      'p_application_id': existing?.id,
      'p_display_name': draft.displayName,
      'p_social_platform': draft.socialPlatform,
      'p_profile_url': draft.profileUrl,
      'p_follower_count': draft.followerCount,
      'p_content_category': draft.contentCategory,
      'p_application_message': draft.applicationMessage,
      'p_agree_to_rules': draft.rulesAgreed,
      'p_expected_version': existing?.version,
    });
    return _map(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<InfluencerApplication> submit(
    InfluencerApplication application,
  ) async {
    final response = await _rpc('submit_influencer_application', {
      'p_application_id': application.id,
      'p_expected_version': application.version,
    });
    return _map(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> withdraw(InfluencerApplication application) async {
    await _rpc('withdraw_influencer_application', {
      'p_application_id': application.id,
      'p_expected_version': application.version,
    });
  }

  @override
  Future<void> decide({
    required InfluencerApplication application,
    required String decision,
    required String reason,
  }) async {
    await _rpc('admin_decide_influencer_application', {
      'p_application_id': application.id,
      'p_decision': decision,
      'p_reason': reason,
      'p_expected_version': application.version,
    });
  }

  InfluencerApplication _map(Map<String, dynamic> row) {
    return InfluencerApplication(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      status: row['status'] as String,
      version: (row['version'] as num).toInt(),
      displayName: row['display_name'] as String?,
      socialPlatform: row['social_platform'] as String?,
      profileUrl: row['profile_url'] as String?,
      followerCount: (row['follower_count'] as num?)?.toInt(),
      contentCategory: row['content_category'] as String?,
      applicationMessage: row['application_message'] as String?,
      rulesAgreed: row['rules_agreed_at'] != null,
    );
  }

  Future<Object?> _rpc(String function, Map<String, dynamic> params) async {
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      throw _error(error, 'The creator application could not be updated.');
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
          ? 'The application changed. Refresh and try again.'
          : message,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
