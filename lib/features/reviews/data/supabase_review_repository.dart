import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/review_model.dart';
import '../domain/review_repository.dart';

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ReviewModel>> fetchReviews({
    String? spotId,
    String? restaurantId,
  }) async {
    try {
      var publicRequest = _client.from('public_reviews').select();
      if (spotId != null) {
        publicRequest =
            publicRequest.eq('target_type', 'spot').eq('target_id', spotId);
      } else if (restaurantId != null) {
        publicRequest = publicRequest
            .eq('target_type', 'restaurant')
            .eq('target_id', restaurantId);
      }
      final publicRows =
          await publicRequest.order('updated_at', ascending: false).limit(100);
      final ownRows = _client.auth.currentUser == null
          ? const <dynamic>[]
          : await _client.from('reviews').select().eq('status', 'published');
      final ownById = <String, Map<String, dynamic>>{
        for (final raw in ownRows)
          (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
      };
      return (publicRows as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final own = ownById[row['id']];
        final isSpot = row['target_type'] == 'spot';
        return ReviewModel(
          id: row['id'] as String,
          spotId: isSpot ? row['target_id'] as String : null,
          restaurantId: isSpot ? null : row['target_id'] as String,
          userId: own?['user_id'] as String? ?? '',
          userName: row['author_display_name'] as String,
          rating: (row['rating'] as num).toDouble(),
          comment: row['body'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
          version: (row['version'] as num).toInt(),
          isOwnedByCurrentUser: own != null,
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw _error(error, 'Reviews could not be loaded.');
    }
  }

  @override
  Future<ReviewModel> upsertReview({
    String? spotId,
    String? restaurantId,
    required int rating,
    required String comment,
    int? expectedVersion,
  }) async {
    final targetId = spotId ?? restaurantId;
    if (targetId == null || (spotId == null) == (restaurantId == null)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose one place to review.',
      );
    }
    try {
      final response = await _client.rpc('upsert_review', params: {
        'p_target_type': spotId != null ? 'spot' : 'restaurant',
        'p_target_id': targetId,
        'p_rating': rating,
        'p_body': comment,
        'p_expected_version': expectedVersion,
      });
      final row = Map<String, dynamic>.from(response as Map);
      return ReviewModel(
        id: row['id'] as String,
        spotId: spotId,
        restaurantId: restaurantId,
        userId: '',
        userName: row['author_display_name'] as String,
        rating: (row['rating'] as num).toDouble(),
        comment: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        version: (row['version'] as num).toInt(),
        isOwnedByCurrentUser: true,
      );
    } on PostgrestException catch (error) {
      throw _error(
        error,
        error.code == '40001'
            ? 'Your review changed. Refresh and try again.'
            : 'Your review could not be saved.',
      );
    }
  }

  @override
  Future<void> deleteReview({
    required String reviewId,
    required int expectedVersion,
  }) async {
    try {
      await _client.rpc('delete_my_review', params: {
        'p_review_id': reviewId,
        'p_expected_version': expectedVersion,
      });
    } on PostgrestException catch (error) {
      throw _error(error, 'The review could not be deleted.');
    }
  }

  @override
  Future<ModerationCaseReceipt> reportReview({
    required String reviewId,
    required String reason,
    String? explanation,
    required bool hideForReporter,
  }) async {
    try {
      final response = await _client.rpc('report_content', params: {
        'p_target_type': 'review',
        'p_target_id': reviewId,
        'p_reason': reason,
        'p_explanation': explanation,
        'p_hide_for_me': hideForReporter,
      });
      final row = Map<String, dynamic>.from(response as Map);
      return ModerationCaseReceipt(
        id: row['id'] as String,
        status: row['status'] as String,
        version: (row['version'] as num).toInt(),
      );
    } on PostgrestException catch (error) {
      throw _error(
        error,
        error.code == '23505'
            ? 'You already have an active report for this review.'
            : 'The report could not be submitted.',
      );
    }
  }

  AppException _error(PostgrestException error, String message) {
    return AppException(
      code: switch (error.code) {
        '23505' => AppErrorCode.conflict,
        '40001' => AppErrorCode.conflict,
        '42501' => AppErrorCode.forbidden,
        _ => AppErrorCode.unexpected,
      },
      userMessage: message,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
