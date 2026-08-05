import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/account_identity.dart';
import '../domain/auth_repository.dart';

enum AuthStatus {
  checking,
  guest,
  authenticated,
  verificationRequired,
  restricted,
  banned,
  deletionPending,
  failure,
}

class AuthController with ChangeNotifier {
  AuthController({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;
  StreamSubscription<void>? _sessionSubscription;

  AccountIdentity? _currentUser;
  AuthStatus _status = AuthStatus.checking;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingVerificationEmail;

  AccountIdentity? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pendingVerificationEmail =>
      _pendingVerificationEmail ?? _currentUser?.email;
  bool get isAuthenticated => _currentUser != null;
  bool get canWrite => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = _repository.sessionChanges.listen((_) {
      unawaited(_restoreSession(fromAuthEvent: true));
    });
    await _restoreSession();
  }

  Future<void> retrySessionRestore() => _restoreSession();

  Future<bool> login(String email, String password) async {
    return _runAccountOperation(
      () => _repository.signIn(email: email, password: password),
      verificationEmail: email,
    );
  }

  Future<bool> register(String email, String password, String fullName) async {
    return _runAccountOperation(
      () => _repository.registerTourist(
        email: email,
        password: password,
        displayName: fullName,
      ),
      verificationEmail: email,
    );
  }

  Future<bool> resendVerificationEmail() async {
    final email = pendingVerificationEmail;
    if (email == null || email.isEmpty) {
      _errorMessage = 'Enter your email address again.';
      notifyListeners();
      return false;
    }
    return _runVoidOperation(
      () => _repository.resendVerificationEmail(email),
    );
  }

  Future<PasswordResetDelivery?> requestPasswordReset(String email) async {
    _setLoading();
    try {
      final delivery = await _repository.requestPasswordReset(email);
      _errorMessage = null;
      return delivery;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAccount() async {
    try {
      final account = await _repository.refreshAccount();
      _setAccount(account);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _setLoading();
    try {
      await _repository.signOut();
      _currentUser = null;
      _pendingVerificationEmail = null;
      _status = AuthStatus.guest;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreSession({bool fromAuthEvent = false}) async {
    if (!fromAuthEvent) {
      _status = AuthStatus.checking;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final account = await _repository.restoreSession();
      if (account == null) {
        _currentUser = null;
        _status = AuthStatus.guest;
      } else {
        _setAccount(account);
      }
      _errorMessage = null;
    } catch (error) {
      _status = AuthStatus.failure;
      _errorMessage = _messageFor(error);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _runAccountOperation(
    Future<AccountIdentity> Function() operation, {
    required String verificationEmail,
  }) async {
    _setLoading();
    try {
      final account = await operation();
      _pendingVerificationEmail = verificationEmail.trim();
      _setAccount(account);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _runVoidOperation(Future<void> Function() operation) async {
    _setLoading();
    try {
      await operation();
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _setAccount(AccountIdentity account) {
    _currentUser = account;
    if (!account.emailVerified) {
      _status = AuthStatus.verificationRequired;
      return;
    }
    switch (account.accessStatus) {
      case AccountAccessStatus.active:
        _status = AuthStatus.authenticated;
        return;
      case AccountAccessStatus.restricted:
        _status = AuthStatus.restricted;
        return;
      case AccountAccessStatus.banned:
      case AccountAccessStatus.deleted:
        _status = AuthStatus.banned;
        return;
      case AccountAccessStatus.deletionPending:
        _status = AuthStatus.deletionPending;
        return;
    }
  }

  String _messageFor(Object error) {
    if (error is AppException) return error.userMessage;
    if (kDebugMode) {
      debugPrint('Auth operation failed: $error');
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }
}
