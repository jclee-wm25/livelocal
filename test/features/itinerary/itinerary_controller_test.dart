import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/controllers/itinerary_controller.dart';
import 'package:live_local/core/errors/app_exception.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/itinerary/data/demo_saved_itinerary_repository.dart';
import 'package:live_local/features/itinerary/domain/saved_itinerary_repository.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  group('saved places and itineraries', () {
    test('save is user-scoped, idempotent, and persisted into an itinerary',
        () async {
      final auth = DemoAuthRepository();
      await auth.signIn(
        email: 'tourist@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final repository = DemoSavedItineraryRepository(auth);
      final controller = ItineraryController(repository: repository);
      final spot = SeedDataService.getInitialSpots().first;

      expect(await controller.toggleSave(spotId: spot.id), isTrue);
      await repository.setSaved(
        targetType: 'spot',
        targetId: spot.id,
        saved: true,
      );
      await controller.loadSavedPlaces();
      expect(controller.savedPlaces, hasLength(1));
      expect(controller.isSaved(spotId: spot.id), isTrue);

      const origin = RouteOrigin(
        label: 'George Town, Penang',
        latitude: 5.4141,
        longitude: 100.3288,
        mode: 'manual',
        state: 'Penang',
        city: 'George Town',
      );
      final created = await controller.generateAndSaveItinerary(
        title: 'Penang morning',
        origin: origin,
        allSpots: SeedDataService.getInitialSpots(),
        allRestaurants: SeedDataService.getInitialRestaurants(),
      );
      expect(created, isTrue);
      expect(controller.itinerarySteps, hasLength(1));
      expect(controller.savedItineraries, hasLength(1));
      expect(repository.locationPreferenceForDemo?.mode, 'manual');

      await auth.signOut();
      await auth.signIn(
        email: 'admin@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      await controller.loadSavedPlaces();
      expect(controller.savedPlaces, isEmpty);
    });

    test('an itinerary cannot use a place the account has not saved', () async {
      final auth = DemoAuthRepository();
      await auth.signIn(
        email: 'tourist@livelocal.my',
        password: SeedDataService.demoPassword,
      );
      final repository = DemoSavedItineraryRepository(auth);
      expect(
        () => repository.createItinerary(
          title: 'Invalid route',
          origin: const RouteOrigin(
            label: 'Ipoh, Perak',
            latitude: 4.5975,
            longitude: 101.0901,
            mode: 'manual',
          ),
          orderedTargets: const [
            ItineraryTarget(type: 'spot', id: 'spot-001'),
          ],
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
