import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/admin_service.dart';

class AdminController with ChangeNotifier {
  final AdminService _service = AdminService();

  List<ProfileModel> _allUsers = [];
  bool _isLoading = false;

  List<ProfileModel> get allUsers => _allUsers;
  bool get isLoading => _isLoading;

  Future<void> loadUsers(String currentUserRole) async {
    _isLoading = true;
    notifyListeners();
    try {
      _allUsers = await _service.fetchUsers(currentUserRole);
    } catch (e) {
      debugPrint('AdminController: loadUsers failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUserSuspension(
      String userId, String currentUserRole) async {
    try {
      await _service.toggleUserSuspension(userId, currentUserRole);
    } catch (e) {
      debugPrint('AdminController: toggleUserSuspension failed: $e');
      rethrow;
    }
    await loadUsers(currentUserRole);
  }

  // Dashboard Stats
  int get totalUsers => _allUsers.length;
  int get totalTourists => _allUsers.where((u) => u.role == 'tourist').length;
  int get totalInfluencers =>
      _allUsers.where((u) => u.role == 'influencer').length;
  int get suspendedUsersCount => _allUsers.where((u) => u.isSuspended).length;

  List<Map<String, dynamic>> _pendingReports = [];
  List<Map<String, dynamic>> get pendingReports => _pendingReports;

  Future<void> loadPendingReports(String currentUserRole) async {
    try {
      _pendingReports = await _service.fetchPendingReports(currentUserRole);
      notifyListeners();
    } catch (e) {
      debugPrint('AdminController: loadPendingReports failed: $e');
    }
  }

  Future<void> resolveReport(
      String reportId, String action, String currentUserRole,
      {String? reviewIdToDelete}) async {
    try {
      await _service.resolveReport(reportId, action, currentUserRole,
          reviewIdToDelete: reviewIdToDelete);
      await loadPendingReports(currentUserRole);
    } catch (e) {
      debugPrint('AdminController: resolveReport failed: $e');
      rethrow;
    }
  }

  Future<void> dismissReport(String reportId, String currentUserRole) async {
    try {
      await _service.dismissReport(reportId, currentUserRole);
      await loadPendingReports(currentUserRole);
    } catch (e) {
      debugPrint('AdminController: dismissReport failed: $e');
      rethrow;
    }
  }
}
