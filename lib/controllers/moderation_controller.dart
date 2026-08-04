import 'package:flutter/foundation.dart';
import '../repositories/supabase_repository.dart';

class ModerationController with ChangeNotifier {
  final SupabaseRepository _repo = SupabaseRepository();

  Future<void> submitReport({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
  }) async {
    try {
      await _repo.submitReport(reporterId, targetId, targetType, reason);
    } catch (e) {
      debugPrint('ModerationController: submitReport failed: \$e');
      rethrow;
    }
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _repo.blockUser(blockerId, blockedId);
    } catch (e) {
      debugPrint('ModerationController: blockUser failed: \$e');
      rethrow;
    }
  }
}
