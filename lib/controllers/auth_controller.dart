import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';

class AuthController with ChangeNotifier {
  final AuthService _service = AuthService();

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
    // Note: In a real app, this should securely rehydrate the session from Supabase.
    // For now, it stays as is to not break local seed mode.
    try {
      // Just mock logging in as the first user if we are not connected to live Supabase
      // In live Supabase, we would check `Supabase.instance.client.auth.currentSession`
    } catch (e) {
      debugPrint('AuthController: failed to load default user: $e');
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

    try {
      _currentUser = await _service.login(email, password);
      return true;
    } catch (e) {
      debugPrint('AuthController: login failed: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String fullName, String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _service.register(email, password, fullName, role);
      return true;
    } catch (e) {
      debugPrint('AuthController: register failed: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String fullName, String? avatarUrl}) async {
    if (_currentUser == null) return;
    try {
      final updated = ProfileModel(
        id: _currentUser!.id,
        email: _currentUser!.email,
        fullName: fullName,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        role: _currentUser!.role,
        isSuspended: _currentUser!.isSuspended,
      );
      await _service.updateProfile(updated);
      _currentUser = updated;
    } catch (e) {
      debugPrint('AuthController: updateProfile failed: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
