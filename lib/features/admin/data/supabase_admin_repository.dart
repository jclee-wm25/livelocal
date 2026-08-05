import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/admin_repository.dart';

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminAccountSummary>> fetchAccounts() async {
    final response = await _rpc('admin_list_accounts');
    return (response as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return AdminAccountSummary(
        id: row['id'] as String,
        email: row['email'] as String? ?? '',
        displayName: row['display_name'] as String,
        role: row['role'] as String,
        accessStatus: row['access_status'] as String,
        accessVersion: (row['access_version'] as num).toInt(),
        accessMessage: row['access_message'] as String?,
        accessEndsAt: _date(row['access_ends_at']),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Future<List<AdminModerationCase>> fetchModerationCases() async {
    final response = await _rpc('admin_list_moderation_cases');
    return (response as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return AdminModerationCase(
        id: row['id'] as String,
        targetType: row['target_type'] as String,
        targetId: row['target_id'] as String,
        reason: row['reason'] as String,
        explanation: row['explanation'] as String?,
        status: row['status'] as String,
        version: (row['version'] as num).toInt(),
        targetPreview: row['target_preview'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Future<void> setAccountAccess({
    required AdminAccountSummary account,
    required String status,
    required String publicMessage,
    required String internalReason,
    DateTime? endsAt,
  }) async {
    await _rpc('admin_set_account_access', {
      'p_target_user_id': account.id,
      'p_new_status': status,
      'p_public_message': publicMessage,
      'p_internal_reason': internalReason,
      'p_restriction_ends_at': endsAt?.toUtc().toIso8601String(),
      'p_expected_version': account.accessVersion,
    });
  }

  @override
  Future<void> decideReviewCase({
    required AdminModerationCase moderationCase,
    required String decision,
    required String reason,
  }) async {
    await _rpc('admin_decide_review_report', {
      'p_case_id': moderationCase.id,
      'p_decision': decision,
      'p_reason': reason,
      'p_expected_version': moderationCase.version,
    });
  }

  Future<Object?> _rpc(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      throw AppException(
        code: switch (error.code) {
          '40001' => AppErrorCode.conflict,
          '42501' => AppErrorCode.forbidden,
          '23514' => AppErrorCode.conflict,
          _ => AppErrorCode.unexpected,
        },
        userMessage: switch (error.code) {
          '40001' => 'This item changed. Refresh and try again.',
          '42501' => 'Administrator permission is required.',
          '23514' => 'The last active administrator cannot be restricted.',
          _ => 'The administrator action could not be completed.',
        },
        technicalMessage: error.message,
        cause: error,
      );
    }
  }

  DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
