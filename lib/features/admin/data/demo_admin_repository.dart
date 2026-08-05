import '../../../core/errors/app_exception.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../../profile/data/demo_account_repository.dart';
import '../../profile/domain/account_repository.dart';
import '../domain/admin_repository.dart';

class DemoAdminRepository implements AdminRepository {
  DemoAdminRepository(this._authRepository, [this._accountRepository])
      : _accounts = SeedDataService.getInitialProfiles()
            .map(
              (profile) => AdminAccountSummary(
                id: profile.id,
                email: profile.email,
                displayName: profile.fullName,
                role: profile.role,
                accessStatus: profile.isSuspended ? 'restricted' : 'active',
                accessVersion: 1,
                createdAt: DateTime(2025),
              ),
            )
            .toList();

  final DemoAuthRepository _authRepository;
  final DemoAccountRepository? _accountRepository;
  final List<AdminAccountSummary> _accounts;
  final List<AdminAuditEvent> _auditEvents = [];

  @override
  Future<List<AdminAccountSummary>> fetchAccounts() async {
    _requireAdmin();
    return List.unmodifiable(_accounts);
  }

  @override
  Future<List<AdminModerationCase>> fetchModerationCases() async {
    _requireAdmin();
    return const [];
  }

  @override
  Future<AdminStatistics> fetchStatistics() async {
    _requireAdmin();
    return AdminStatistics(
      accountsTotal: _accounts.length,
      accountsRestricted:
          _accounts.where((item) => item.accessStatus != 'active').length,
      spotsPublished: SeedDataService.getInitialSpots().length,
      restaurantsPublished: SeedDataService.getInitialRestaurants().length,
      guidesPublished: SeedDataService.getInitialGuides().length,
      reviewsPublished: SeedDataService.getInitialReviews().length,
      moderationPending: 0,
      creatorApplicationsPending: 0,
    );
  }

  @override
  Future<List<AdminAuditEvent>> fetchAuditEvents() async {
    _requireAdmin();
    return List.unmodifiable(_auditEvents.reversed);
  }

  @override
  Future<List<AdminAppealCase>> fetchAppeals() async {
    _requireAdmin();
    return (_accountRepository?.appealsForDemo ?? const <AppealCase>[])
        .where(
          (appeal) =>
              appeal.status == AppealStatus.submitted ||
              appeal.status == AppealStatus.underReview,
        )
        .map(
          (appeal) => AdminAppealCase(
            id: appeal.id,
            userId: 'usr-tourist-1',
            displayName: 'Demo tourist',
            email: 'tourist@livelocal.my',
            relatedDecisionId: appeal.relatedDecisionId,
            accessStatus: 'restricted',
            reason: 'Demo appeal',
            status: appeal.status.name,
            version: appeal.version,
            createdAt: appeal.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> setAccountAccess({
    required AdminAccountSummary account,
    required String status,
    required String publicMessage,
    required String internalReason,
    DateTime? endsAt,
  }) async {
    final actor = _requireAdmin();
    if (actor.id == account.id) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Administrators cannot change their own access.',
      );
    }
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index < 0 || _accounts[index].accessVersion != account.accessVersion) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'This account changed. Refresh and try again.',
      );
    }
    _accounts[index] = AdminAccountSummary(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      role: account.role,
      accessStatus: status,
      accessVersion: account.accessVersion + 1,
      accessMessage: status == 'active' ? null : publicMessage,
      accessEndsAt: status == 'restricted' ? endsAt : null,
      createdAt: account.createdAt,
    );
    _auditEvents.add(
      AdminAuditEvent(
        id: 'demo-audit-${DateTime.now().microsecondsSinceEpoch}',
        action: 'admin.account_access_changed',
        targetType: 'account',
        targetId: account.id,
        reason: internalReason,
        actorName: actor.fullName,
        occurredAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> decideModerationCase({
    required AdminModerationCase moderationCase,
    required String decision,
    required String reason,
  }) async {
    _requireAdmin();
  }

  @override
  Future<void> decideAppeal({
    required AdminAppealCase appeal,
    required String decision,
    required String reason,
  }) async {
    final actor = _requireAdmin();
    final accountRepository = _accountRepository;
    if (accountRepository == null) {
      throw const AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'No demo appeal store is configured.',
      );
    }
    accountRepository.decideAppealForDemo(
      appealId: appeal.id,
      decision:
          decision == 'upheld' ? AppealStatus.upheld : AppealStatus.dismissed,
      outcomeReason: reason,
      expectedVersion: appeal.version,
    );
    _auditEvents.add(
      AdminAuditEvent(
        id: 'demo-audit-${DateTime.now().microsecondsSinceEpoch}',
        action: 'admin.account_appeal_$decision',
        targetType: 'account_appeal',
        targetId: appeal.id,
        reason: reason,
        actorName: actor.fullName,
        occurredAt: DateTime.now(),
      ),
    );
  }

  AccountIdentity _requireAdmin() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.admin ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Administrator permission is required.',
      );
    }
    return account!;
  }
}
