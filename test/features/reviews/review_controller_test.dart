import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/reviews/data/demo_review_repository.dart';
import 'package:live_local/features/reviews/presentation/review_controller.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  test('one review per target is edited with a version increment', () async {
    final authRepository = DemoAuthRepository();
    await authRepository.signIn(
      email: 'tourist@livelocal.my',
      password: SeedDataService.demoPassword,
    );
    final controller = ReviewController(
      repository: DemoReviewRepository(authRepository),
    );
    await controller.loadReviews(spotId: 'spot-002');

    expect(
      await controller.addReview(
        spotId: 'spot-002',
        rating: 4,
        comment: 'A useful first review.',
      ),
      isTrue,
    );
    final first = controller
        .getReviewsForSpot('spot-002')
        .singleWhere((review) => review.isOwnedByCurrentUser);

    expect(
      await controller.addReview(
        spotId: 'spot-002',
        rating: 5,
        comment: 'Updated after another visit.',
      ),
      isTrue,
    );
    final updated = controller
        .getReviewsForSpot('spot-002')
        .singleWhere((review) => review.isOwnedByCurrentUser);
    expect(updated.id, first.id);
    expect(updated.version, first.version + 1);
    expect(updated.rating, 5);
  });

  test('report is pending, personally hidden, and cannot be duplicated',
      () async {
    final authRepository = DemoAuthRepository();
    await authRepository.signIn(
      email: 'foodie@livelocal.my',
      password: SeedDataService.demoPassword,
    );
    final controller = ReviewController(
      repository: DemoReviewRepository(authRepository),
    );
    await controller.loadReviews();
    final target = controller.reviews.first;

    expect(
      await controller.reportReview(
        reviewId: target.id,
        reason: 'spam',
      ),
      isTrue,
    );
    expect(controller.reviews.any((review) => review.id == target.id), isFalse);
    expect(
      await controller.reportReview(
        reviewId: target.id,
        reason: 'spam',
      ),
      isFalse,
    );
  });
}
