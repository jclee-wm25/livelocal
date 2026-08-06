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

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final DateTime blockedAt;
}

class UserBlockReceipt {
  const UserBlockReceipt({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;
}

abstract interface class ModerationRepository {
  bool get supportsUserBlocking;

  Future<ModerationReceipt> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  });

  Future<UserBlockReceipt> blockContentAuthor({
    required String targetType,
    required String targetId,
  });

  Future<List<BlockedUser>> listBlockedUsers();

  Future<void> unblockUser(String userId);
}
