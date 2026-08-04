import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPendingSpots() async {
    final response = await _client.from('spots').select().eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateSpotStatus(String spotId, String status, {String? rejectionReason}) async {
    await _client.from('spots').update({
      'status': status,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    }).eq('id', spotId);
  }

  Future<List<Map<String, dynamic>>> getReports() async {
    final response = await _client.from('reports').select().eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _client.from('reports').update({'status': status}).eq('id', reportId);
  }

  Future<void> submitReport(String reporterId, String targetId, String targetType, String reason) async {
    await _client.from('reports').insert({
      'reporter_id': reporterId,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      'status': 'pending',
    });
  }

  Future<void> blockUser(String blockerId, String blockedId) async {
    await _client.from('blocked_users').insert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }
}
