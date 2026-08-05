import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/spots/data/demo_spot_repository.dart';
import 'package:live_local/features/spots/domain/spot_repository.dart';
import 'package:live_local/features/spots/presentation/spot_controller.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  late DemoAuthRepository authRepository;
  late SpotController controller;

  setUp(() async {
    authRepository = DemoAuthRepository();
    await authRepository.signIn(
      email: 'tourist@livelocal.my',
      password: SeedDataService.demoPassword,
    );
    controller = SpotController(
      repository: DemoSpotRepository(authRepository),
    );
    await controller.loadSpots();
  });

  test('probable duplicate remains a draft until resolved', () async {
    final result = await controller.submitDraft(
      input: const SpotDraftInput(
        name: 'Chop Seng Hin Kopitiam',
        category: 'Kopitiam',
        description: 'A sufficiently detailed duplicate spot description.',
        state: 'Penang',
        city: 'George Town',
        address: '142 Lebuh Carnarvon, 10100 George Town, Pulau Pinang',
        priceRange: r'$',
        bestTime: 'Morning',
        thingsToDo: 'Try local coffee',
      ),
    );

    expect(result, isNotNull);
    expect(result!.probableDuplicates, isNotEmpty);
    expect(controller.pendingSpots, isEmpty);

    expect(await controller.discardDraft(result), isTrue);
  });

  test('new spot is submitted without trusting a client actor id', () async {
    final result = await controller.submitDraft(
      input: const SpotDraftInput(
        name: 'Community Test Garden',
        category: 'Park / Walkway',
        description: 'A quiet community garden with shaded walking paths.',
        state: 'Penang',
        city: 'George Town',
        address: '999 New Test Road, George Town',
        priceRange: r'$',
        bestTime: 'Early morning',
        thingsToDo: 'Walk and enjoy the garden',
      ),
    );

    expect(result, isNotNull);
    expect(result!.probableDuplicates, isEmpty);
    expect(controller.pendingSpots.single.submittedBy, 'usr-tourist-1');
  });
}
