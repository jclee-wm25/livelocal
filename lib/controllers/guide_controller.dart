import 'package:flutter/foundation.dart';
import '../models/guide_model.dart';
import '../repositories/supabase_repository.dart';

class GuideController with ChangeNotifier {
  final SupabaseRepository _db = SupabaseRepository();

  List<GuideModel> _guides = [];
  bool _isLoading = false;
  String _selectedState = 'All';

  List<GuideModel> get guides => _guides;
  bool get isLoading => _isLoading;
  String get selectedState => _selectedState;

  GuideController() {
    loadGuides();
  }

  Future<void> loadGuides() async {
    _isLoading = true;
    notifyListeners();
    try {
      _guides = await _db.fetchGuides();
    } catch (e) {
      debugPrint('GuideController: loadGuides failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<GuideModel> get approvedGuides {
    return _guides.where((g) {
      if (g.status != 'approved') return false;
      if (_selectedState != 'All' &&
          g.state.toLowerCase() != _selectedState.toLowerCase()) return false;
      return true;
    }).toList();
  }

  List<GuideModel> get pendingGuides =>
      _guides.where((g) => g.status == 'pending').toList();

  void setStateFilter(String state) {
    _selectedState = state;
    notifyListeners();
  }

  Future<void> approveGuide(String guideId) async {
    try {
      await _db.updateGuideStatus(guideId, 'approved');
    } catch (e) {
      debugPrint('GuideController: approveGuide failed: $e');
      rethrow;
    }
    await loadGuides();
  }

  Future<void> rejectGuide(String guideId, String reason) async {
    try {
      await _db.updateGuideStatus(guideId, 'rejected', rejectionReason: reason);
    } catch (e) {
      debugPrint('GuideController: rejectGuide failed: $e');
      rethrow;
    }
    await loadGuides();
  }
}
