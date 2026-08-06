import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/account_repository.dart';

class AccountController with ChangeNotifier {
  AccountController({
    required AccountRepository repository,
    required AuthController authController,
  })  : _repository = repository,
        _authController = authController;

  final AccountRepository _repository;
  final AuthController _authController;

  bool _isLoading = false;
  String? _errorMessage;
  AppealCase? _submittedAppeal;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppealCase? get submittedAppeal => _submittedAppeal;

  Future<void> loadAppeal(String decisionId) async {
    await _run(() async {
      _submittedAppeal =
          await _repository.fetchLatestAppeal(decisionId: decisionId);
    });
  }

  Future<bool> updateDisplayName(String displayName) async {
    return _run(() async {
      await _repository.updateProfile(displayName: displayName);
      await _authController.refreshAccount();
    });
  }

  Future<bool> uploadAvatar(Uint8List bytes, String mimeType) async {
    return _run(() async {
      await _repository.uploadAvatar(bytes: bytes, mimeType: mimeType);
      await _authController.refreshAccount();
    });
  }

  Future<bool> requestDeletion(String password) async {
    return _run(() async {
      await _repository.requestDeletion(password: password);
      await _authController.refreshAccount();
    });
  }

  Future<bool> cancelDeletion(String password) async {
    return _run(() async {
      await _repository.cancelDeletion(password: password);
      await _authController.refreshAccount();
    });
  }

  Future<bool> submitAppeal({
    required String decisionId,
    required String reason,
    String? explanation,
  }) async {
    return _run(() async {
      _submittedAppeal = await _repository.submitAppeal(
        decisionId: decisionId,
        reason: reason,
        explanation: explanation,
      );
    });
  }

  Future<bool> _run(Future<void> Function() operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      _errorMessage = error is AppException
          ? error.userMessage
          : 'The account change could not be completed. Try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
