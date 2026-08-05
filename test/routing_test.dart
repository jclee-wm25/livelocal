import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/models/spot_model.dart';
import 'package:live_local/models/restaurant_model.dart';
import 'package:live_local/services/location_service.dart';

void main() {
  group('NearestNeighborRouting', () {
    late NearestNeighborRouting routingStrategy;

    setUp(() {
      routingStrategy = NearestNeighborRouting();
    });

    SpotModel createSpot(String id, double? lat, double? lng) {
      return SpotModel(
        id: id,
        name: 'Spot $id',
        category: 'Test',
        description: 'Test',
        state: 'Test State',
        city: 'Test City',
        address: 'Test Address',
        priceRange: '\$',
        bestTime: 'Morning',
        thingsToDo: 'Test',
        imageUrl: '',
        submittedBy: 'test_user',
        latitude: lat,
        longitude: lng,
      );
    }

    RestaurantModel createRestaurant(String id, double? lat, double? lng) {
      return RestaurantModel(
        id: id,
        name: 'Rest $id',
        address: 'Test',
        state: 'Test',
        city: 'Test',
        cuisineType: 'Test',
        priceRange: '\$',
        reviewedDishes: 'Test',
        influencerId: 'Test',
        influencerName: 'Test',
        socialMediaUrl: 'Test',
        coverPhotoUrl: '',
        latitude: lat,
        longitude: lng,
      );
    }

    test('Test 0 locations returns empty route', () {
      final route = routingStrategy.calculateRoute(3.0, 101.0, [], []);
      expect(route, isEmpty);
    });

    test('Test 1 location returns that single location', () {
      final spot = createSpot('s1', 3.1, 101.1);
      final route = routingStrategy.calculateRoute(3.0, 101.0, [spot], []);

      expect(route.length, 1);
      expect(route[0]['type'], 'Spot');
      expect((route[0]['item'] as SpotModel).id, 's1');
    });

    test('Test multiple locations sorts correctly based on proximity', () {
      // Start is at (0, 0)
      // s1 is at (0, 1) -> distance ~111km
      // s2 is at (0, 3) -> distance ~333km
      // r1 is at (0, 2) -> distance ~222km

      final spot1 = createSpot('s1', 0.0, 1.0);
      final spot2 = createSpot('s2', 0.0, 3.0);
      final rest1 = createRestaurant('r1', 0.0, 2.0);

      final route =
          routingStrategy.calculateRoute(0.0, 0.0, [spot1, spot2], [rest1]);

      expect(route.length, 3);
      expect((route[0]['item'] as SpotModel).id, 's1');
      expect((route[1]['item'] as RestaurantModel).id, 'r1');
      expect((route[2]['item'] as SpotModel).id, 's2');
    });

    test('Test identical coordinates handles gracefully', () {
      final spot1 = createSpot('s1', 1.0, 1.0);
      final spot2 = createSpot('s2', 1.0, 1.0);

      final route =
          routingStrategy.calculateRoute(1.0, 1.0, [spot1, spot2], []);

      expect(route.length, 2);
      // Both are at the same point, order between them doesn't mathematically matter,
      // but it shouldn't crash.
    });

    test('Test missing coordinates are ignored (fallback behavior)', () {
      final spot1 = createSpot('s1', null, null); // Missing
      final spot2 = createSpot('s2', 0.0, 1.0); // Has coords

      final route =
          routingStrategy.calculateRoute(0.0, 0.0, [spot1, spot2], []);

      // Only spot2 should be included in the routing
      expect(route.length, 1);
      expect((route[0]['item'] as SpotModel).id, 's2');
    });
  });
}
