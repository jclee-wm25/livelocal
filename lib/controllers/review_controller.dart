import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

class ReviewController with ChangeNotifier {
  final ReviewService _service = ReviewService();

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;

  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;

  ReviewController() {
    loadReviews();
  }

  Future<void> loadReviews() async {
    _isLoading = true;
    notifyListeners();
    try {
      _reviews = await _service.fetchReviews();
    } catch (e) {
      debugPrint('ReviewController: loadReviews failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ReviewModel> getReviewsForSpot(String spotId) {
    return _reviews.where((r) => r.spotId == spotId && !r.isFlagged).toList();
  }

  List<ReviewModel> getReviewsForRestaurant(String restaurantId) {
    return _reviews
        .where((r) => r.restaurantId == restaurantId && !r.isFlagged)
        .toList();
  }

  List<ReviewModel> get flaggedReviews =>
      _reviews.where((r) => r.isFlagged).toList();

  double getAverageRating(String? spotId, String? restaurantId) {
    final list = spotId != null
        ? getReviewsForSpot(spotId)
        : (restaurantId != null
            ? getReviewsForRestaurant(restaurantId)
            : <ReviewModel>[]);
    if (list.isEmpty) return 0.0;
    final sum = list.fold<double>(0.0, (prev, r) => prev + r.rating);
    return sum / list.length;
  }

  Future<void> addReview({
    String? spotId,
    String? restaurantId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
    String? photoUrl,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }
    if (comment.trim().isEmpty) {
      throw ArgumentError('Review comment cannot be empty.');
    }
    final newReview = ReviewModel(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      spotId: spotId,
      restaurantId: restaurantId,
      userId: userId,
      userName: userName,
      rating: rating,
      comment: comment,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );
    try {
      await _service.addReview(newReview);
    } catch (e) {
      debugPrint('ReviewController: addReview failed: $e');
      rethrow;
    }
    await loadReviews();
  }

  Future<void> flagReview(String reviewId, String reason) async {
    try {
      await _service.flagReview(reviewId, reason);
    } catch (e) {
      debugPrint('ReviewController: flagReview failed: $e');
      rethrow;
    }
    await loadReviews();
  }

  Future<void> removeReview(String reviewId) async {
    try {
      await _service.removeReview(reviewId);
    } catch (e) {
      debugPrint('ReviewController: removeReview failed: $e');
      rethrow;
    }
    await loadReviews();
  }
}
