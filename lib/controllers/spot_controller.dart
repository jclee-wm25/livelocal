import 'package:flutter/foundation.dart';
import '../models/spot_model.dart';
import '../services/supabase_service.dart';

class SpotController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  List<SpotModel> _spots = [];
  bool _isLoading = false;
  String _selectedState = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<SpotModel> get spots => _spots;
  bool get isLoading => _isLoading;
  String get selectedState => _selectedState;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  SpotController() {
    loadSpots();
  }

  Future<void> loadSpots() async {
    _isLoading = true;
    notifyListeners();
    _spots = await _db.fetchSpots();
    _isLoading = false;
    notifyListeners();
  }

  List<SpotModel> get approvedSpots {
    return _spots.where((s) {
      if (s.status != 'approved') return false;
      if (_selectedState != 'All' && s.state.toLowerCase() != _selectedState.toLowerCase()) return false;
      if (_selectedCategory != 'All' && s.category.toLowerCase() != _selectedCategory.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.name.toLowerCase().contains(q);
        final matchCity = s.city.toLowerCase().contains(q);
        final matchDesc = s.description.toLowerCase().contains(q);
        if (!matchName && !matchCity && !matchDesc) return false;
      }
      return true;
    }).toList();
  }

  List<SpotModel> get pendingSpots => _spots.where((s) => s.status == 'pending').toList();

  void filter({String? state, String? category, String? query}) {
    if (state != null) _selectedState = state;
    if (category != null) _selectedCategory = category;
    if (query != null) _searchQuery = query;
    notifyListeners();
  }

  void resetFilters() {
    _selectedState = 'All';
    _selectedCategory = 'All';
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> submitSpot(SpotModel newSpot) async {
    await _db.addSpot(newSpot);
    await loadSpots();
  }

  Future<void> approveSpot(String spotId) async {
    await _db.updateSpotStatus(spotId, 'approved');
    await loadSpots();
  }

  Future<void> rejectSpot(String spotId, String reason) async {
    await _db.updateSpotStatus(spotId, 'rejected', rejectionReason: reason);
    await loadSpots();
  }
}
