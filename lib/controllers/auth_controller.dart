import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';

class AuthController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  ProfileModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthController() {
    _initDefaultUser();
  }

  void _initDefaultUser() async {
    final profiles = await _db.fetchProfiles();
    if (profiles.isNotEmpty) {
      _currentUser = profiles.first;
      notifyListeners();
    }
  }

  void setRole(String newRole) {
    if (_currentUser != null) {
      _currentUser = ProfileModel(
        id: _currentUser!.id,
        email: _currentUser!.email,
        fullName: _currentUser!.fullName,
        avatarUrl: _currentUser!.avatarUrl,
        role: newRole,
        isSuspended: _currentUser!.isSuspended,
      );
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300)); // Simulate async auth
    final profiles = await _db.fetchProfiles();
    final match = profiles.where((p) => p.email.toLowerCase() == email.toLowerCase()).toList();

    if (match.isNotEmpty) {
      if (match.first.isSuspended) {
        _errorMessage = 'Your account has been suspended by an administrator.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _currentUser = match.first;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      // Auto-register mock tourist user if new email entered
      final newProfile = ProfileModel(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: email.split('@').first,
        role: 'tourist',
      );
      await _db.saveProfile(newProfile);
      _currentUser = newProfile;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> register(String email, String password, String fullName, String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final newProfile = ProfileModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      fullName: fullName,
      role: role,
    );

    await _db.saveProfile(newProfile);
    _currentUser = newProfile;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({required String fullName, String? avatarUrl}) async {
    if (_currentUser == null) return;
    final updated = ProfileModel(
      id: _currentUser!.id,
      email: _currentUser!.email,
      fullName: fullName,
      avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      role: _currentUser!.role,
      isSuspended: _currentUser!.isSuspended,
    );
    await _db.saveProfile(updated);
    _currentUser = updated;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
