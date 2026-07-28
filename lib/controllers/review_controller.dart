import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../services/supabase_service.dart';

class ReviewController with ChangeNotifier {
  final SupabaseService _db = SupabaseService();

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
    _reviews = await _db.fetchReviews();
    _isLoading = false;
    notifyListeners();
  }

  List<ReviewModel> getReviewsForSpot(String spotId) {
    return _reviews.where((r) => r.spotId == spotId && !r.isFlagged).toList();
  }

  List<ReviewModel> getReviewsForRestaurant(String restaurantId) {
    return _reviews.where((r) => r.restaurantId == restaurantId && !r.isFlagged).toList();
  }

  List<ReviewModel> get flaggedReviews => _reviews.where((r) => r.isFlagged).toList();

  double getAverageRating(String? spotId, String? restaurantId) {
    final list = spotId != null
        ? getReviewsForSpot(spotId)
        : (restaurantId != null ? getReviewsForRestaurant(restaurantId) : <ReviewModel>[]);
    if (list.isEmpty) return 4.5; // default fallback initial rating
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
    await _db.addReview(newReview);
    await loadReviews();
  }

  Future<void> flagReview(String reviewId, String reason) async {
    await _db.flagReview(reviewId, reason);
    await loadReviews();
  }

  Future<void> removeReview(String reviewId) async {
    await _db.deleteReview(reviewId);
    await loadReviews();
  }
}
