import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/spot_model.dart';
import '../domain/spot_repository.dart';

class SpotController with ChangeNotifier {
  SpotController({required SpotRepository repository})
      : _repository = repository {
    unawaited(loadSpots());
  }

  static const int _pageSize = 20;
  final SpotRepository _repository;
  final List<SpotModel> _spots = [];
  List<SpotModel> _pendingSpots = [];
  List<SpotModel> _ownedSubmissions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedState = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _errorMessage;
  Timer? _searchDebounce;

  List<SpotModel> get spots => List.unmodifiable(_spots);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get selectedState => _selectedState;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<SpotModel> get approvedSpots => _spots.where(_matchesFilters).toList();
  List<SpotModel> get pendingSpots => List.unmodifiable(_pendingSpots);
  List<SpotModel> get ownedSubmissions => List.unmodifiable(_ownedSubmissions);

  Future<void> loadSpots() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _repository.fetchPublicSpots(
        query: _searchQuery,
        state: _selectedState,
        category: _selectedCategory,
        offset: 0,
        limit: _pageSize,
      );
      _spots
        ..clear()
        ..addAll(loaded);
      _hasMore = loaded.length == _pageSize;
    } catch (error) {
      _errorMessage = _message(error, 'Local spots could not be loaded.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final loaded = await _repository.fetchPublicSpots(
        query: _searchQuery,
        state: _selectedState,
        category: _selectedCategory,
        offset: _spots.length,
        limit: _pageSize,
      );
      _spots.addAll(loaded);
      _hasMore = loaded.length == _pageSize;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'More spots could not be loaded.');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingSpots() async {
    try {
      _pendingSpots = await _repository.fetchPendingModeration();
      _errorMessage = null;
    } catch (error) {
      _errorMessage =
          _message(error, 'Pending submissions could not be loaded.');
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadOwnedSubmissions() async {
    try {
      _ownedSubmissions = await _repository.fetchOwnedSubmissions();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'Your submissions could not be loaded.');
    } finally {
      notifyListeners();
    }
  }

  void filter({String? state, String? category, String? query}) {
    if (state != null) _selectedState = state;
    if (category != null) _selectedCategory = category;
    if (query != null) _searchQuery = query;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), loadSpots);
  }

  void resetFilters() {
    _selectedState = 'All';
    _selectedCategory = 'All';
    _searchQuery = '';
    unawaited(loadSpots());
  }

  Future<SpotDraftResult?> submitDraft({
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
    required bool imageRightsConfirmed,
    String? duplicateOverrideReason,
  }) async {
    _errorMessage = null;
    notifyListeners();
    if (imageBytes == null || !imageRightsConfirmed) {
      _errorMessage = 'Choose a photo and confirm that you may share it.';
      notifyListeners();
      return null;
    }
    try {
      final draft = await _repository.createDraft(
        input: input,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );
      await _repository.confirmImageRights(draft.revisionId);
      if (draft.probableDuplicates.isEmpty || duplicateOverrideReason != null) {
        await _repository.submitRevision(
          revisionId: draft.revisionId,
          duplicateOverrideReason: duplicateOverrideReason,
        );
        await loadPendingSpots();
      }
      return draft;
    } catch (error) {
      _errorMessage = _message(error, 'The spot could not be submitted.');
      notifyListeners();
      return null;
    }
  }

  Future<SpotDraftResult?> reviseAndSubmit({
    required SpotModel source,
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
    required bool imageRightsConfirmed,
    String? duplicateOverrideReason,
  }) async {
    _errorMessage = null;
    notifyListeners();
    if ((imageBytes == null && source.imageUrl.isEmpty) ||
        !imageRightsConfirmed) {
      _errorMessage =
          'Choose or keep a photo and confirm that you may share it.';
      notifyListeners();
      return null;
    }
    try {
      final draft = await _repository.saveRevisionDraft(
        source: source,
        input: input,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );
      await _repository.confirmImageRights(draft.revisionId);
      if (draft.probableDuplicates.isEmpty || duplicateOverrideReason != null) {
        await _repository.submitRevision(
          revisionId: draft.revisionId,
          duplicateOverrideReason: duplicateOverrideReason,
        );
      }
      await loadOwnedSubmissions();
      return draft;
    } catch (error) {
      _errorMessage = _message(error, 'The spot revision could not be saved.');
      notifyListeners();
      return null;
    }
  }

  Future<bool> withdrawSubmission(SpotModel spot) async {
    final revisionId = spot.revisionId;
    if (revisionId == null) return false;
    try {
      await _repository.withdrawRevision(revisionId);
      await Future.wait([loadOwnedSubmissions(), loadSpots()]);
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The submission could not be withdrawn.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitExistingDraft(
    String revisionId,
    String duplicateOverrideReason,
  ) async {
    try {
      await _repository.submitRevision(
        revisionId: revisionId,
        duplicateOverrideReason: duplicateOverrideReason,
      );
      await loadPendingSpots();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The spot could not be submitted.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> discardDraft(SpotDraftResult draft) async {
    try {
      await _repository.deleteDraft(
        revisionId: draft.revisionId,
        imagePath: draft.imagePath,
      );
      await loadOwnedSubmissions();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The draft could not be discarded.');
      notifyListeners();
      return false;
    }
  }

  Future<void> approveSpot(SpotModel spot) async {
    await _moderate(
        spot, 'approved', 'Meets LiveLocal publication guidelines.');
  }

  Future<void> approveSpotWithReason(SpotModel spot, String reason) async {
    await _moderate(spot, 'approved', reason);
  }

  Future<void> rejectSpot(SpotModel spot, String reason) async {
    await _moderate(spot, 'rejected', reason);
  }

  Future<void> _moderate(SpotModel spot, String decision, String reason) async {
    final revisionId = spot.revisionId;
    if (revisionId == null) throw StateError('Missing revision identifier');
    try {
      await _repository.moderateRevision(
        revisionId: revisionId,
        decision: decision,
        reason: reason,
        expectedVersion: spot.moderationVersion,
      );
      await Future.wait([loadPendingSpots(), loadSpots()]);
    } catch (error) {
      _errorMessage = _message(error, 'The moderation decision failed.');
      notifyListeners();
      rethrow;
    }
  }

  bool _matchesFilters(SpotModel spot) {
    if (spot.status != 'approved') return false;
    if (_selectedState != 'All' && spot.state != _selectedState) return false;
    if (_selectedCategory != 'All' && spot.category != _selectedCategory) {
      return false;
    }
    final query = _searchQuery.trim().toLowerCase();
    return query.isEmpty ||
        spot.name.toLowerCase().contains(query) ||
        spot.city.toLowerCase().contains(query) ||
        spot.description.toLowerCase().contains(query);
  }

  String _message(Object error, String fallback) {
    return error is AppException ? error.userMessage : fallback;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
