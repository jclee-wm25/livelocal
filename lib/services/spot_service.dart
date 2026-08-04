import 'package:flutter/foundation.dart';
import '../models/spot_model.dart';
import '../repositories/supabase_repository.dart';

class SpotService {
  final SupabaseRepository _repo = SupabaseRepository();

  Future<List<SpotModel>> fetchSpots() {
    return _repo.fetchSpots();
  }

  Future<void> submitSpot(SpotModel newSpot) async {
    await _repo.addSpot(newSpot);
  }

  Future<void> updateSpot(SpotModel spot) async {
    await _repo.updateSpot(spot);
  }

  Future<void> approveSpot(String spotId, String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can approve spots.');
    }
    await _repo.updateSpotStatus(spotId, 'approved');
  }

  Future<void> rejectSpot(String spotId, String reason, String currentUserRole) async {
    if (currentUserRole != 'admin') {
      throw Exception('Unauthorized: Only admins can reject spots.');
    }
    await _repo.updateSpotStatus(spotId, 'rejected', rejectionReason: reason);
  }
}
