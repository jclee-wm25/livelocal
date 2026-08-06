import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/account_repository.dart';

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository({
    required SupabaseClient client,
    required SupabaseAuthRepository authRepository,
  })  : _client = client,
        _authRepository = authRepository;

  static const int maxAvatarBytes = 5 * 1024 * 1024;
  static const Set<String> allowedAvatarTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final SupabaseClient _client;
  final SupabaseAuthRepository _authRepository;

  @override
  Future<AccountIdentity> updateProfile({required String displayName}) async {
    await _rpc('update_my_profile', {'new_display_name': displayName.trim()});
    return _authRepository.refreshAccount();
  }

  @override
  Future<AccountIdentity> uploadAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!allowedAvatarTypes.contains(mimeType) ||
        bytes.isEmpty ||
        !_matchesDeclaredImageType(bytes, mimeType)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a JPEG, PNG or WebP image.',
      );
    }
    if (bytes.length > maxAvatarBytes) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'The profile image must be 5 MB or smaller.',
      );
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to update your profile image.',
      );
    }
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/avatar.$extension';
    try {
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      await _rpc('update_my_avatar', {'new_avatar_path': path});
      final account = await _authRepository.refreshAccount();
      return account.copyWith(
        avatarUrl: _authRepository.publicAvatarUrl(path),
      );
    } on StorageException catch (error) {
      throw AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'The profile image could not be uploaded. Try again.',
        technicalMessage: error.message,
        cause: error,
      );
    }
  }

  @override
  Future<AccountIdentity> requestDeletion({required String password}) async {
    await _reauthenticate(password);
    await _rpc('request_account_deletion');
    return _authRepository.refreshAccount();
  }

  @override
  Future<AccountIdentity> cancelDeletion({required String password}) async {
    await _reauthenticate(password);
    await _rpc('cancel_account_deletion');
    return _authRepository.refreshAccount();
  }

  @override
  Future<AppealCase> submitAppeal({
    required String decisionId,
    required String reason,
    String? explanation,
  }) async {
    final response = await _rpc('submit_account_appeal', {
      'p_related_decision_id': decisionId,
      'p_appeal_reason': reason,
      'p_appeal_explanation': explanation,
    });
    if (response is! Map<String, dynamic>) {
      throw const AppException(
        code: AppErrorCode.unexpected,
        userMessage: 'Your appeal could not be recorded. Try again.',
      );
    }
    return AppealCase(
      id: response['id'] as String,
      relatedDecisionId: response['related_decision_id'] as String,
      status: _appealStatus(response['status'] as String?),
      createdAt: DateTime.parse(response['created_at'] as String).toLocal(),
      version: (response['version'] as num?)?.toInt() ?? 1,
      outcomeReason: response['outcome_reason'] as String?,
    );
  }

  @override
  Future<AppealCase?> fetchLatestAppeal({required String decisionId}) async {
    try {
      final rows = await _client
          .from('account_appeals')
          .select()
          .eq('related_decision_id', decisionId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = Map<String, dynamic>.from(rows.first);
      return AppealCase(
        id: row['id'] as String,
        relatedDecisionId: row['related_decision_id'] as String,
        status: _appealStatus(row['status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        version: (row['version'] as num).toInt(),
        outcomeReason: row['outcome_reason'] as String?,
      );
    } on PostgrestException catch (error) {
      throw AppException(
        code: AppErrorCode.unexpected,
        userMessage: 'Your appeal status could not be loaded.',
        technicalMessage: error.message,
        cause: error,
      );
    }
  }

  Future<void> _reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in again to continue.',
      );
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AppException(
        code: AppErrorCode.authentication,
        userMessage: 'The password is incorrect.',
        technicalMessage: error.message,
        cause: error,
      );
    }
  }

  Future<Object?> _rpc(
    String function, [
    Map<String, dynamic>? parameters,
  ]) async {
    try {
      return await _client.rpc(function, params: parameters);
    } on PostgrestException catch (error) {
      throw AppException(
        code: error.code == '23505'
            ? AppErrorCode.conflict
            : AppErrorCode.unexpected,
        userMessage: error.code == '23505'
            ? 'An active request already exists.'
            : 'The account change could not be completed. Try again.',
        technicalMessage: error.message,
        cause: error,
      );
    }
  }

  AppealStatus _appealStatus(String? value) {
    return switch (value) {
      'under_review' => AppealStatus.underReview,
      'upheld' => AppealStatus.upheld,
      'dismissed' => AppealStatus.dismissed,
      'withdrawn' => AppealStatus.withdrawn,
      _ => AppealStatus.submitted,
    };
  }

  bool _matchesDeclaredImageType(Uint8List bytes, String mimeType) {
    if (mimeType == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mimeType == 'image/png') {
      const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }
    if (mimeType == 'image/webp') {
      return bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }
}
