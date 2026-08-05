import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../models/profile_model.dart';
import '../../../services/seed_data_service.dart';
import '../domain/account_identity.dart';
import '../domain/auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({List<ProfileModel>? initialProfiles})
      : _profiles = List<ProfileModel>.of(
          initialProfiles ?? SeedDataService.getInitialProfiles(),
        );

  final List<ProfileModel> _profiles;
  final StreamController<void> _sessionController =
      StreamController<void>.broadcast();
  final Map<String, AppRole> _roleOverrides = {};
  AccountIdentity? _currentAccount;

  AccountIdentity? get currentAccountForDemo => _currentAccount;

  @override
  Stream<void> get sessionChanges => _sessionController.stream;

  @override
  Future<AccountIdentity?> restoreSession() async => _currentAccount;

  @override
  Future<AccountIdentity> signIn({
    required String email,
    required String password,
  }) async {
    if (password != SeedDataService.demoPassword) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Invalid email or password.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final matches = _profiles
        .where((profile) => profile.email.toLowerCase() == normalizedEmail)
        .toList();
    if (matches.isEmpty) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Invalid email or password.',
      );
    }

    _currentAccount = _fromProfile(matches.single);
    _sessionController.add(null);
    return _currentAccount!;
  }

  @override
  Future<AccountIdentity> registerTourist({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (password != SeedDataService.demoPassword) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage:
            'Demo accounts must use the password shown on the demo sign-in screen.',
      );
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (_profiles.any(
      (profile) => profile.email.toLowerCase() == normalizedEmail,
    )) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'An account with this email already exists.',
      );
    }

    final profile = ProfileModel(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      email: normalizedEmail,
      fullName: displayName.trim(),
      role: AppRole.tourist.name,
    );
    _profiles.add(profile);
    _currentAccount = _fromProfile(profile);
    _sessionController.add(null);
    return _currentAccount!;
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    throw const AppException(
      code: AppErrorCode.unavailable,
      userMessage: 'Demo accounts are already verified. No email was sent.',
    );
  }

  @override
  Future<PasswordResetDelivery> requestPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Enter your email address.',
      );
    }
    return PasswordResetDelivery.demo;
  }

  @override
  Future<void> signOut() async {
    _currentAccount = null;
    _sessionController.add(null);
  }

  @override
  Future<AccountIdentity> refreshAccount() async {
    final current = _currentAccount;
    if (current == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to continue.',
      );
    }
    return current;
  }

  AccountIdentity _fromProfile(ProfileModel profile) {
    return AccountIdentity(
      id: profile.id,
      email: profile.email,
      fullName: profile.fullName,
      avatarUrl: profile.avatarUrl,
      role: _roleOverrides[profile.id] ?? AppRole.fromDatabase(profile.role),
      accessStatus: profile.isSuspended
          ? AccountAccessStatus.restricted
          : AccountAccessStatus.active,
      emailVerified: true,
      accessReason: profile.isSuspended
          ? 'This demo account is temporarily restricted.'
          : null,
    );
  }

  AccountIdentity replaceAccountForDemo(AccountIdentity account) {
    _currentAccount = account;
    _sessionController.add(null);
    return account;
  }

  /// Demo-only server adapter behavior. Production role grants occur only in
  /// the audited `admin_decide_influencer_application` database function.
  void grantRoleForDemo(String userId, AppRole role) {
    _roleOverrides[userId] = role;
    if (_currentAccount?.id == userId) {
      _currentAccount = _currentAccount!.copyWith(role: role);
      _sessionController.add(null);
    }
  }
}
