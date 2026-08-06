import 'dart:typed_data';

import '../../auth/domain/account_identity.dart';

enum AppealStatus { submitted, underReview, upheld, dismissed, withdrawn }

class AppealCase {
  const AppealCase({
    required this.id,
    required this.relatedDecisionId,
    required this.status,
    required this.createdAt,
    required this.version,
    this.outcomeReason,
  });

  final String id;
  final String relatedDecisionId;
  final AppealStatus status;
  final DateTime createdAt;
  final int version;
  final String? outcomeReason;
}

abstract interface class AccountRepository {
  Future<AccountIdentity> updateProfile({required String displayName});

  Future<AccountIdentity> uploadAvatar({
    required Uint8List bytes,
    required String mimeType,
  });

  Future<AccountIdentity> requestDeletion({required String password});

  Future<AccountIdentity> cancelDeletion({required String password});

  Future<AppealCase> submitAppeal({
    required String decisionId,
    required String reason,
    String? explanation,
  });

  Future<AppealCase?> fetchLatestAppeal({required String decisionId});
}
