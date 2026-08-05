import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/moderation_repository.dart';

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get supportsUserBlocking => true;

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

  @override
  Future<UserBlockReceipt> blockContentAuthor({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final response = await _client.rpc('block_content_author', params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
      });
      final row = Map<String, dynamic>.from(response as Map);
      return UserBlockReceipt(
        userId: row['blocked_user_id'] as String,
        displayName: row['display_name'] as String,
      );
    } on PostgrestException catch (error) {
      throw _blockError(error, 'The account could not be blocked.');
    }
  }

  @override
  Future<List<BlockedUser>> listBlockedUsers() async {
    try {
      final response = await _client.rpc('list_my_blocked_users');
      return (response as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return BlockedUser(
          userId: row['user_id'] as String,
          displayName: row['display_name'] as String,
          blockedAt: DateTime.parse(row['blocked_at'] as String).toLocal(),
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw _blockError(error, 'Blocked accounts could not be loaded.');
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    try {
      await _client.rpc('unblock_user', params: {
        'p_blocked_user_id': userId,
      });
    } on PostgrestException catch (error) {
      throw _blockError(error, 'The account could not be unblocked.');
    }
  }

  AppException _blockError(PostgrestException error, String fallback) {
    return AppException(
      code: switch (error.code) {
        '22023' => AppErrorCode.validation,
        '42501' => AppErrorCode.forbidden,
        'P0002' => AppErrorCode.unavailable,
        _ => AppErrorCode.unexpected,
      },
      userMessage: switch (error.code) {
        '22023' => 'You cannot block the account for this content.',
        'P0002' => 'This content is no longer linked to an account.',
        _ => fallback,
      },
      technicalMessage: error.message,
      cause: error,
    );
  }
}
