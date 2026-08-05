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

class AdminStatistics {
  const AdminStatistics({
    required this.accountsTotal,
    required this.accountsRestricted,
    required this.spotsPublished,
    required this.restaurantsPublished,
    required this.guidesPublished,
    required this.reviewsPublished,
    required this.moderationPending,
    required this.creatorApplicationsPending,
  });

  final int accountsTotal;
  final int accountsRestricted;
  final int spotsPublished;
  final int restaurantsPublished;
  final int guidesPublished;
  final int reviewsPublished;
  final int moderationPending;
  final int creatorApplicationsPending;
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.action,
    required this.targetType,
    required this.actorName,
    required this.occurredAt,
    this.targetId,
    this.reason,
  });

  final String id;
  final String action;
  final String targetType;
  final String? targetId;
  final String? reason;
  final String actorName;
  final DateTime occurredAt;
}

abstract interface class AdminRepository {
  Future<List<AdminAccountSummary>> fetchAccounts();
  Future<List<AdminModerationCase>> fetchModerationCases();
  Future<AdminStatistics> fetchStatistics();
  Future<List<AdminAuditEvent>> fetchAuditEvents();

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
