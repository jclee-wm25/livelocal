import '../models/review_model.dart';
import '../repositories/supabase_repository.dart';

class ReviewService {
  final SupabaseRepository _repo = SupabaseRepository();

  Future<List<ReviewModel>> fetchReviews() {
    return _repo.fetchReviews();
  }

  Future<void> addReview(ReviewModel newReview) async {
    // 1. Insert review
    await _repo.addReview(newReview);
    // 2. Cascading update for spot or restaurant rating
    await _recalculateAndSaveRating(
        spotId: newReview.spotId, restaurantId: newReview.restaurantId);
  }

  Future<void> flagReview(String reviewId, String reason) async {
    // 1. Flag review
    await _repo.flagReview(reviewId, reason);

    // 2. Re-calculate ratings (ignoring flagged reviews)
    final reviews = await _repo.fetchReviews();
    final target = reviews.firstWhere((r) => r.id == reviewId);
    await _recalculateAndSaveRating(
        spotId: target.spotId, restaurantId: target.restaurantId);
  }

  Future<void> removeReview(String reviewId) async {
    // 1. Fetch review to know its spot/restaurant
    final reviews = await _repo.fetchReviews();
    final targetIdx = reviews.indexWhere((r) => r.id == reviewId);
    if (targetIdx == -1) return;
    final target = reviews[targetIdx];

    // 2. Delete review
    await _repo.deleteReview(reviewId);

    // 3. Re-calculate ratings
    await _recalculateAndSaveRating(
        spotId: target.spotId, restaurantId: target.restaurantId);
  }

  Future<void> _recalculateAndSaveRating(
      {String? spotId, String? restaurantId}) async {
    final reviews = await _repo.fetchReviews();

    if (spotId != null) {
      final valid =
          reviews.where((r) => r.spotId == spotId && !r.isFlagged).toList();
      double newRating = 0.0;
      if (valid.isNotEmpty) {
        newRating = valid.fold<double>(0.0, (prev, r) => prev + r.rating) /
            valid.length;
      }
      await _repo.updateSpotRating(spotId, newRating, valid.length);
    } else if (restaurantId != null) {
      final valid = reviews
          .where((r) => r.restaurantId == restaurantId && !r.isFlagged)
          .toList();
      double newRating = 0.0;
      if (valid.isNotEmpty) {
        newRating = valid.fold<double>(0.0, (prev, r) => prev + r.rating) /
            valid.length;
      }
      await _repo.updateRestaurantRating(restaurantId, newRating, valid.length);
    }
  }
}
