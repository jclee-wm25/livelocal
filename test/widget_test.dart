import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/core/config/app_environment.dart';
import 'package:live_local/main.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/profile/data/demo_account_repository.dart';
import 'package:live_local/features/spots/data/demo_spot_repository.dart';
import 'package:live_local/features/reviews/data/demo_review_repository.dart';
import 'package:live_local/features/admin/data/demo_admin_repository.dart';
import 'package:live_local/features/influencer_applications/data/demo_influencer_application_repository.dart';
import 'package:live_local/features/restaurants/data/demo_local_eats_repository.dart';
import 'package:live_local/features/itinerary/data/demo_saved_itinerary_repository.dart';
import 'package:live_local/features/guides/data/demo_guide_repository.dart';
import 'package:live_local/features/notifications/data/demo_notification_repository.dart';
import 'package:live_local/features/moderation/data/demo_moderation_repository.dart';

void main() {
  testWidgets('LiveLocal App Smoke Test', (WidgetTester tester) async {
    final authRepository = DemoAuthRepository();
    await tester.pumpWidget(
      LiveLocalApp(
        configuration: AppConfiguration.demoForTesting(),
        authRepository: authRepository,
        accountRepository: DemoAccountRepository(authRepository),
        spotRepository: DemoSpotRepository(authRepository),
        reviewRepository: DemoReviewRepository(authRepository),
        adminRepository: DemoAdminRepository(authRepository),
        influencerApplicationRepository:
            DemoInfluencerApplicationRepository(authRepository),
        localEatsRepository: DemoLocalEatsRepository(authRepository),
        savedItineraryRepository: DemoSavedItineraryRepository(authRepository),
        guideRepository: DemoGuideRepository(authRepository),
        notificationRepository: DemoNotificationRepository(authRepository),
        moderationRepository: DemoModerationRepository(authRepository),
      ),
    );
    expect(find.byType(LiveLocalApp), findsOneWidget);
    expect(find.byType(Banner), findsOneWidget);
  });
}
