import '../models/profile_model.dart';
import '../repositories/supabase_repository.dart';
import 'seed_data_service.dart';

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
      final matches = profiles
          .where(
              (profile) => profile.email.toLowerCase() == email.toLowerCase())
          .toList();
      if (matches.isEmpty) {
        await _repo.signOut();
        throw Exception('Profile not found for this user.');
      }
      final userProfile = matches.first;

      if (userProfile.isSuspended) {
        await _repo.signOut();
        throw Exception('Your account has been suspended by an administrator.');
      }

      return userProfile;
    } else {
      // Explicit non-release demo authentication. It never accepts arbitrary
      // passwords and cannot be selected by the release bootstrap.
      if (password != SeedDataService.demoPassword) {
        throw Exception('Invalid email or password.');
      }
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
      return match.first;
    }
  }

  Future<ProfileModel> register(
      String email, String password, String fullName) async {
    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      throw Exception('All registration fields are required.');
    }

    if (_repo.isLiveSupabase) {
      final res = await _repo.signUp(email, password);
      if (res == null || res.user == null) {
        throw Exception('Registration failed.');
      }

      final newProfile = ProfileModel(
        id: res.user!.id,
        email: email,
        fullName: fullName,
        role: 'tourist',
      );

      await _repo.saveProfile(newProfile);
      return newProfile;
    } else {
      // Explicit, nonpersistent demo registration.
      final profiles = await _repo.fetchProfiles();
      if (profiles.any((p) => p.email.toLowerCase() == email.toLowerCase())) {
        throw Exception('An account with this email already exists.');
      }

      final newProfile = ProfileModel(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: fullName,
        role: 'tourist',
      );

      await _repo.saveProfile(newProfile);
      return newProfile;
    }
  }

  Future<void> updateProfile(ProfileModel updatedProfile) async {
    await _repo.saveProfile(updatedProfile);
  }

  Future<void> logout() => _repo.signOut();
}
