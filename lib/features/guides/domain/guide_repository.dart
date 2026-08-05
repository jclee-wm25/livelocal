import '../../../models/guide_model.dart';

class GuideDraftInput {
  const GuideDraftInput({
    required this.title,
    required this.locationName,
    required this.state,
    required this.routeOverview,
    required this.stops,
    required this.walkingSequence,
    required this.estimatedDuration,
  });

  final String title;
  final String locationName;
  final String state;
  final String routeOverview;
  final List<String> stops;
  final List<String> walkingSequence;
  final String estimatedDuration;
}

abstract interface class GuideRepository {
  Future<List<GuideModel>> fetchPublishedGuides();
  Future<List<GuideModel>> fetchAdminDrafts();
  Future<GuideModel> saveAdminDraft(
    GuideDraftInput input, {
    GuideModel? guide,
  });
  Future<void> publishAdminDraft(GuideModel draft, String reason);
  Future<void> archiveGuide(GuideModel guide, String reason);
}
