import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../repositories/supabase_repository.dart';

class AuthService {
  final SupabaseRepository _repo = SupabaseRepository();

  static const String _sessionKey = 'livelocal_auth_session';

  // Only used in local/demo mode.
  // Seed accounts use "password" as the demo password.
  static final Map<String, String> _localPasswords = {};

  bool get isLiveSupabase => _repo.isLiveSupabase;

  bool _isValidEmail(String email) {
    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    return emailPattern.hasMatch(email);
  }

  Future<void> saveSession(ProfileModel profile) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _sessionKey,
      jsonEncode(profile.toMap()),
    );
  }

  Future<ProfileModel?> restoreSession() async {
    try {
      if (_repo.isLiveSupabase) {
        final User? authUser = Supabase.instance.client.auth.currentUser;

        if (authUser == null) {
          await _clearStoredSession();
          return null;
        }

        final List<ProfileModel> profiles = await _repo.fetchProfiles();

        ProfileModel? matchingProfile;

        for (final ProfileModel profile in profiles) {
          final bool sameId = profile.id == authUser.id;

          final bool sameEmail = authUser.email != null &&
              profile.email.trim().toLowerCase() ==
                  authUser.email!.trim().toLowerCase();

          if (sameId || sameEmail) {
            matchingProfile = profile;
            break;
          }
        }

        if (matchingProfile == null) {
          await logout();
          return null;
        }

        if (matchingProfile.isSuspended) {
          await logout();
          return null;
        }

        await saveSession(matchingProfile);
        return matchingProfile;
      }

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? storedSession = preferences.getString(_sessionKey);

      if (storedSession == null || storedSession.isEmpty) {
        return null;
      }

      final Object? decodedSession = jsonDecode(storedSession);

      if (decodedSession is! Map) {
        await _clearStoredSession();
        return null;
      }

      final Map<String, dynamic> sessionMap =
          Map<String, dynamic>.from(decodedSession);

      final ProfileModel profile = ProfileModel.fromMap(sessionMap);

      if (profile.id.isEmpty || profile.email.isEmpty) {
        await _clearStoredSession();
        return null;
      }

      if (profile.isSuspended) {
        await _clearStoredSession();
        return null;
      }

      return profile;
    } catch (_) {
      await _clearStoredSession();
      return null;
    }
  }

  Future<ProfileModel> login(
    String email,
    String password,
  ) async {
    final String normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw Exception(
        'Email and password cannot be empty.',
      );
    }

    if (!_isValidEmail(normalizedEmail)) {
      throw Exception(
        'Please enter a valid email address.',
      );
    }

    if (_repo.isLiveSupabase) {
      final AuthResponse? response = await _repo.signIn(
        normalizedEmail,
        password,
      );

      if (response == null || response.user == null) {
        throw Exception('Invalid email or password.');
      }

      final List<ProfileModel> profiles = await _repo.fetchProfiles();

      final ProfileModel userProfile = profiles.firstWhere(
        (ProfileModel profile) =>
            profile.email.trim().toLowerCase() == normalizedEmail,
        orElse: () {
          throw Exception(
            'Profile not found for this account.',
          );
        },
      );

      if (userProfile.isSuspended) {
        await Supabase.instance.client.auth.signOut();

        throw Exception(
          'Your account has been suspended by an administrator.',
        );
      }

      await saveSession(userProfile);

      return userProfile;
    }

    // Local fallback mode.
    final List<ProfileModel> profiles = await _repo.fetchProfiles();

    final List<ProfileModel> matchingProfiles = profiles
        .where(
          (ProfileModel profile) =>
              profile.email.trim().toLowerCase() == normalizedEmail,
        )
        .toList();

    if (matchingProfiles.isEmpty) {
      throw Exception('Invalid email or password.');
    }

    final ProfileModel profile = matchingProfiles.first;

    final String? savedPassword = _localPasswords[normalizedEmail];

    // New local accounts use their entered password.
    // Seed accounts use "password".
    final bool passwordIsValid = savedPassword != null
        ? savedPassword == password
        : password == 'password';

    if (!passwordIsValid) {
      throw Exception('Invalid email or password.');
    }

    if (profile.isSuspended) {
      throw Exception(
        'Your account has been suspended by an administrator.',
      );
    }

    await saveSession(profile);

    return profile;
  }

  Future<ProfileModel> register(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    final String normalizedEmail = email.trim().toLowerCase();

    final String normalizedName = fullName.trim();

    final String normalizedRole = role.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty || normalizedName.isEmpty) {
      throw Exception(
        'All registration fields are required.',
      );
    }

    if (!_isValidEmail(normalizedEmail)) {
      throw Exception(
        'Please enter a valid email address.',
      );
    }

    if (password.length < 6) {
      throw Exception(
        'Password must contain at least 6 characters.',
      );
    }

    const Set<String> allowedRoles = {
      'tourist',
      'influencer',
    };

    if (!allowedRoles.contains(normalizedRole)) {
      throw Exception('Invalid user role selected.');
    }

    final List<ProfileModel> existingProfiles = await _repo.fetchProfiles();

    final bool emailAlreadyExists = existingProfiles.any(
      (ProfileModel profile) =>
          profile.email.trim().toLowerCase() == normalizedEmail,
    );

    if (emailAlreadyExists) {
      throw Exception(
        'An account with this email already exists.',
      );
    }

    if (_repo.isLiveSupabase) {
      final AuthResponse? response = await _repo.signUp(
        normalizedEmail,
        password,
      );

      if (response == null || response.user == null) {
        throw Exception(
          'Registration failed. Please try again.',
        );
      }

      final ProfileModel newProfile = ProfileModel(
        id: response.user!.id,
        email: normalizedEmail,
        fullName: normalizedName,
        role: normalizedRole,
      );

      await _repo.saveProfile(newProfile);
      await saveSession(newProfile);

      return newProfile;
    }

    final ProfileModel newProfile = ProfileModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: normalizedEmail,
      fullName: normalizedName,
      role: normalizedRole,
    );

    await _repo.saveProfile(newProfile);

    _localPasswords[normalizedEmail] = password;

    await saveSession(newProfile);

    return newProfile;
  }

  Future<void> updateProfile(
    ProfileModel updatedProfile,
  ) async {
    await _repo.saveProfile(updatedProfile);
    await saveSession(updatedProfile);
  }

  Future<void> logout() async {
    if (_repo.isLiveSupabase) {
      final User? authUser = Supabase.instance.client.auth.currentUser;

      if (authUser != null) {
        await Supabase.instance.client.auth.signOut();
      }
    }

    await _clearStoredSession();
  }

  Future<void> _clearStoredSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove(_sessionKey);
  }
}
