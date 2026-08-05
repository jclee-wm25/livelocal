class ModerationReceipt {
  const ModerationReceipt({
    required this.id,
    required this.status,
    required this.version,
  });

  final String id;
  final String status;
  final int version;
}

abstract interface class ModerationRepository {
  Future<ModerationReceipt> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  });
}
