import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';

class AuthController with ChangeNotifier {
  final AuthService _service = AuthService();

  late final Future<void> _initializationFuture;

  ProfileModel? _currentUser;

  bool _isLoading = false;
  bool _isInitializing = true;

  String? _errorMessage;

  ProfileModel? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  bool get isInitializing => _isInitializing;

  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;

  AuthController() {
    _initializationFuture = _restoreSession();
  }

  Future<void> _restoreSession() async {
    _isInitializing = true;
    _errorMessage = null;

    try {
      _currentUser = await _service.restoreSession();
    } catch (error) {
      debugPrint(
        'AuthController: restoreSession failed: $error',
      );

      _currentUser = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(
    String email,
    String password,
  ) async {
    await _initializationFuture;

    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _service.login(
        email,
        password,
      );

      return true;
    } catch (error) {
      debugPrint(
        'AuthController: login failed: $error',
      );

      _errorMessage = _cleanErrorMessage(error);
      _currentUser = null;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    await _initializationFuture;

    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _service.register(
        email,
        password,
        fullName,
        role,
      );

      return true;
    } catch (error) {
      debugPrint(
        'AuthController: register failed: $error',
      );

      _errorMessage = _cleanErrorMessage(error);
      _currentUser = null;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    await _initializationFuture;

    if (_currentUser == null) {
      throw Exception(
        'You must be logged in to update your profile.',
      );
    }

    if (_isLoading) {
      return;
    }

    final String normalizedName = fullName.trim();

    if (normalizedName.isEmpty) {
      throw Exception('Full name cannot be empty.');
    }

    final String? normalizedAvatar = avatarUrl?.trim();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ProfileModel updatedProfile = ProfileModel(
        id: _currentUser!.id,
        email: _currentUser!.email,
        fullName: normalizedName,
        avatarUrl: normalizedAvatar == null || normalizedAvatar.isEmpty
            ? null
            : normalizedAvatar,
        role: _currentUser!.role,
        isSuspended: _currentUser!.isSuspended,
      );

      await _service.updateProfile(updatedProfile);

      _currentUser = updatedProfile;
    } catch (error) {
      debugPrint(
        'AuthController: updateProfile failed: $error',
      );

      _errorMessage = _cleanErrorMessage(error);

      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logout() async {
    await _initializationFuture;

    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.logout();

      _currentUser = null;

      return true;
    } catch (error) {
      debugPrint(
        'AuthController: logout failed: $error',
      );

      _errorMessage = _cleanErrorMessage(error);

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  // Local testing only.
  // Users cannot change their role in live Supabase mode.
  void setRole(String newRole) {
    if (_service.isLiveSupabase || _currentUser == null) {
      return;
    }

    const Set<String> allowedRoles = {
      'tourist',
      'influencer',
      'admin',
    };

    final String normalizedRole = newRole.trim().toLowerCase();

    if (!allowedRoles.contains(normalizedRole)) {
      return;
    }

    _currentUser = ProfileModel(
      id: _currentUser!.id,
      email: _currentUser!.email,
      fullName: _currentUser!.fullName,
      avatarUrl: _currentUser!.avatarUrl,
      role: normalizedRole,
      isSuspended: _currentUser!.isSuspended,
    );

    unawaited(
      _service.saveSession(_currentUser!),
    );

    notifyListeners();
  }

  String _cleanErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
