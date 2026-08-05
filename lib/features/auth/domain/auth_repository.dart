import 'account_identity.dart';

enum PasswordResetDelivery { email, demo }

abstract interface class AuthRepository {
  Stream<void> get sessionChanges;

  Future<AccountIdentity?> restoreSession();

  Future<AccountIdentity> signIn({
    required String email,
    required String password,
  });

  Future<AccountIdentity> registerTourist({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> resendVerificationEmail(String email);

  Future<PasswordResetDelivery> requestPasswordReset(String email);

  Future<void> signOut();

  Future<AccountIdentity> refreshAccount();
}
