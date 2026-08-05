import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/moderation_repository.dart';

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ModerationReceipt> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  }) async {
    try {
      final response = await _client.rpc('report_content', params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': reason,
        'p_explanation': explanation,
        'p_hide_for_me': hideForReporter,
      });
      final row = Map<String, dynamic>.from(response as Map);
      return ModerationReceipt(
        id: row['id'] as String,
        status: row['status'] as String,
        version: (row['version'] as num).toInt(),
      );
    } on PostgrestException catch (error) {
      throw AppException(
        code: switch (error.code) {
          '23505' => AppErrorCode.conflict,
          '42501' => AppErrorCode.forbidden,
          'P0001' => AppErrorCode.unavailable,
          _ => AppErrorCode.unexpected,
        },
        userMessage: switch (error.code) {
          '23505' => 'You already have an active report for this content.',
          'P0001' => 'Too many reports were submitted. Try again later.',
          _ => 'The report could not be submitted.',
        },
        technicalMessage: error.message,
        cause: error,
      );
    }
  }
}
