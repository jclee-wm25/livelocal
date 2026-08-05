import '../../../core/errors/app_exception.dart';
import '../../../models/guide_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/guide_repository.dart';

class DemoGuideRepository implements GuideRepository {
  DemoGuideRepository(this._authRepository)
      : _guides = List.of(SeedDataService.getInitialGuides());

  final DemoAuthRepository _authRepository;
  final List<GuideModel> _guides;

  @override
  Future<List<GuideModel>> fetchPublishedGuides() async {
    return _guides.where((guide) => guide.status == 'approved').toList();
  }

  @override
  Future<List<GuideModel>> fetchAdminDrafts() async {
    _requireAdmin();
    return _guides.where((guide) => guide.status == 'draft').toList();
  }

  @override
  Future<GuideModel> saveAdminDraft(GuideDraftInput input) async {
    _requireAdmin();
    _validate(input);
    final id = 'demo-guide-${DateTime.now().microsecondsSinceEpoch}';
    final guide = GuideModel(
      id: id,
      revisionId:
          'demo-guide-revision-${DateTime.now().microsecondsSinceEpoch}',
      title: input.title.trim(),
      locationName: input.locationName.trim(),
      state: input.state.trim(),
      routeOverview: input.routeOverview.trim(),
      stops: input.stops.map((item) => item.trim()).toList(),
      walkingSequence:
          input.walkingSequence.map((item) => item.trim()).toList(),
      estimatedDuration: input.estimatedDuration.trim(),
      status: 'draft',
    );
    _guides.add(guide);
    return guide;
  }

  @override
  Future<void> publishAdminDraft(GuideModel draft, String reason) async {
    _requireAdmin();
    if (reason.trim().length < 3) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Record a publication reason.',
      );
    }
    final index = _guides.indexWhere((guide) => guide.id == draft.id);
    if (index < 0 || _guides[index].status != 'draft') {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'The guide draft changed. Refresh and try again.',
      );
    }
    _guides[index] = _copy(_guides[index], status: 'approved', version: 2);
  }

  void _requireAdmin() {
    final account = _authRepository.currentAccountForDemo;
    if (account?.appRole != AppRole.admin ||
        account?.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'Administrator permission is required.',
      );
    }
  }

  void _validate(GuideDraftInput input) {
    if (input.title.trim().length < 3 ||
        input.routeOverview.trim().length < 20 ||
        input.stops.isEmpty ||
        input.stops.length != input.walkingSequence.length ||
        input.stops.any((item) => item.trim().length < 2) ||
        input.walkingSequence.any((item) => item.trim().length < 2)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Complete the guide and provide matching route steps.',
      );
    }
  }

  GuideModel _copy(
    GuideModel value, {
    required String status,
    required int version,
  }) {
    return GuideModel(
      id: value.id,
      revisionId: value.revisionId,
      version: version,
      title: value.title,
      locationName: value.locationName,
      state: value.state,
      routeOverview: value.routeOverview,
      stops: value.stops,
      walkingSequence: value.walkingSequence,
      estimatedDuration: value.estimatedDuration,
      status: status,
    );
  }
}
