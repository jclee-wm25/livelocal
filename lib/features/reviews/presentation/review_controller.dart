import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/review_model.dart';
import '../domain/review_repository.dart';

class ReviewController with ChangeNotifier {
  ReviewController({required ReviewRepository repository})
      : _repository = repository {
    unawaited(loadReviews());
  }

  final ReviewRepository _repository;
  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReviewModel> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadReviews({String? spotId, String? restaurantId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _reviews = await _repository.fetchReviews(
        spotId: spotId,
        restaurantId: restaurantId,
      );
    } catch (error) {
      _errorMessage = _message(error, 'Reviews could not be loaded.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ReviewModel> getReviewsForSpot(String spotId) {
    return _reviews.where((review) => review.spotId == spotId).toList();
  }

  List<ReviewModel> getReviewsForRestaurant(String restaurantId) {
    return _reviews
        .where((review) => review.restaurantId == restaurantId)
        .toList();
  }

  List<ReviewModel> get flaggedReviews => const [];

  double getAverageRating(String? spotId, String? restaurantId) {
    final list = spotId != null
        ? getReviewsForSpot(spotId)
        : restaurantId != null
            ? getReviewsForRestaurant(restaurantId)
            : <ReviewModel>[];
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (sum, review) => sum + review.rating) /
        list.length;
  }

  Future<bool> addReview({
    String? spotId,
    String? restaurantId,
    required double rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5 || comment.trim().length < 3) {
      _errorMessage = 'Choose a rating and write at least 3 characters.';
      notifyListeners();
      return false;
    }
    final existing = _reviews.where(
      (review) =>
          review.isOwnedByCurrentUser &&
          review.spotId == spotId &&
          review.restaurantId == restaurantId,
    );
    try {
      await _repository.upsertReview(
        spotId: spotId,
        restaurantId: restaurantId,
        rating: rating.round(),
        comment: comment.trim(),
        expectedVersion: existing.isEmpty ? null : existing.single.version,
      );
      await loadReviews(spotId: spotId, restaurantId: restaurantId);
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'Your review could not be saved.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportReview({
    required String reviewId,
    required String reason,
    String? explanation,
    bool hideForReporter = true,
  }) async {
    try {
      await _repository.reportReview(
        reviewId: reviewId,
        reason: reason,
        explanation: explanation,
        hideForReporter: hideForReporter,
      );
      if (hideForReporter) {
        _reviews.removeWhere((review) => review.id == reviewId);
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The report could not be submitted.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeReview(String reviewId) async {
    final matches = _reviews.where((review) => review.id == reviewId);
    if (matches.isEmpty || !matches.single.isOwnedByCurrentUser) return false;
    try {
      await _repository.deleteReview(
        reviewId: reviewId,
        expectedVersion: matches.single.version,
      );
      _reviews.removeWhere((review) => review.id == reviewId);
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'The review could not be deleted.');
      notifyListeners();
      return false;
    }
  }

  String _message(Object error, String fallback) {
    return error is AppException ? error.userMessage : fallback;
  }
}
