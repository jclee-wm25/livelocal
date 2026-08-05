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

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _service.register(email, password, fullName);
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

  Future<void> updateProfile(
      {required String fullName, String? avatarUrl}) async {
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

  Future<void> logout() async {
    try {
      await _service.logout();
    } finally {
      _currentUser = null;
      notifyListeners();
    }
  }
}
