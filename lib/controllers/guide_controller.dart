import 'package:flutter/foundation.dart';
import '../models/guide_model.dart';
import '../services/supabase_service.dart';

class GuideController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

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
    _guides = await _db.fetchGuides();
    _isLoading = false;
    notifyListeners();
  }

  List<GuideModel> get approvedGuides {
    return _guides.where((g) {
      if (g.status != 'approved') return false;
      if (_selectedState != 'All' && g.state.toLowerCase() != _selectedState.toLowerCase()) return false;
      return true;
    }).toList();
  }

  List<GuideModel> get pendingGuides => _guides.where((g) => g.status == 'pending').toList();

  void setStateFilter(String state) {
    _selectedState = state;
    notifyListeners();
  }

  Future<void> approveGuide(String guideId) async {
    await _db.updateGuideStatus(guideId, 'approved');
    await loadGuides();
  }

  Future<void> rejectGuide(String guideId, String reason) async {
    await _db.updateGuideStatus(guideId, 'rejected', rejectionReason: reason);
    await loadGuides();
  }
}
