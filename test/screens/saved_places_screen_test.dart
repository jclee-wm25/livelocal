import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/controllers/auth_controller.dart';
import 'package:live_local/controllers/itinerary_controller.dart';
import 'package:live_local/controllers/localeats_controller.dart';
import 'package:live_local/controllers/spot_controller.dart';
import 'package:live_local/core/routing/protected_navigation.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/itinerary/data/demo_saved_itinerary_repository.dart';
import 'package:live_local/features/restaurants/data/demo_local_eats_repository.dart';
import 'package:live_local/features/spots/data/demo_spot_repository.dart';
import 'package:live_local/screens/saved_places_screen.dart';
import 'package:live_local/services/seed_data_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('saved-place filters use persisted spot and restaurant data',
      (tester) async {
    final authRepository = DemoAuthRepository();
    await authRepository.signIn(
      email: 'tourist@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    final authController = AuthController(repository: authRepository);
    await authController.initialize();

    final spotRepository = DemoSpotRepository(authRepository);
    final restaurantRepository = DemoLocalEatsRepository(authRepository);
    final savedRepository = DemoSavedItineraryRepository(authRepository);
    final spot = SeedDataService.getInitialSpots().first;
    final restaurant = SeedDataService.getInitialRestaurants().first;
    await savedRepository.setSaved(
      targetType: 'spot',
      targetId: spot.id,
      saved: true,
    );
    await savedRepository.setSaved(
      targetType: 'restaurant',
      targetId: restaurant.id,
      saved: true,
    );

    final spotController = SpotController(repository: spotRepository);
    final restaurantController =
        LocalEatsController(repository: restaurantRepository);
    final itineraryController =
        ItineraryController(repository: savedRepository);
    await Future.wait([
      spotController.loadSpots(),
      restaurantController.loadData(),
      itineraryController.loadSavedPlaces(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authController),
          ChangeNotifierProvider.value(value: spotController),
          ChangeNotifierProvider.value(value: restaurantController),
          ChangeNotifierProvider.value(value: itineraryController),
          Provider(create: (_) => ProtectedNavigation()),
        ],
        child: const MaterialApp(home: SavedPlacesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 saved places'), findsOneWidget);
    expect(find.text(spot.name), findsOneWidget);
    expect(find.text(restaurant.name), findsOneWidget);

    await tester.tap(find.text('Spots'));
    await tester.pumpAndSettle();
    expect(find.text(spot.name), findsOneWidget);
    expect(find.text(restaurant.name), findsNothing);

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();
    expect(find.text(spot.name), findsNothing);
    expect(find.text(restaurant.name), findsOneWidget);
  });
}
