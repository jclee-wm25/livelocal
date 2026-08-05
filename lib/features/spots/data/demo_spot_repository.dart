import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../models/spot_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/spot_repository.dart';

class DemoSpotRepository implements SpotRepository {
  DemoSpotRepository(this._authRepository)
      : _spots = List<SpotModel>.of(SeedDataService.getInitialSpots()) {
    for (final spot in _spots) {
      _currentRevisionIds[spot.id] = spot.revisionId ?? spot.id;
    }
  }

  final DemoAuthRepository _authRepository;
  final List<SpotModel> _spots;
  final Set<String> _rightsConfirmedRevisions = {};
  final Map<String, String> _currentRevisionIds = {};

  @override
  Future<List<SpotModel>> fetchPublicSpots({
    String? query,
    String? state,
    String? category,
    required int offset,
    required int limit,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final filtered = _spots.where((spot) {
      if (spot.status != 'approved') return false;
      if (state != null && state != 'All' && spot.state != state) return false;
      if (category != null && category != 'All' && spot.category != category) {
        return false;
      }
      return normalizedQuery.isEmpty ||
          spot.name.toLowerCase().contains(normalizedQuery) ||
          spot.city.toLowerCase().contains(normalizedQuery) ||
          spot.description.toLowerCase().contains(normalizedQuery);
    }).toList();
    if (offset >= filtered.length) return const [];
    final end = (offset + limit).clamp(0, filtered.length);
    return filtered.sublist(offset, end);
  }

  @override
  Future<List<SpotModel>> fetchPendingModeration() async {
    return _spots.where((spot) => spot.status == 'submitted').toList();
  }

  @override
  Future<List<SpotModel>> fetchOwnedSubmissions() async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    return _spots
        .where(
          (spot) =>
              spot.submittedBy == accountId &&
              _currentRevisionIds[spot.id] == (spot.revisionId ?? spot.id),
        )
        .toList()
      ..sort((left, right) => right.id.compareTo(left.id));
  }

