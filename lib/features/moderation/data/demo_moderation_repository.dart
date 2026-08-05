import '../../../core/errors/app_exception.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/moderation_repository.dart';

class DemoModerationRepository implements ModerationRepository {
  DemoModerationRepository(this._authRepository);

  final DemoAuthRepository _authRepository;
  final Set<String> _activeReports = {};

  @override
  bool get supportsUserBlocking => false;

  @override
  Future<ModerationReceipt> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  }) async {
    final account = _authRepository.currentAccountForDemo;
    if (account == null || account.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in with an active account to report content.',
      );
    }
    if (!{'review', 'spot', 'restaurant', 'guide'}.contains(targetType) ||
        (reason == 'broken_link' && targetType != 'restaurant')) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'This report type is not supported.',
      );
    }
    final key = '${account.id}:$targetType:$targetId';
    if (!_activeReports.add(key)) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'You already have an active report for this content.',
      );
    }
    return ModerationReceipt(
      id: 'demo-moderation-${DateTime.now().microsecondsSinceEpoch}',
      status: 'pending',
      version: 1,
    );
  }

  @override
  Future<UserBlockReceipt> blockContentAuthor({
    required String targetType,
    required String targetId,
  }) {
    throw const AppException(
      code: AppErrorCode.unavailable,
      userMessage: 'Account blocking is unavailable in the local demo.',
    );
  }

  @override
  Future<List<BlockedUser>> listBlockedUsers() async => const [];

  @override
  Future<void> unblockUser(String userId) {
    throw const AppException(
      code: AppErrorCode.unavailable,
      userMessage: 'Account blocking is unavailable in the local demo.',
    );
  }
}
