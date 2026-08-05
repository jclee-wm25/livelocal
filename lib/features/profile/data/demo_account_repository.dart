import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/account_repository.dart';

class DemoAccountRepository implements AccountRepository {
  DemoAccountRepository(this._authRepository);

  final DemoAuthRepository _authRepository;
  final List<AppealCase> _appeals = [];

  List<AppealCase> get appealsForDemo => List.unmodifiable(_appeals);

  AccountIdentity get _account {
    final account = _authRepository.currentAccountForDemo;
    if (account == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to manage your account.',
      );
    }
    return account;
  }

  @override
  Future<AccountIdentity> updateProfile({required String displayName}) async {
    final updated = _account.copyWith(fullName: displayName.trim());
    return _authRepository.replaceAccountForDemo(updated);
  }

  @override
  Future<AccountIdentity> uploadAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    throw const AppException(
      code: AppErrorCode.unavailable,
      userMessage:
          'Demo mode does not upload personal images. No file was stored.',
    );
  }

  @override
  Future<AccountIdentity> requestDeletion({required String password}) async {
    if (password != SeedDataService.demoPassword) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'The password is incorrect.',
      );
    }
    final scheduled = DateTime.now().toUtc().add(const Duration(days: 14));
    return _authRepository.replaceAccountForDemo(
      _account.copyWith(
        accessStatus: AccountAccessStatus.deletionPending,
        deletionScheduledFor: scheduled,
        accessReason:
            'This demo account is scheduled for deletion. No production data is affected.',
      ),
    );
  }

  @override
  Future<AccountIdentity> cancelDeletion({required String password}) async {
    if (password != SeedDataService.demoPassword) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'The password is incorrect.',
      );
    }
    return _authRepository.replaceAccountForDemo(
      _account.copyWith(
        accessStatus: AccountAccessStatus.active,
        clearDeletionScheduledFor: true,
        clearAccessReason: true,
      ),
    );
  }

  @override
  Future<AppealCase> submitAppeal({
    required String decisionId,
    required String reason,
    String? explanation,
  }) async {
    if (_appeals.any(
      (appeal) =>
          appeal.relatedDecisionId == decisionId &&
          (appeal.status == AppealStatus.submitted ||
              appeal.status == AppealStatus.underReview),
    )) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'An active appeal already exists for this decision.',
      );
    }
    final appeal = AppealCase(
      id: 'demo-appeal-${DateTime.now().microsecondsSinceEpoch}',
      relatedDecisionId: decisionId,
      status: AppealStatus.submitted,
      createdAt: DateTime.now().toUtc(),
      version: 1,
    );
    _appeals.add(appeal);
    return appeal;
  }

  @override
  Future<AppealCase?> fetchLatestAppeal({required String decisionId}) async {
    final matching = _appeals
        .where((appeal) => appeal.relatedDecisionId == decisionId)
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return matching.isEmpty ? null : matching.first;
  }

  AppealCase decideAppealForDemo({
    required String appealId,
    required AppealStatus decision,
    required String outcomeReason,
    required int expectedVersion,
  }) {
    final index = _appeals.indexWhere((appeal) => appeal.id == appealId);
    if (index < 0 || _appeals[index].version != expectedVersion) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'This appeal changed. Refresh and try again.',
      );
    }
    final existing = _appeals[index];
    final decided = AppealCase(
      id: existing.id,
      relatedDecisionId: existing.relatedDecisionId,
      status: decision,
      createdAt: existing.createdAt,
      version: existing.version + 1,
      outcomeReason: outcomeReason,
    );
    _appeals[index] = decided;
    return decided;
  }
}
