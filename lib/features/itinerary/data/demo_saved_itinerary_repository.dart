import '../../../core/errors/app_exception.dart';
import '../../../models/saved_place_model.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/saved_itinerary_repository.dart';

class DemoSavedItineraryRepository implements SavedItineraryRepository {
  DemoSavedItineraryRepository(this._authRepository);

  final DemoAuthRepository _authRepository;
  final List<SavedPlaceModel> _savedPlaces = [];
  final List<SavedItinerary> _itineraries = [];
  RouteOrigin? _preference;

  RouteOrigin? get locationPreferenceForDemo => _preference;

  @override
  Future<List<SavedPlaceModel>> fetchSavedPlaces() async {
    final userId = _requireUser();
    return _savedPlaces.where((item) => item.userId == userId).toList();
  }

  @override
  Future<bool> setSaved({
    required String targetType,
    required String targetId,
    required bool saved,
  }) async {
    final userId = _requireUser();
    _validateTarget(targetType, targetId);
    _savedPlaces.removeWhere(
      (item) =>
          item.userId == userId &&
          (item.spotId == targetId || item.restaurantId == targetId),
    );
    if (saved) {
      _savedPlaces.add(
        SavedPlaceModel(
          id: 'demo-save-${DateTime.now().microsecondsSinceEpoch}',
          userId: userId,
          spotId: targetType == 'spot' ? targetId : null,
          restaurantId: targetType == 'restaurant' ? targetId : null,
          savedAt: DateTime.now(),
        ),
      );
    }
    return saved;
  }

  @override
  Future<List<SavedItinerary>> fetchItineraries() async {
    _requireUser();
    return List.unmodifiable(_itineraries);
  }

  @override
  Future<SavedItinerary> createItinerary({
    required String title,
    required RouteOrigin origin,
    required List<ItineraryTarget> orderedTargets,
  }) async {
    final userId = _requireUser();
    if (title.trim().length < 2 || orderedTargets.isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Add at least one saved place and a plan title.',
      );
    }
    final owned = _savedPlaces.where((item) => item.userId == userId).toList();
    for (final target in orderedTargets) {
      _validateTarget(target.type, target.id);
      if (!owned.any(
        (item) => item.spotId == target.id || item.restaurantId == target.id,
      )) {
        throw const AppException(
          code: AppErrorCode.forbidden,
          userMessage: 'An itinerary can contain only your saved places.',
        );
      }
    }
    final itinerary = SavedItinerary(
      id: 'demo-itinerary-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      originLabel: origin.label,
      version: 1,
      createdAt: DateTime.now(),
      targets: List.unmodifiable(orderedTargets),
    );
    _itineraries.add(itinerary);
    return itinerary;
  }

  @override
  Future<void> saveLocationPreference(RouteOrigin origin) async {
    _requireUser();
    _preference = origin;
  }

  String _requireUser() {
    final account = _authRepository.currentAccountForDemo;
    if (account == null || account.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in with an active account to continue.',
      );
    }
    return account.id;
  }

  void _validateTarget(String type, String id) {
    if (!{'spot', 'restaurant'}.contains(type) || id.isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a valid place.',
      );
    }
  }
}
