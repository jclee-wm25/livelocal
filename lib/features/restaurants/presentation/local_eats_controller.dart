import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/discount_code_model.dart';
import '../../../models/restaurant_model.dart';
import '../domain/local_eats_repository.dart';

class LocalEatsController with ChangeNotifier {
  LocalEatsController({required LocalEatsRepository repository})
      : _repository = repository {
    unawaited(loadData());
  }

  final LocalEatsRepository _repository;
  List<RestaurantModel> _restaurants = [];
  List<RestaurantModel> _pendingRestaurants = [];
  List<DiscountCodeModel> _discountCodes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedState = 'All';
  String _selectedCuisine = 'All';
  String _selectedBudget = 'All';
  String _searchQuery = '';

  List<RestaurantModel> get restaurants => List.unmodifiable(_restaurants);
  List<RestaurantModel> get pendingRestaurants =>
      List.unmodifiable(_pendingRestaurants);
  List<DiscountCodeModel> get discountCodes =>
      List.unmodifiable(_discountCodes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedState => _selectedState;
  String get selectedCuisine => _selectedCuisine;
  String get selectedBudget => _selectedBudget;
  String get searchQuery => _searchQuery;

  List<RestaurantModel> get filteredRestaurants =>
      _restaurants.where((restaurant) {
        final searchable = [
          restaurant.name,
          restaurant.cuisineType,
          restaurant.city,
          restaurant.state,
          restaurant.reviewedDishes,
        ].join(' ').toLowerCase();
        if (_searchQuery.isNotEmpty && !searchable.contains(_searchQuery)) {
          return false;
        }
        if (_selectedState != 'All' && restaurant.state != _selectedState) {
          return false;
        }
        if (_selectedCuisine != 'All' &&
            !restaurant.cuisineType
                .toLowerCase()
                .contains(_selectedCuisine.toLowerCase())) {
          return false;
        }
        return _selectedBudget == 'All' ||
            restaurant.priceRange == _selectedBudget;
      }).toList();

  List<RestaurantModel> get trendingRestaurants =>
      _restaurants.take(3).toList();
  List<RestaurantModel> get ownedApprovedRestaurants => _restaurants
      .where((restaurant) => restaurant.isOwnedByCurrentUser)
      .toList();

  List<DiscountCodeModel> getActiveDiscountsForRestaurant(
    String restaurantId,
  ) {
    return _discountCodes
        .where(
          (discount) =>
              discount.restaurantId == restaurantId &&
              discount.isCurrentlyActive,
        )
        .toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final values = await Future.wait([
        _repository.fetchPublicRestaurants(),
        _repository.fetchActiveDiscounts(),
      ]);
      _restaurants = values[0] as List<RestaurantModel>;
      _discountCodes = values[1] as List<DiscountCodeModel>;
    } catch (error) {
      _errorMessage = _message(error, 'LocalEats could not be loaded.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingRestaurants() async {
    try {
      _pendingRestaurants = await _repository.fetchPendingRestaurants();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(
        error,
        'Restaurant submissions could not be loaded.',
      );
    } finally {
      notifyListeners();
    }
  }

  void setFilter({String? state, String? cuisine, String? budget}) {
    if (state != null) _selectedState = state;
    if (cuisine != null) _selectedCuisine = cuisine;
    if (budget != null) _selectedBudget = budget;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value.trim().toLowerCase();
    notifyListeners();
  }

  void resetFilters() {
    _selectedState = 'All';
    _selectedCuisine = 'All';
    _selectedBudget = 'All';
    _searchQuery = '';
    notifyListeners();
  }

  Future<RestaurantDraftResult?> createRestaurantDraft({
    required RestaurantDraftInput input,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    try {
      final draft = await _repository.createRestaurantDraft(
        input: input,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );
      if (draft.probableDuplicates.isEmpty) {
        await _repository.submitRestaurant(revisionId: draft.revisionId);
      }
      _errorMessage = null;
      notifyListeners();
      return draft;
    } catch (error) {
      _errorMessage = _message(error, 'The restaurant could not be saved.');
      notifyListeners();
      return null;
    }
  }

  Future<bool> resolveRestaurantDuplicate(
    RestaurantDraftResult draft, {
    String? overrideReason,
    bool discard = false,
  }) async {
    try {
      if (discard) {
        await _repository.deleteRestaurantDraft(draft);
      } else {
        await _repository.submitRestaurant(
          revisionId: draft.revisionId,
          duplicateOverrideReason: overrideReason,
        );
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _message(
        error,
        'The restaurant draft could not be updated.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> moderateRestaurant(
    RestaurantModel restaurant,
    String decision,
    String reason,
  ) async {
    try {
      await _repository.moderateRestaurant(
        restaurant: restaurant,
        decision: decision,
        reason: reason,
      );
      await Future.wait([loadPendingRestaurants(), loadData()]);
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The restaurant decision failed.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> createDiscount(DiscountDraftInput input) async {
    try {
      await _repository.createAndPublishDiscount(input);
      await loadData();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The discount could not be created.');
      notifyListeners();
      return false;
    }
  }

  String _message(Object error, String fallback) {
    return error is AppException ? error.userMessage : fallback;
  }
}
