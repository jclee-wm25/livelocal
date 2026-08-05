enum AppRole {
  tourist,
  influencer,
  admin;

  static AppRole fromDatabase(String? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.tourist,
    );
  }
}

enum AccountAccessStatus {
  active,
  restricted,
  banned,
  deletionPending,
  deleted;

  static AccountAccessStatus fromDatabase(String? value) {
    switch (value) {
      case 'restricted':
        return AccountAccessStatus.restricted;
      case 'banned':
        return AccountAccessStatus.banned;
      case 'deletion_pending':
        return AccountAccessStatus.deletionPending;
      case 'deleted':
        return AccountAccessStatus.deleted;
      default:
        return AccountAccessStatus.active;
    }
  }
}

class AccountIdentity {
  const AccountIdentity({
    required this.id,
    required this.email,
    required this.fullName,
    required AppRole role,
    required this.accessStatus,
    required this.emailVerified,
    this.avatarUrl,
    this.accessReason,
    this.accessEndsAt,
    this.deletionScheduledFor,
    this.accessDecisionId,
  }) : appRole = role;

  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final AppRole appRole;
  final AccountAccessStatus accessStatus;
  final bool emailVerified;
  final String? accessReason;
  final DateTime? accessEndsAt;
  final DateTime? deletionScheduledFor;
  final String? accessDecisionId;

  /// Compatibility property for presentation code that has not yet migrated
  /// from string roles. Remove after the feature migration is complete.
  String get role => appRole.name;

  bool get isSuspended =>
      accessStatus == AccountAccessStatus.restricted ||
      accessStatus == AccountAccessStatus.banned;

  AccountIdentity copyWith({
    String? fullName,
    String? avatarUrl,
    AppRole? role,
    AccountAccessStatus? accessStatus,
    bool? emailVerified,
    String? accessReason,
    DateTime? accessEndsAt,
    DateTime? deletionScheduledFor,
    String? accessDecisionId,
    bool clearAccessReason = false,
    bool clearAccessEndsAt = false,
    bool clearDeletionScheduledFor = false,
    bool clearAccessDecisionId = false,
  }) {
    return AccountIdentity(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? appRole,
      accessStatus: accessStatus ?? this.accessStatus,
      emailVerified: emailVerified ?? this.emailVerified,
      accessReason:
          clearAccessReason ? null : accessReason ?? this.accessReason,
      accessEndsAt:
          clearAccessEndsAt ? null : accessEndsAt ?? this.accessEndsAt,
      deletionScheduledFor: clearDeletionScheduledFor
          ? null
          : deletionScheduledFor ?? this.deletionScheduledFor,
      accessDecisionId: clearAccessDecisionId
          ? null
          : accessDecisionId ?? this.accessDecisionId,
    );
  }
}
