import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/core/errors/app_exception.dart';
import 'package:live_local/features/moderation/presentation/ugc_consent_dialog.dart';
import 'package:live_local/features/reviews/presentation/review_controller.dart';
import 'package:live_local/features/reviews/domain/review_repository.dart';
import 'package:live_local/models/review_model.dart';

class MockReviewRepository implements ReviewRepository {
  int upsertCalls = 0;
  bool shouldThrowRulesError = false;
  bool shouldThrowRestrictedError = false;
  bool shouldThrowOtherError = false;

  @override
  Future<List<ReviewModel>> fetchReviews(
      {String? spotId, String? restaurantId}) async {
    return [];
  }

  @override
  Future<ReviewModel> upsertReview({
    String? spotId,
    String? restaurantId,
    required int rating,
    required String comment,
    int? expectedVersion,
  }) async {
    upsertCalls++;
    if (shouldThrowRulesError) {
      throw const AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'UGC_RULES_ACCEPTANCE_REQUIRED',
      );
    }
    if (shouldThrowRestrictedError) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage:
            'Your content contains restricted words. Please revise it and try again.',
      );
    }
    if (shouldThrowOtherError) {
      throw const AppException(
        code: AppErrorCode.unexpected,
        userMessage: 'Other error',
      );
    }
    return ReviewModel(
      id: '1',
      spotId: spotId,
      restaurantId: restaurantId,
      userId: '1',
      userName: 'Test',
      rating: rating.toDouble(),
      comment: comment,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
      isOwnedByCurrentUser: true,
    );
  }

  @override
  Future<void> deleteReview(
      {required String reviewId, required int expectedVersion}) async {}
  @override
  Future<ModerationCaseReceipt> reportReview(
      {required String reviewId,
      required String reason,
      String? explanation,
      required bool hideForReporter}) async {
    return const ModerationCaseReceipt(id: '1', status: 'pending', version: 1);
  }
}

void main() {
  setUp(() {
    UgcConsentDialog.onAcceptOverride = null;
  });

  testWidgets(
      'missing consent produces shared Rules dialog and retries exactly once on agree',
      (tester) async {
    final repo = MockReviewRepository();
    repo.shouldThrowRulesError = true;
    final controller = ReviewController(repository: repo);

    bool dialogAccepted = false;
    UgcConsentDialog.onAcceptOverride = () async {
      dialogAccepted = true;
      // After accepting, the repository should succeed on retry
      repo.shouldThrowRulesError = false;
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await controller.addReview(
                context,
                spotId: 'spot1',
                rating: 5,
                comment: 'Great spot!',
              );
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Community Rules Update'), findsOneWidget);

    // Tap agree
    await tester.tap(find.text('Agree & Continue'));
    await tester.pumpAndSettle();

    expect(dialogAccepted, isTrue);
    expect(repo.upsertCalls, 2); // original + exactly one retry
    expect(find.text('Community Rules Update'), findsNothing);
    expect(controller.errorMessage, isNull);
  });

  testWidgets('cancel does not retry submission', (tester) async {
    final repo = MockReviewRepository();
    repo.shouldThrowRulesError = true;
    final controller = ReviewController(repository: repo);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await controller.addReview(
                context,
                spotId: 'spot1',
                rating: 5,
                comment: 'Great spot!',
              );
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Community Rules Update'), findsOneWidget);

    // Tap cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.upsertCalls, 1); // no retry
    expect(find.text('Community Rules Update'), findsNothing);
    expect(controller.errorMessage,
        isNull); // Should just gracefully cancel without red text
  });

  testWidgets('second consent failure does not loop', (tester) async {
    final repo = MockReviewRepository();
    repo.shouldThrowRulesError = true; // permanently throws
    final controller = ReviewController(repository: repo);

    UgcConsentDialog.onAcceptOverride = () async {};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await controller.addReview(
                context,
                spotId: 'spot1',
                rating: 5,
                comment: 'Great spot!',
              );
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Tap agree
    await tester.tap(find.text('Agree & Continue'));
    await tester.pumpAndSettle();

    // Should only have been called twice, no infinite loop
    expect(repo.upsertCalls, 2);
    // Error message might be null since we gracefully handled the first one, but the retry failed
    // The retry will just throw or return false. Actually, the retry will see isRetry=true, so it will fall through to _errorMessage!
    expect(controller.errorMessage, isNotNull);
    // Dialog should not reopen
    expect(find.text('Community Rules Update'), findsNothing);
  });

  testWidgets('restricted-content error maps to safe UI message',
      (tester) async {
    final repo = MockReviewRepository();
    repo.shouldThrowRestrictedError = true;
    final controller = ReviewController(repository: repo);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await controller.addReview(
                context,
                spotId: 'spot1',
                rating: 5,
                comment: 'Bad word!',
              );
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Community Rules Update'),
        findsNothing); // Dialog does NOT open
    expect(controller.errorMessage,
        'Your content contains restricted words. Please revise it and try again.');
  });

  testWidgets('unrelated Postgres errors do NOT trigger the consent dialog',
      (tester) async {
    final repo = MockReviewRepository();
    repo.shouldThrowOtherError = true;
    final controller = ReviewController(repository: repo);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await controller.addReview(
                context,
                spotId: 'spot1',
                rating: 5,
                comment: 'Hello',
              );
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Community Rules Update'), findsNothing);
    expect(controller.errorMessage, 'Other error');
  });
}
