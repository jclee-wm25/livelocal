import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/controllers/auth_controller.dart';
import 'package:live_local/controllers/spot_controller.dart';
import 'package:live_local/controllers/localeats_controller.dart';
import 'package:live_local/controllers/itinerary_controller.dart';
import 'package:live_local/controllers/guide_controller.dart';
import 'package:live_local/controllers/review_controller.dart';
import 'package:live_local/models/spot_model.dart';
import 'package:live_local/repositories/supabase_repository.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/spots/data/demo_spot_repository.dart';
import 'package:live_local/features/spots/domain/spot_repository.dart';
import 'package:live_local/features/reviews/data/demo_review_repository.dart';
import 'package:live_local/features/restaurants/data/demo_local_eats_repository.dart';
import 'package:live_local/features/itinerary/data/demo_saved_itinerary_repository.dart';
import 'package:live_local/features/guides/data/demo_guide_repository.dart';

void main() {
  setUpAll(() {
    SupabaseRepository().configureForDemo();
  });

  group('LiveLocal System Integration Tests', () {
    test('Module 1: demo fixture login preserves the stored tourist role',
        () async {
      final authCtrl = AuthController(repository: DemoAuthRepository());
      await authCtrl.login('tourist@livelocal.my', 'DemoOnly123!');
      expect(authCtrl.isAuthenticated, isTrue);
      expect(authCtrl.currentUser?.role, 'tourist');
    });

    test('Module 2: Local Spots Filtering & Submission Flow', () async {
      final authRepository = DemoAuthRepository();
      await authRepository.signIn(
        email: 'tourist@livelocal.my',
        password: 'DemoOnly123!',
      );
      final spotCtrl = SpotController(
        repository: DemoSpotRepository(authRepository),
      );
      await spotCtrl.loadSpots();

      final initialApprovedCount = spotCtrl.approvedSpots.length;
      expect(initialApprovedCount, greaterThan(0));

      spotCtrl.filter(state: 'Penang');
      expect(spotCtrl.approvedSpots.every((s) => s.state == 'Penang'), isTrue);

      spotCtrl.resetFilters();

      // Submit new spot
      final newSpot = SpotModel(
        id: 'spot-test-1',
        name: 'Test Kopitiam',
        category: 'Kopitiam',
        description: 'Test Kopitiam description',
        state: 'Penang',
        city: 'George Town',
        address: '123 Test St',
        priceRange: '\$',
        bestTime: '8:00 AM',
        thingsToDo: 'Drink kopi',
        imageUrl: 'https://example.com/test.jpg',
        submittedBy: 'usr-1',
        status: 'pending',
      );

      final submitted = await spotCtrl.submitDraft(
        input: SpotDraftInput(
          name: newSpot.name,
          category: newSpot.category,
          description: newSpot.description,
          state: newSpot.state,
          city: newSpot.city,
          address: newSpot.address,
          priceRange: newSpot.priceRange,
          bestTime: newSpot.bestTime,
          thingsToDo: newSpot.thingsToDo,
          latitude: newSpot.latitude,
          longitude: newSpot.longitude,
        ),
        imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        imageMimeType: 'image/jpeg',
        imageRightsConfirmed: true,
      );
      expect(submitted, isNotNull);
      expect(
        spotCtrl.pendingSpots.any((s) => s.name == 'Test Kopitiam'),
        isTrue,
      );
      expect(
        spotCtrl.pendingSpots.every((s) => s.id != 'spot-test-1'),
        isTrue,
        reason: 'The repository, not the client, assigns persisted IDs.',
      );

      // Admin authorization is deliberately not characterized here. The
      // current client-role contract is not production authorization and will
      // be replaced by a server-side RPC/RLS flow in Phase 5.
    });

    test('Module 3: LocalEats & Discount Codes', () async {
      final authRepository = DemoAuthRepository();
      final foodCtrl = LocalEatsController(
        repository: DemoLocalEatsRepository(authRepository),
      );
      await foodCtrl.loadData();

      expect(foodCtrl.restaurants.isNotEmpty, isTrue);
      expect(foodCtrl.discountCodes.isNotEmpty, isTrue);

      final rest = foodCtrl.restaurants.first;
      final discounts = foodCtrl.getActiveDiscountsForRestaurant(rest.id);
      expect(discounts.every((d) => !d.isExpired), isTrue);
    });

    test('Module 4: Saved Places', () async {
      final authRepository = DemoAuthRepository();
      await authRepository.signIn(
        email: 'tourist@livelocal.my',
        password: 'DemoOnly123!',
      );
      final itineraryCtrl = ItineraryController(
        repository: DemoSavedItineraryRepository(authRepository),
      );
      final spotCtrl = SpotController(
        repository: DemoSpotRepository(authRepository),
      );
      final foodCtrl = LocalEatsController(
        repository: DemoLocalEatsRepository(authRepository),
      );

      await spotCtrl.loadSpots();
      await foodCtrl.loadData();
      await itineraryCtrl.loadSavedPlaces();

      final spotId = spotCtrl.approvedSpots.first.id;
      await itineraryCtrl.toggleSave(spotId: spotId);

      expect(itineraryCtrl.isSaved(spotId: spotId), isTrue);

      expect(itineraryCtrl.savedPlaces, isNotEmpty);
    });

    test('Module 5: Neighbourhood Explorer Guides', () async {
      final guideCtrl = GuideController(
        repository: DemoGuideRepository(DemoAuthRepository()),
      );
      await guideCtrl.loadGuides();

      expect(guideCtrl.approvedGuides.isNotEmpty, isTrue);
      final guide = guideCtrl.approvedGuides.first;
      expect(guide.stops.isNotEmpty, isTrue);
      expect(guide.walkingSequence.isNotEmpty, isTrue);
    });

    test('Module 6: Community review validation and storage', () async {
      final authRepository = DemoAuthRepository();
      await authRepository.signIn(
        email: 'tourist@livelocal.my',
        password: 'DemoOnly123!',
      );
      final reviewCtrl = ReviewController(
        repository: DemoReviewRepository(authRepository),
      );

      await reviewCtrl.loadReviews();

      // Add review
      await reviewCtrl.addReview(
        spotId: 'spot-001',
        rating: 5.0,
        comment: 'Awesome place!',
      );

      final reviews = reviewCtrl.getReviewsForSpot('spot-001');
      expect(reviews.any((r) => r.comment == 'Awesome place!'), isTrue);
    });
  });
}
