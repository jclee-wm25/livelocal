import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/admin_repository.dart';

class AdminController with ChangeNotifier {
  AdminController({required AdminRepository repository})
      : _repository = repository;

  final AdminRepository _repository;
  List<AdminAccountSummary> _accounts = [];
  List<AdminModerationCase> _cases = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AdminAccountSummary> get accounts => List.unmodifiable(_accounts);
  List<AdminModerationCase> get moderationCases => List.unmodifiable(_cases);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUsers => _accounts.length;
  int get suspendedUsersCount =>
      _accounts.where((account) => account.accessStatus != 'active').length;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchAccounts(),
        _repository.fetchModerationCases(),
      ]);
      _accounts = results[0] as List<AdminAccountSummary>;
      _cases = results[1] as List<AdminModerationCase>;
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setAccountAccess({
    required AdminAccountSummary account,
    required String status,
    required String publicMessage,
    required String internalReason,
    DateTime? endsAt,
  }) async {
    return _run(() => _repository.setAccountAccess(
          account: account,
          status: status,
          publicMessage: publicMessage,
          internalReason: internalReason,
          endsAt: endsAt,
        ));
  }

  Future<bool> decideReviewCase({
    required AdminModerationCase moderationCase,
    required String decision,
    required String reason,
  }) async {
    return _run(() => _repository.decideReviewCase(
          moderationCase: moderationCase,
          decision: decision,
          reason: reason,
        ));
  }

  Future<bool> _run(Future<void> Function() operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      await loadDashboard();
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    return error is AppException
        ? error.userMessage
        : 'The administrator dashboard could not be loaded.';
  }
}
