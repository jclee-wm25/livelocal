import '../../../core/errors/app_exception.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/admin_repository.dart';

class DemoAdminRepository implements AdminRepository {
  DemoAdminRepository(this._authRepository)
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
  final List<AdminAccountSummary> _accounts;

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
  }

  @override
  Future<void> decideReviewCase({
    required AdminModerationCase moderationCase,
    required String decision,
    required String reason,
  }) async {
    _requireAdmin();
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
