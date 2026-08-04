import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../repositories/supabase_repository.dart';

class AdminService {
  final SupabaseRepository _repo = SupabaseRepository();

  Future<List<ProfileModel>> fetchUsers(String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can view users.');
    }
    return _repo.fetchProfiles();
  }

  Future<void> toggleUserSuspension(String userId, String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can suspend users.');
    }
    final allUsers = await _repo.fetchProfiles();
    final idx = allUsers.indexWhere((u) => u.id == userId);
    if (idx < 0) return;
    final target = allUsers[idx];
    
    final updated = ProfileModel(
      id: target.id,
      email: target.email,
      fullName: target.fullName,
      avatarUrl: target.avatarUrl,
      role: target.role,
      isSuspended: !target.isSuspended,
    );
    await _repo.saveProfile(updated);

    if (updated.isSuspended && updated.role == 'influencer') {
      final allDiscounts = await _repo.fetchDiscountCodes();
      final influencerDiscounts = allDiscounts.where((d) => d.influencerId == userId && d.isActive);
      for (var discount in influencerDiscounts) {
        await _repo.updateDiscountCodeStatus(discount.id, false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingReports(String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can view reports.');
    }
    return _repo.fetchPendingReports();
  }

  Future<void> resolveReport(String reportId, String action, String currentUserRole, {String? reviewIdToDelete}) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can resolve reports.');
    }
    if (action == 'delete_review' && reviewIdToDelete != null) {
      await _repo.deleteReview(reviewIdToDelete);
    }
    await _repo.updateReportStatus(reportId, 'resolved');
  }

  Future<void> dismissReport(String reportId, String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can dismiss reports.');
    }
    await _repo.updateReportStatus(reportId, 'dismissed');
  }
}