  @override
  Future<SpotDraftResult> createDraft({
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    _requireActiveAccount();
    final id = 'demo-spot-${DateTime.now().microsecondsSinceEpoch}';
    final revisionId = 'demo-revision-${DateTime.now().microsecondsSinceEpoch}';
    final duplicates = _spots
        .where(
          (spot) =>
              spot.status == 'approved' &&
              (spot.name.trim().toLowerCase() ==
                      input.name.trim().toLowerCase() ||
                  spot.address.trim().toLowerCase() ==
                      input.address.trim().toLowerCase()),
        )
        .map(
          (spot) => ProbableSpotDuplicate(
            id: spot.id,
            name: spot.name,
            address: spot.address,
            city: spot.city,
            state: spot.state,
          ),
        )
        .toList();
    _spots.add(
      SpotModel(
        id: id,
        revisionId: revisionId,
        name: input.name,
        category: input.category,
        description: input.description,
        state: input.state,
        city: input.city,
        address: input.address,
        priceRange: input.priceRange,
        bestTime: input.bestTime,
        thingsToDo: input.thingsToDo,
        imageUrl: imageBytes == null ? '' : 'demo://spot-image/$revisionId',
        submittedBy: _authRepository.currentAccountForDemo!.id,
        status: 'draft',
        latitude: input.latitude,
        longitude: input.longitude,
      ),
    );
    _currentRevisionIds[id] = revisionId;
    return SpotDraftResult(
      spotId: id,
      revisionId: revisionId,
      probableDuplicates: duplicates,
      imagePath: imageBytes == null ? null : 'demo://spot-image/$revisionId',
    );
  }

  @override
  Future<SpotDraftResult> saveRevisionDraft({
    required SpotModel source,
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    final sourceIndex = _spots.indexWhere(
      (spot) =>
          spot.revisionId == source.revisionId &&
          spot.submittedBy == accountId &&
          _currentRevisionIds[spot.id] == spot.revisionId,
    );
    if (sourceIndex < 0 ||
        !{
          'draft',
          'submitted',
          'under_review',
          'approved',
          'rejected',
          'withdrawn',
        }.contains(_spots[sourceIndex].status)) {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The current spot submission could not be edited.',
      );
    }
    final existing = _spots[sourceIndex];
    final revisionId = existing.status == 'draft'
        ? existing.revisionId!
        : 'demo-revision-${DateTime.now().microsecondsSinceEpoch}';
    final revised = SpotModel(
      id: existing.id,
      revisionId: revisionId,
      moderationVersion: existing.moderationVersion,
      name: input.name,
      category: input.category,
      description: input.description,
      state: input.state,
      city: input.city,
      address: input.address,
      priceRange: input.priceRange,
      bestTime: input.bestTime,
      thingsToDo: input.thingsToDo,
      imageUrl: imageBytes == null
          ? existing.imageUrl
          : 'demo://spot-image/$revisionId',
      imagePath: imageBytes == null
          ? existing.imagePath
          : 'demo://spot-image/$revisionId',
      submittedBy: accountId,
      status: 'draft',
      hasApprovedRevision: _spots
          .any((spot) => spot.id == existing.id && spot.status == 'approved'),
      latitude: input.latitude,
      longitude: input.longitude,
    );
    if (revised.imageUrl.isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a photo before saving the revision.',
      );
    }
    if (existing.status == 'draft') {
      _spots[sourceIndex] = revised;
    } else {
      if (existing.status == 'submitted' || existing.status == 'under_review') {
        _spots[sourceIndex] = _copy(existing, status: 'withdrawn');
      }
      _spots.add(revised);
    }
    _currentRevisionIds[existing.id] = revisionId;
    _rightsConfirmedRevisions.remove(revisionId);
    final duplicates = _spots
        .where(
          (spot) =>
              spot.id != existing.id &&
              spot.status == 'approved' &&
              (spot.name.trim().toLowerCase() ==
                      input.name.trim().toLowerCase() ||
                  spot.address.trim().toLowerCase() ==
                      input.address.trim().toLowerCase()),
        )
        .map(
          (spot) => ProbableSpotDuplicate(
            id: spot.id,
            name: spot.name,
            address: spot.address,
            city: spot.city,
            state: spot.state,
          ),
        )
        .toList();
    return SpotDraftResult(
      spotId: existing.id,
      revisionId: revisionId,
      probableDuplicates: duplicates,
      imagePath: revised.imagePath,
    );
  }

