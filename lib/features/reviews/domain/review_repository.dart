import '../../../models/review_model.dart';

class ModerationCaseReceipt {
  const ModerationCaseReceipt({
    required this.id,
    required this.status,
    required this.version,
  });

  final String id;
  final String status;
  final int version;
}

abstract interface class ReviewRepository {
  Future<List<ReviewModel>> fetchReviews({
    String? spotId,
    String? restaurantId,
  });

  Future<ReviewModel> upsertReview({
    String? spotId,
    String? restaurantId,
    required int rating,
    required String comment,
    int? expectedVersion,
  });

  Future<void> deleteReview({
    required String reviewId,
    required int expectedVersion,
  });

  Future<ModerationCaseReceipt> reportReview({
    required String reviewId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  });
}
