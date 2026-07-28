import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';

class AdminController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  List<ProfileModel> _allUsers = [];
  bool _isLoading = false;

  List<ProfileModel> get allUsers => _allUsers;
  bool get isLoading => _isLoading;

  AdminController() {
    loadUsers();
  }

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();
    _allUsers = await _db.fetchProfiles();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleUserSuspension(String userId) async {
    final idx = _allUsers.indexWhere((u) => u.id == userId);
    if (idx >= 0) {
      final target = _allUsers[idx];
      final updated = ProfileModel(
        id: target.id,
        email: target.email,
        fullName: target.fullName,
        avatarUrl: target.avatarUrl,
        role: target.role,
        isSuspended: !target.isSuspended,
      );
      await _db.saveProfile(updated);
      await loadUsers();
    }
  }

  // Dashboard Stats
  int get totalUsers => _allUsers.length;
  int get totalTourists => _allUsers.where((u) => u.role == 'tourist').length;
  int get totalInfluencers => _allUsers.where((u) => u.role == 'influencer').length;
  int get suspendedUsersCount => _allUsers.where((u) => u.isSuspended).length;
}
