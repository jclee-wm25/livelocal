import '../models/profile_model.dart';
import '../repositories/supabase_repository.dart';

class AuthService {
  final SupabaseRepository _repo = SupabaseRepository();

  Future<ProfileModel> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    if (_repo.isLiveSupabase) {
      final res = await _repo.signIn(email, password);
      if (res == null || res.user == null) {
        throw Exception('Invalid login credentials.');
      }

      // Fetch the user's profile associated with this Auth user
      final profiles = await _repo.fetchProfiles();
      final userProfile = profiles.firstWhere(
        (p) => p.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Profile not found for this user.'),
      );

      if (userProfile.isSuspended) {
        // Technically we should sign out immediately if suspended, but
        // for simplicity we just throw.
        throw Exception('Your account has been suspended by an administrator.');
      }

      return userProfile;
    } else {
      // Local fallback
      final profiles = await _repo.fetchProfiles();
      final match = profiles
          .where((p) => p.email.toLowerCase() == email.toLowerCase())
          .toList();

      if (match.isEmpty) {
        throw Exception('Invalid email or password.');
      }
      if (match.first.isSuspended) {
        throw Exception('Your account has been suspended by an administrator.');
      }
      // Simulate successful local login
      return match.first;
    }
  }

  Future<ProfileModel> register(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty || normalizedName.isEmpty) {
      throw Exception('All registration fields are required.');
    }

    final emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(normalizedEmail)) {
      throw Exception('Please enter a valid email address.');
    }

    if (password.length < 6) {
      throw Exception('Password must contain at least 6 characters.');
    }

    const allowedRoles = {
      'tourist',
      'influencer',
    };

    if (!allowedRoles.contains(normalizedRole)) {
      throw Exception('Invalid user role selected.');
    }

    final existingProfiles = await _repo.fetchProfiles();

    final emailAlreadyExists = existingProfiles.any(
      (profile) => profile.email.trim().toLowerCase() == normalizedEmail,
    );

    if (emailAlreadyExists) {
      throw Exception('An account with this email already exists.');
    }

    if (_repo.isLiveSupabase) {
      final response = await _repo.signUp(
        normalizedEmail,
        password,
      );

      if (response == null || response.user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      final newProfile = ProfileModel(
        id: response.user!.id,
        email: normalizedEmail,
        fullName: normalizedName,
        role: normalizedRole,
      );

      await _repo.saveProfile(newProfile);

      return newProfile;
    }

    final newProfile = ProfileModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: normalizedEmail,
      fullName: normalizedName,
      role: normalizedRole,
    );

    await _repo.saveProfile(newProfile);

    return newProfile;
  }

  Future<void> updateProfile(ProfileModel updatedProfile) async {
    await _repo.saveProfile(updatedProfile);
  }
}
