class AdminAccountSummary {
  const AdminAccountSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.accessStatus,
    required this.accessVersion,
    required this.createdAt,
    this.accessMessage,
    this.accessEndsAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String accessStatus;
  final int accessVersion;
  final DateTime createdAt;
  final String? accessMessage;
  final DateTime? accessEndsAt;
}

class AdminModerationCase {
  const AdminModerationCase({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.version,
    required this.targetPreview,
    required this.createdAt,
    this.explanation,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String? explanation;
  final String status;
  final int version;
  final String targetPreview;
  final DateTime createdAt;
}

abstract interface class AdminRepository {
  Future<List<AdminAccountSummary>> fetchAccounts();
  Future<List<AdminModerationCase>> fetchModerationCases();

  Future<void> setAccountAccess({
    required AdminAccountSummary account,
    required String status,
    required String publicMessage,
    required String internalReason,
    DateTime? endsAt,
  });

  Future<void> decideReviewCase({
    required AdminModerationCase moderationCase,
    required String decision,
    required String reason,
  });
}
