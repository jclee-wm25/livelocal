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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ModerationReceipt? get lastReceipt => _lastReceipt;

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
}
