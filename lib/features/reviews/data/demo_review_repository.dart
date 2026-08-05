import '../../../core/errors/app_exception.dart';
import '../../../models/review_model.dart';
import '../../../services/seed_data_service.dart';
import '../../auth/data/demo_auth_repository.dart';
import '../../auth/domain/account_identity.dart';
import '../domain/review_repository.dart';

class DemoReviewRepository implements ReviewRepository {
  DemoReviewRepository(this._authRepository)
      : _reviews = List<ReviewModel>.of(SeedDataService.getInitialReviews());

  final DemoAuthRepository _authRepository;
  final List<ReviewModel> _reviews;
  final Set<String> _hiddenReviewIds = {};
  final Set<String> _reportedReviewIds = {};

  @override
  Future<List<ReviewModel>> fetchReviews({
    String? spotId,
    String? restaurantId,
  }) async {
    final currentUserId = _authRepository.currentAccountForDemo?.id;
    return _reviews
        .where(
          (review) =>
              !_hiddenReviewIds.contains(review.id) &&
              (spotId == null || review.spotId == spotId) &&
              (restaurantId == null || review.restaurantId == restaurantId),
        )
        .map(
          (review) => _copy(
            review,
            isOwnedByCurrentUser: review.userId == currentUserId,
          ),
        )
        .toList();
  }

  @override
  Future<ReviewModel> upsertReview({
    String? spotId,
    String? restaurantId,
    required int rating,
    required String comment,
    int? expectedVersion,
  }) async {
    final account = _requireAccount();
    final index = _reviews.indexWhere(
      (review) =>
          review.userId == account.id &&
          review.spotId == spotId &&
          review.restaurantId == restaurantId,
    );
    if (index >= 0) {
      final existing = _reviews[index];
      if (expectedVersion != existing.version) {
        throw const AppException(
          code: AppErrorCode.conflict,
          userMessage: 'Your review changed. Refresh and try again.',
        );
      }
      final updated = _copy(
        existing,
        rating: rating.toDouble(),
        comment: comment.trim(),
        version: existing.version + 1,
        updatedAt: DateTime.now(),
        isOwnedByCurrentUser: true,
      );
      _reviews[index] = updated;
      return updated;
    }
    final created = ReviewModel(
      id: 'demo-review-${DateTime.now().microsecondsSinceEpoch}',
      spotId: spotId,
      restaurantId: restaurantId,
      userId: account.id,
      userName: account.fullName,
      rating: rating.toDouble(),
      comment: comment.trim(),
      createdAt: DateTime.now(),
      isOwnedByCurrentUser: true,
    );
    _reviews.add(created);
    return created;
  }

  @override
  Future<void> deleteReview({
    required String reviewId,
    required int expectedVersion,
  }) async {
    final account = _requireAccount();
    final index = _reviews.indexWhere(
      (review) => review.id == reviewId && review.userId == account.id,
    );
    if (index < 0) {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The review is no longer available.',
      );
    }
    if (_reviews[index].version != expectedVersion) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'Your review changed. Refresh and try again.',
      );
    }
    _reviews.removeAt(index);
  }

  @override
  Future<ModerationCaseReceipt> reportReview({
    required String reviewId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  }) async {
    final account = _requireAccount();
    final target = _reviews.where((review) => review.id == reviewId);
    if (target.isEmpty) {
      throw const AppException(
        code: AppErrorCode.notFound,
        userMessage: 'The review is no longer available.',
      );
    }
    if (target.single.userId == account.id) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'You cannot report your own review.',
      );
    }
    if (!_reportedReviewIds.add(reviewId)) {
      throw const AppException(
        code: AppErrorCode.conflict,
        userMessage: 'You already have an active report for this review.',
      );
    }
    if (hideForReporter) _hiddenReviewIds.add(reviewId);
    return ModerationCaseReceipt(
      id: 'demo-case-${DateTime.now().microsecondsSinceEpoch}',
      status: 'pending',
      version: 1,
    );
  }

  AccountIdentity _requireAccount() {
    final account = _authRepository.currentAccountForDemo;
    if (account == null || account.accessStatus != AccountAccessStatus.active) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in with an active account to continue.',
      );
    }
    return account;
  }

  ReviewModel _copy(
    ReviewModel review, {
    double? rating,
    String? comment,
    int? version,
    DateTime? updatedAt,
    bool? isOwnedByCurrentUser,
  }) {
    return ReviewModel(
      id: review.id,
      spotId: review.spotId,
      restaurantId: review.restaurantId,
      userId: review.userId,
      userName: review.userName,
      rating: rating ?? review.rating,
      comment: comment ?? review.comment,
      createdAt: review.createdAt,
      updatedAt: updatedAt ?? review.updatedAt,
      version: version ?? review.version,
      isOwnedByCurrentUser: isOwnedByCurrentUser ?? review.isOwnedByCurrentUser,
    );
  }
}
