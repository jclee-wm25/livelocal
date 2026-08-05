import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/controllers/admin_controller.dart';
import 'package:live_local/controllers/auth_controller.dart';
import 'package:live_local/controllers/guide_controller.dart';
import 'package:live_local/controllers/itinerary_controller.dart';
import 'package:live_local/controllers/localeats_controller.dart';
import 'package:live_local/controllers/review_controller.dart';
import 'package:live_local/controllers/spot_controller.dart';
import 'package:live_local/models/spot_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences.setMockInitialValues({});

  group('LiveLocal System Integration Tests', () {
    test('Module 1: Auth and Role Switching', () async {
      final authCtrl = AuthController();

      final loginSuccess = await authCtrl.login(
        'tourist@livelocal.my',
        'password',
      );

      expect(loginSuccess, isTrue);
      expect(authCtrl.isAuthenticated, isTrue);

      authCtrl.setRole('influencer');
      expect(authCtrl.currentUser?.role, 'influencer');

      authCtrl.setRole('admin');
      expect(authCtrl.currentUser?.role, 'admin');
    });

    test('Module 2: Local Spots Filtering and Approval Flow', () async {
      final spotCtrl = SpotController();

      await spotCtrl.loadSpots();

      expect(spotCtrl.approvedSpots.isNotEmpty, isTrue);

      spotCtrl.filter(state: 'Penang');

      expect(
        spotCtrl.approvedSpots.every(
          (spot) => spot.state == 'Penang',
        ),
        isTrue,
      );

      spotCtrl.resetFilters();

      final testSpotId = 'spot-test-${DateTime.now().microsecondsSinceEpoch}';

      final newSpot = SpotModel(
        id: testSpotId,
        name: 'Test Kopitiam',
        category: 'Kopitiam',
        description: 'Test Kopitiam description',
        state: 'Penang',
        city: 'George Town',
        address: '123 Test Street',
        priceRange: '\$',
        bestTime: '8:00 AM',
        thingsToDo: 'Drink kopi',
        imageUrl: 'https://example.com/test.jpg',
        submittedBy: 'usr-tourist-1',
        status: 'pending',
      );

      await spotCtrl.submitSpot(newSpot);

      expect(
        spotCtrl.pendingSpots.any(
          (spot) => spot.id == testSpotId,
        ),
        isTrue,
      );

      await spotCtrl.approveSpot(
        testSpotId,
        'admin',
      );

      expect(
        spotCtrl.approvedSpots.any(
          (spot) => spot.id == testSpotId,
        ),
        isTrue,
      );
    });

    test('Module 3: LocalEats and Discount Codes', () async {
      final foodCtrl = LocalEatsController();

      await foodCtrl.loadData();

      expect(foodCtrl.restaurants.isNotEmpty, isTrue);
      expect(foodCtrl.discountCodes.isNotEmpty, isTrue);

      final restaurant = foodCtrl.restaurants.first;

      final discounts = foodCtrl.getActiveDiscountsForRestaurant(
        restaurant.id,
      );

      expect(
        discounts.every(
          (discount) => !discount.isExpired,
        ),
        isTrue,
      );
    });

    test('Module 4: Saved Places and Smart Itinerary Routing', () async {
      final itineraryCtrl = ItineraryController();

      await itineraryCtrl.loadSavedPlaces('usr-tourist-1');

      final routableSpot = SpotModel(
        id: 'route-test-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Test Route Location',
        category: 'Attraction',
        description: 'Location used for itinerary testing',
        state: 'Penang',
        city: 'George Town',
        address: 'Test Address',
        priceRange: '\$',
        bestTime: 'Morning',
        thingsToDo: 'Walk around',
        imageUrl: 'https://example.com/route.jpg',
        submittedBy: 'usr-tourist-1',
        status: 'approved',
        latitude: 5.4141,
        longitude: 100.3288,
      );

      await itineraryCtrl.toggleSave(
        'usr-tourist-1',
        spotId: routableSpot.id,
      );

      expect(
        itineraryCtrl.isSaved(
          'usr-tourist-1',
          spotId: routableSpot.id,
        ),
        isTrue,
      );

      await itineraryCtrl.generateProximityItinerary(
        [routableSpot],
        [],
      );

      expect(
        itineraryCtrl.itinerarySteps.isNotEmpty,
        isTrue,
      );

      expect(
        itineraryCtrl.itinerarySteps.first['title'],
        routableSpot.name,
      );
    });

    test('Module 5: Neighbourhood Explorer Guides', () async {
      final guideCtrl = GuideController();

      await guideCtrl.loadGuides();

      expect(guideCtrl.approvedGuides.isNotEmpty, isTrue);

      final guide = guideCtrl.approvedGuides.first;

      expect(guide.stops.isNotEmpty, isTrue);
      expect(guide.walkingSequence.isNotEmpty, isTrue);
    });

    test('Module 6: Community Reviews and Admin Moderation', () async {
      final reviewCtrl = ReviewController();
      final adminCtrl = AdminController();

      await reviewCtrl.loadReviews();
      await adminCtrl.loadUsers('admin');

      expect(adminCtrl.totalUsers, greaterThan(0));

      const testComment = 'Awesome place integration test';

      await reviewCtrl.addReview(
        spotId: 'spot-001',
        userId: 'usr-tourist-1',
        userName: 'Test User',
        rating: 5.0,
        comment: testComment,
      );

      final reviews = reviewCtrl.getReviewsForSpot('spot-001');

      expect(
        reviews.any(
          (review) => review.comment == testComment,
        ),
        isTrue,
      );
    });
  });
}
