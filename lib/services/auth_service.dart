import '../models/profile_model.dart';
import '../repositories/supabase_repository.dart';

class AuthService {
  final SupabaseRepository _repo = SupabaseRepository();

  // Local development mode only.
  // Seed accounts use "password" as the demo password.
  // Newly registered local accounts are stored here during the current run.
  static final Map<String, String> _localPasswords = {};

  bool _isValidEmail(String email) {
    final emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    return emailPattern.hasMatch(email);
  }

  Future<ProfileModel> login(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    if (!_isValidEmail(normalizedEmail)) {
      throw Exception('Please enter a valid email address.');
    }

    if (_repo.isLiveSupabase) {
      final response = await _repo.signIn(
        normalizedEmail,
        password,
      );

      if (response == null || response.user == null) {
        throw Exception('Invalid email or password.');
      }

      final profiles = await _repo.fetchProfiles();

      final userProfile = profiles.firstWhere(
        (profile) => profile.email.trim().toLowerCase() == normalizedEmail,
        orElse: () {
          throw Exception('Profile not found for this account.');
        },
      );

      if (userProfile.isSuspended) {
        throw Exception(
          'Your account has been suspended by an administrator.',
        );
      }

      return userProfile;
    }

    // Local fallback mode
    final profiles = await _repo.fetchProfiles();

    final matchingProfiles = profiles.where(
      (profile) => profile.email.trim().toLowerCase() == normalizedEmail,
    );

    if (matchingProfiles.isEmpty) {
      throw Exception('Invalid email or password.');
    }

    final profile = matchingProfiles.first;

    // Registered local accounts use their entered password.
    // Seed accounts use "password" for development testing.
    final savedPassword = _localPasswords[normalizedEmail];

    final passwordIsValid = savedPassword != null
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

    return profile;
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

    if (!_isValidEmail(normalizedEmail)) {
      throw Exception('Please enter a valid email address.');
    }

    if (password.length < 6) {
      throw Exception(
        'Password must contain at least 6 characters.',
      );
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
      throw Exception(
        'An account with this email already exists.',
      );
    }

    if (_repo.isLiveSupabase) {
      final response = await _repo.signUp(
        normalizedEmail,
        password,
      );

      if (response == null || response.user == null) {
        throw Exception(
          'Registration failed. Please try again.',
        );
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

    // Save the local development password for this app session.
    _localPasswords[normalizedEmail] = password;

    return newProfile;
  }

  Future<void> updateProfile(
    ProfileModel updatedProfile,
  ) async {
    await _repo.saveProfile(updatedProfile);
  }
}