  @override
  Future<void> deleteDraft({
    required String revisionId,
    String? imagePath,
  }) async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    final draftIndex = _spots.indexWhere(
      (spot) =>
          spot.revisionId == revisionId &&
          spot.status == 'draft' &&
          spot.submittedBy == accountId &&
          _currentRevisionIds[spot.id] == revisionId,
    );
    if (draftIndex < 0) {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The current spot draft could not be discarded.',
      );
    }
    final draftSpotId = _spots[draftIndex].id;
    _spots.removeAt(draftIndex);
    _rightsConfirmedRevisions.remove(revisionId);
    if (_spots
        .any((spot) => spot.id == draftSpotId && spot.status == 'approved')) {
      final approved = _spots.lastWhere(
        (spot) => spot.id == draftSpotId && spot.status == 'approved',
      );
      _currentRevisionIds[draftSpotId] = approved.revisionId ?? approved.id;
    } else {
      _currentRevisionIds.remove(draftSpotId);
    }
  }

  @override
  Future<void> withdrawRevision(String revisionId) async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    final index = _spots.indexWhere(
      (spot) => spot.revisionId == revisionId && spot.submittedBy == accountId,
    );
    if (index < 0 ||
        !{'submitted', 'under_review'}.contains(_spots[index].status)) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'This spot is no longer awaiting review.',
      );
    }
    final withdrawn = _spots[index];
    _spots[index] = _copy(withdrawn, status: 'withdrawn');
    final approved = _spots.where(
      (spot) => spot.id == withdrawn.id && spot.status == 'approved',
    );
    if (approved.isNotEmpty) {
      final current = approved.last;
      _currentRevisionIds[withdrawn.id] = current.revisionId ?? current.id;
    }
  }

  @override
  Future<void> confirmImageRights(String revisionId) async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    SpotModel? draft;
    for (final spot in _spots) {
      if (spot.revisionId == revisionId &&
          spot.submittedBy == accountId &&
          _currentRevisionIds[spot.id] == revisionId) {
        draft = spot;
        break;
      }
    }
    if (draft == null || draft.status != 'draft' || draft.imageUrl.isEmpty) {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'Choose a photo before confirming image rights.',
      );
    }
    _rightsConfirmedRevisions.add(revisionId);
  }

  @override
  Future<void> submitRevision({
    required String revisionId,
    String? duplicateOverrideReason,
  }) async {
    _requireActiveAccount();
    final accountId = _authRepository.currentAccountForDemo!.id;
    final index = _spots.indexWhere(
      (spot) =>
          spot.revisionId == revisionId &&
          spot.submittedBy == accountId &&
          _currentRevisionIds[spot.id] == revisionId,
    );
    if (index < 0 || _spots[index].status != 'draft') {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The spot draft is no longer available.',
      );
    }
    if (_spots[index].imageUrl.isEmpty ||
        !_rightsConfirmedRevisions.contains(revisionId)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'A photo and rights confirmation are required.',
      );
    }
    final existing = _spots[index];
    _spots[index] = _copy(existing, status: 'submitted');
  }

  @override
  Future<void> moderateRevision({
    required String revisionId,
    required String decision,
    required String reason,
    required int expectedVersion,
  }) async {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.admin ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Administrator permission is required.',
      );
    }
    final index = _spots.indexWhere((spot) => spot.revisionId == revisionId);
    if (index < 0 || _spots[index].moderationVersion != expectedVersion) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'This submission changed. Refresh and try again.',
      );
    }
    if (decision == 'approved') {
      for (var candidate = 0; candidate < _spots.length; candidate++) {
        final item = _spots[candidate];
        if (candidate != index &&
            item.id == _spots[index].id &&
            item.status == 'approved') {
          _spots[candidate] = _copy(item, status: 'archived');
        }
      }
    }
    _spots[index] = _copy(
      _spots[index],
      status: decision,
      moderationVersion: expectedVersion + 1,
      rejectionReason: decision == 'rejected' ? reason : null,
    );
    _currentRevisionIds[_spots[index].id] =
        _spots[index].revisionId ?? _spots[index].id;
  }

  void _requireActiveAccount() {
    final account = _authRepository.currentAccountForDemo;
    if (account == null || account.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in with an active account to submit a spot.',
      );
    }
  }

  SpotModel _copy(
    SpotModel spot, {
    required String status,
    int? moderationVersion,
    String? rejectionReason,
  }) {
    return SpotModel(
      id: spot.id,
      revisionId: spot.revisionId,
      moderationVersion: moderationVersion ?? spot.moderationVersion,
      name: spot.name,
      category: spot.category,
      description: spot.description,
      state: spot.state,
      city: spot.city,
      address: spot.address,
      priceRange: spot.priceRange,
      bestTime: spot.bestTime,
      thingsToDo: spot.thingsToDo,
      imageUrl: spot.imageUrl,
      imagePath: spot.imagePath,
      rating: spot.rating,
      reviewCount: spot.reviewCount,
      submittedBy: spot.submittedBy,
      status: status,
      rejectionReason: rejectionReason,
      decisionReason: rejectionReason ?? spot.decisionReason,
      hasApprovedRevision: spot.hasApprovedRevision,
      latitude: spot.latitude,
      longitude: spot.longitude,
    );
  }
}
