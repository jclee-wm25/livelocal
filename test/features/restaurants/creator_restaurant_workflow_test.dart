import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/core/errors/app_exception.dart';
import 'package:live_local/core/validation/social_url_validator.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/influencer_applications/data/demo_influencer_application_repository.dart';
import 'package:live_local/features/influencer_applications/domain/influencer_application_repository.dart';
import 'package:live_local/features/restaurants/data/demo_local_eats_repository.dart';
import 'package:live_local/features/restaurants/domain/local_eats_repository.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  group('creator and restaurant vertical slice', () {
    test('social links reject deceptive and unsupported hosts', () {
      expect(
        SocialUrlValidator.isSupported('https://instagram.com/example'),
        isTrue,
      );
      expect(
        SocialUrlValidator.isSupported('https://www.tiktok.com/@local'),
        isTrue,
      );
      expect(
        SocialUrlValidator.isSupported('http://instagram.com/example'),
        isFalse,
      );
      expect(
        SocialUrlValidator.isSupported('https://instagram.com.evil.test/x'),
        isFalse,
      );
      expect(
        SocialUrlValidator.isSupported('https://example.com/instagram.com'),
        isFalse,
      );
    });

    test('approval grants creator role and enables moderated listing workflow',
        () async {
      final auth = DemoAuthRepository();
      final applications = DemoInfluencerApplicationRepository(auth);
      final localEats = DemoLocalEatsRepository(auth);

      await auth.signIn(
        email: 'tourist@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final draft = await applications.saveDraft(
        draft: const InfluencerApplicationDraft(
          displayName: 'Local Explorer',
          socialPlatform: 'instagram',
          profileUrl: 'https://instagram.com/local-explorer',
          followerCount: 1500,
          contentCategory: 'Local food',
          applicationMessage:
              'I share careful, useful recommendations about local food.',
          rulesAgreed: true,
        ),
      );
      final submitted = await applications.submit(draft);
      expect(submitted.status, 'submitted');

      await auth.signOut();
      await auth.signIn(
        email: 'admin@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final queue = await applications.fetchPendingForAdmin();
      await applications.decide(
        application: queue.single,
        decision: 'approved',
        reason: 'Public work meets the creator rules.',
      );

      await auth.signOut();
      final creator = await auth.signIn(
        email: 'tourist@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      expect(creator.role, 'influencer');

      final restaurantDraft = await localEats.createRestaurantDraft(
        input: const RestaurantDraftInput(
          name: 'Workflow Test Kitchen',
          address: '12 Test Street',
          state: 'Penang',
          city: 'George Town',
          cuisineType: 'Malay',
          priceRange: r'$$',
          reviewedDishes: 'Nasi lemak and kuih',
          socialMediaUrl: 'https://tiktok.com/@local/video/123',
        ),
        imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        imageMimeType: 'image/jpeg',
      );
      expect(restaurantDraft.probableDuplicates, isEmpty);
      await localEats.submitRestaurant(revisionId: restaurantDraft.revisionId);

      await auth.signOut();
      await auth.signIn(
        email: 'admin@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final restaurantQueue = await localEats.fetchPendingRestaurants();
      final pending = restaurantQueue.singleWhere(
        (item) => item.id == restaurantDraft.restaurantId,
      );
      await localEats.moderateRestaurant(
        restaurant: pending,
        decision: 'approved',
        reason: 'Business details and supporting post verified.',
      );

      await auth.signOut();
      await auth.signIn(
        email: 'tourist@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final publicRestaurants = await localEats.fetchPublicRestaurants();
      expect(
        publicRestaurants
            .singleWhere(
              (item) => item.id == restaurantDraft.restaurantId,
            )
            .isOwnedByCurrentUser,
        isTrue,
      );

      final discount = await localEats.createAndPublishDiscount(
        DiscountDraftInput(
          restaurantId: restaurantDraft.restaurantId,
          code: 'LOCAL10',
          description: 'Ten percent off selected dishes',
          redemptionTerms: 'Show the code before ordering. Exclusions apply.',
          startsAt: DateTime.now().subtract(const Duration(minutes: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        ),
      );
      expect(discount.isCurrentlyActive, isTrue);
      expect(await localEats.fetchOwnedDiscounts(), hasLength(1));
      final paused = await localEats.transitionDiscount(
        discount: discount,
        action: 'pause',
      );
      expect(paused.status, 'paused');
      await expectLater(
        localEats.transitionDiscount(
          discount: discount,
          action: 'resume',
        ),
        throwsA(isA<AppException>()),
      );
      final resumed = await localEats.transitionDiscount(
        discount: paused,
        action: 'resume',
      );
      expect(resumed.status, 'active');
      final revoked = await localEats.transitionDiscount(
        discount: resumed,
        action: 'revoke',
      );
      expect(revoked.status, 'revoked');
    });

    test('demo adapter rejects invalid image content and social URL', () async {
      final auth = DemoAuthRepository();
      await auth.signIn(
        email: 'foodie@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final repository = DemoLocalEatsRepository(auth);
      const deceptiveInput = RestaurantDraftInput(
        name: 'Unsafe Test Listing',
        address: '99 Test Street',
        state: 'Selangor',
        city: 'Petaling Jaya',
        cuisineType: 'Fusion',
        priceRange: r'$',
        reviewedDishes: 'A test dish',
        socialMediaUrl: 'https://instagram.com.evil.test/deceptive',
      );

      expect(
        () => repository.createRestaurantDraft(
          input: deceptiveInput,
          imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
          imageMimeType: 'image/jpeg',
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () => repository.createRestaurantDraft(
          input: const RestaurantDraftInput(
            name: 'Unsafe Test Listing',
            address: '99 Test Street',
            state: 'Selangor',
            city: 'Petaling Jaya',
            cuisineType: 'Fusion',
            priceRange: r'$',
            reviewedDishes: 'A test dish',
            socialMediaUrl: 'https://instagram.com/safe-host',
          ),
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageMimeType: 'image/jpeg',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
