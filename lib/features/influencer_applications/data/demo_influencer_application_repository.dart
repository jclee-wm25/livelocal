import '../../../core/errors/app_exception.dart';
import '../../../core/validation/social_url_validator.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/influencer_application_repository.dart';

class DemoInfluencerApplicationRepository
    implements InfluencerApplicationRepository {
  DemoInfluencerApplicationRepository(this._authRepository);

  final DemoAuthRepository _authRepository;
  final List<InfluencerApplication> _applications = [];

  @override
  Future<InfluencerApplication?> fetchMine() async {
    final account = _authRepository.currentAccountForDemo;
    if (account == null) return null;
    final mine = _applications.where((item) => item.userId == account.id);
    return mine.isEmpty ? null : mine.last;
  }

  @override
  Future<List<InfluencerApplication>> fetchPendingForAdmin() async {
    _requireAdmin();
    return _applications
        .where((item) => ['submitted', 'under_review'].contains(item.status))
        .toList();
  }

  @override
  Future<InfluencerApplication> saveDraft({
    InfluencerApplication? existing,
    required InfluencerApplicationDraft draft,
  }) async {
    final account = _requireTourist();
    final saved = InfluencerApplication(
      id: existing?.id ??
          'demo-application-${DateTime.now().microsecondsSinceEpoch}',
      userId: account.id,
      status: 'draft',
      version: (existing?.version ?? 0) + 1,
      displayName: draft.displayName,
      socialPlatform: draft.socialPlatform,
      profileUrl: draft.profileUrl,
      followerCount: draft.followerCount,
      contentCategory: draft.contentCategory,
      applicationMessage: draft.applicationMessage,
      rulesAgreed: draft.rulesAgreed,
    );
    _applications.removeWhere((item) => item.id == saved.id);
    _applications.add(saved);
    return saved;
  }

  @override
  Future<InfluencerApplication> submit(
    InfluencerApplication application,
  ) async {
    _requireTourist();
    if ((application.displayName?.trim().length ?? 0) < 2 ||
        !{'tiktok', 'instagram'}.contains(application.socialPlatform) ||
        !SocialUrlValidator.isSupported(
          application.profileUrl ?? '',
          platform: application.socialPlatform,
        ) ||
        application.followerCount == null ||
        (application.contentCategory?.trim().length ?? 0) < 2 ||
        (application.applicationMessage?.trim().length ?? 0) < 20 ||
        !application.rulesAgreed) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Complete every required application field.',
      );
    }
    final submitted = _copy(
      application,
      status: 'submitted',
      version: application.version + 1,
    );
    _replace(submitted);
    return submitted;
  }

  @override
  Future<void> withdraw(InfluencerApplication application) async {
    _requireTourist();
    _replace(
      _copy(
        application,
        status: 'withdrawn',
        version: application.version + 1,
      ),
    );
  }

  @override
  Future<void> decide({
    required InfluencerApplication application,
    required String decision,
    required String reason,
  }) async {
    _requireAdmin();
    if (!{'approved', 'rejected', 'needs_information'}.contains(decision) ||
        reason.trim().length < 3) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a valid decision and record a reason.',
      );
    }
    _replace(
      _copy(
        application,
        status: decision,
        version: application.version + 1,
      ),
    );
    if (decision == 'approved') {
      _authRepository.grantRoleForDemo(
        application.userId,
        AppRole.influencer,
      );
    }
  }

  AccountIdentity _requireTourist() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.tourist ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'An active tourist account is required.',
      );
    }
    return account!;
  }

  void _requireAdmin() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.admin ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Administrator permission is required.',
      );
    }
  }

  void _replace(InfluencerApplication application) {
    final index = _applications.indexWhere((item) => item.id == application.id);
    if (index < 0 || _applications[index].version != application.version - 1) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'The application changed. Refresh and try again.',
      );
    }
    _applications[index] = application;
  }

  InfluencerApplication _copy(
    InfluencerApplication application, {
    required String status,
    required int version,
  }) {
    return InfluencerApplication(
      id: application.id,
      userId: application.userId,
      status: status,
      version: version,
      displayName: application.displayName,
      socialPlatform: application.socialPlatform,
      profileUrl: application.profileUrl,
      followerCount: application.followerCount,
      contentCategory: application.contentCategory,
      applicationMessage: application.applicationMessage,
      rulesAgreed: application.rulesAgreed,
    );
  }
}
