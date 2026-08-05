import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/moderation_repository.dart';

class ModerationController with ChangeNotifier {
  ModerationController({required ModerationRepository repository})
      : _repository = repository;

  final ModerationRepository _repository;
  bool _isLoading = false;
  String? _errorMessage;
  ModerationReceipt? _lastReceipt;
  UserBlockReceipt? _lastBlock;
  List<BlockedUser> _blockedUsers = const [];

  bool get isLoading => _isLoading;
  bool get supportsUserBlocking => _repository.supportsUserBlocking;
  String? get errorMessage => _errorMessage;
  ModerationReceipt? get lastReceipt => _lastReceipt;
  UserBlockReceipt? get lastBlock => _lastBlock;
  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);

  Future<bool> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? explanation,
    bool hideForReporter = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _lastReceipt = await _repository.reportContent(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        explanation: explanation,
        hideForReporter: hideForReporter,
      );
      return true;
    } catch (error) {
      _errorMessage = error is AppException
          ? error.userMessage
          : 'The report could not be submitted.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> blockContentAuthor({
    required String targetType,
    required String targetId,
  }) async {
    if (!supportsUserBlocking) {
      _errorMessage = 'Account blocking is unavailable in the local demo.';
      notifyListeners();
      return false;
    }
    return _run(() async {
      _lastBlock = await _repository.blockContentAuthor(
        targetType: targetType,
        targetId: targetId,
      );
      await _loadBlockedUsers();
    });
  }

  Future<bool> loadBlockedUsers() async {
    if (!supportsUserBlocking) {
      _blockedUsers = const [];
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    return _run(_loadBlockedUsers);
  }

  Future<bool> unblockUser(String userId) {
    return _run(() async {
      await _repository.unblockUser(userId);
      await _loadBlockedUsers();
    });
  }

  Future<void> _loadBlockedUsers() async {
    _blockedUsers = await _repository.listBlockedUsers();
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
          : 'The account safety setting could not be updated.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
