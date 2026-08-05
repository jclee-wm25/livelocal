class InfluencerApplication {
  const InfluencerApplication({
    required this.id,
    required this.userId,
    required this.status,
    required this.version,
    this.displayName,
    this.socialPlatform,
    this.profileUrl,
    this.followerCount,
    this.contentCategory,
    this.applicationMessage,
    this.rulesAgreed = false,
  });

  final String id;
  final String userId;
  final String status;
  final int version;
  final String? displayName;
  final String? socialPlatform;
  final String? profileUrl;
  final int? followerCount;
  final String? contentCategory;
  final String? applicationMessage;
  final bool rulesAgreed;
}

class InfluencerApplicationDraft {
  const InfluencerApplicationDraft({
    required this.displayName,
    required this.socialPlatform,
    required this.profileUrl,
    required this.followerCount,
    required this.contentCategory,
    required this.applicationMessage,
    required this.rulesAgreed,
  });

  final String displayName;
  final String socialPlatform;
  final String profileUrl;
  final int followerCount;
  final String contentCategory;
  final String applicationMessage;
  final bool rulesAgreed;
}

abstract interface class InfluencerApplicationRepository {
  Future<InfluencerApplication?> fetchMine();
  Future<List<InfluencerApplication>> fetchPendingForAdmin();

  Future<InfluencerApplication> saveDraft({
    InfluencerApplication? existing,
    required InfluencerApplicationDraft draft,
  });

  Future<InfluencerApplication> submit(InfluencerApplication application);
  Future<void> withdraw(InfluencerApplication application);

  Future<void> decide({
    required InfluencerApplication application,
    required String decision,
    required String reason,
  });
}
