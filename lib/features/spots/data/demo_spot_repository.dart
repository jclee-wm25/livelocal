import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../models/spot_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/spot_repository.dart';

class DemoSpotRepository implements SpotRepository {
  DemoSpotRepository(this._authRepository)
      : _spots = List<SpotModel>.of(SeedDataService.getInitialSpots());

  final DemoAuthRepository _authRepository;
  final List<SpotModel> _spots;
  final Set<String> _rightsConfirmedRevisions = {};

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
    return SpotDraftResult(
      spotId: id,
      revisionId: revisionId,
      probableDuplicates: duplicates,
      imagePath: imageBytes == null ? null : 'demo://spot-image/$revisionId',
    );
  }

  @override
  Future<void> deleteDraft({
    required String revisionId,
    String? imagePath,
  }) async {
    _requireActiveAccount();
    _spots.removeWhere(
      (spot) => spot.revisionId == revisionId && spot.status == 'draft',
    );
    _rightsConfirmedRevisions.remove(revisionId);
  }

  @override
  Future<void> confirmImageRights(String revisionId) async {
    _requireActiveAccount();
    SpotModel? draft;
    for (final spot in _spots) {
      if (spot.revisionId == revisionId) {
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
    final index = _spots.indexWhere((spot) => spot.revisionId == revisionId);
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
    _spots[index] = _copy(
      _spots[index],
      status: decision,
      moderationVersion: expectedVersion + 1,
      rejectionReason: decision == 'rejected' ? reason : null,
    );
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
      rating: spot.rating,
      reviewCount: spot.reviewCount,
      submittedBy: spot.submittedBy,
      status: status,
      rejectionReason: rejectionReason,
      latitude: spot.latitude,
      longitude: spot.longitude,
    );
  }
}
