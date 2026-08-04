import 'package:flutter/foundation.dart';
import '../models/restaurant_model.dart';
import '../models/discount_code_model.dart';
import '../services/supabase_repository.dart';

class LocalEatsController with ChangeNotifier {
  final SupabaseRepository _db = SupabaseRepository();

  List<RestaurantModel> _restaurants = [];
  List<DiscountCodeModel> _discountCodes = [];
  bool _isLoading = false;
  String _selectedState = 'All';
  String _selectedCuisine = 'All';
  String _selectedBudget = 'All';

  List<RestaurantModel> get restaurants => _restaurants;
  List<DiscountCodeModel> get discountCodes => _discountCodes;
  bool get isLoading => _isLoading;
  String get selectedState => _selectedState;
  String get selectedCuisine => _selectedCuisine;
  String get selectedBudget => _selectedBudget;

  LocalEatsController() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _restaurants = await _db.fetchRestaurants();
      _discountCodes = await _db.fetchDiscountCodes();
    } catch (e) {
      debugPrint('LocalEatsController: loadData failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<RestaurantModel> get filteredRestaurants {
    return _restaurants.where((r) {
      if (_selectedState != 'All' && r.state.toLowerCase() != _selectedState.toLowerCase()) return false;
      if (_selectedCuisine != 'All' && !r.cuisineType.toLowerCase().contains(_selectedCuisine.toLowerCase())) return false;
      if (_selectedBudget != 'All' && r.priceRange != _selectedBudget) return false;
      return true;
    }).toList();
  }

  List<RestaurantModel> get trendingRestaurants {
    // Return latest 3 restaurants for trending carousel
    final copy = List<RestaurantModel>.from(_restaurants);
    return copy.reversed.take(3).toList();
  }

  List<DiscountCodeModel> getActiveDiscountsForRestaurant(String restaurantId) {
    return _discountCodes.where((d) => d.restaurantId == restaurantId && !d.isExpired).toList();
  }

  void setFilter({String? state, String? cuisine, String? budget}) {
    if (state != null) _selectedState = state;
    if (cuisine != null) _selectedCuisine = cuisine;
    if (budget != null) _selectedBudget = budget;
    notifyListeners();
  }

  void resetFilters() {
    _selectedState = 'All';
    _selectedCuisine = 'All';
    _selectedBudget = 'All';
    notifyListeners();
  }

  Future<void> addRestaurantListing(RestaurantModel restaurant) async {
    try {
      await _db.addRestaurant(restaurant);
    } catch (e) {
      debugPrint('LocalEatsController: addRestaurantListing failed: $e');
      rethrow;
    }
    await loadData();
  }

  Future<void> addDiscountCode(DiscountCodeModel discount) async {
    try {
      await _db.addDiscountCode(discount);
    } catch (e) {
      debugPrint('LocalEatsController: addDiscountCode failed: $e');
      rethrow;
    }
    await loadData();
  }
}
