import 'dart:typed_data';

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
      email: 'tourist@livelocal.com',
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
      imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      imageMimeType: 'image/jpeg',
      imageRightsConfirmed: true,
    );

    expect(result, isNotNull);
    expect(result!.probableDuplicates, isNotEmpty);
    expect(controller.pendingSpots, isEmpty);

    expect(await controller.discardDraft(result), isTrue);
  });

  test('photo rights are required before a draft is created', () async {
    final result = await controller.submitDraft(
      input: const SpotDraftInput(
        name: 'Consent Test Garden',
        category: 'Park / Walkway',
        description: 'A sufficiently detailed place description for testing.',
        state: 'Penang',
        city: 'George Town',
        address: '8 Consent Test Road, George Town',
        priceRange: r'$',
        bestTime: 'Morning',
        thingsToDo: 'Walk through the garden',
      ),
      imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      imageMimeType: 'image/jpeg',
      imageRightsConfirmed: false,
    );

    expect(result, isNull);
    expect(controller.errorMessage, contains('confirm'));
    expect(controller.pendingSpots, isEmpty);
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
      imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      imageMimeType: 'image/jpeg',
      imageRightsConfirmed: true,
    );

    expect(result, isNotNull);
    expect(result!.probableDuplicates, isEmpty);
    expect(controller.pendingSpots.single.submittedBy, 'usr-tourist-1');
  });

  test('approved spot stays public while its owner revision is reviewed',
      () async {
    final original = await controller.submitDraft(
      input: const SpotDraftInput(
        name: 'Owner Revision Garden',
        category: 'Park / Walkway',
        description:
            'A detailed original place description for revision testing.',
        state: 'Penang',
        city: 'George Town',
        address: '81 Owner Revision Road, George Town',
        priceRange: r'$',
        bestTime: 'Morning',
        thingsToDo: 'Walk through the original garden',
      ),
      imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      imageMimeType: 'image/jpeg',
      imageRightsConfirmed: true,
    );
    expect(original, isNotNull);
    final originalDraft = original!;

    await authRepository.signOut();
    await authRepository.signIn(
      email: 'admin@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    await controller.loadPendingSpots();
    await controller.approveSpotWithReason(
      controller.pendingSpots.singleWhere(
        (spot) => spot.id == originalDraft.spotId,
      ),
      'Original details verified.',
    );

    await authRepository.signOut();
    await authRepository.signIn(
      email: 'tourist@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    await controller.loadOwnedSubmissions();
    final source = controller.ownedSubmissions.singleWhere(
      (spot) => spot.id == originalDraft.spotId,
    );
    final revision = await controller.reviseAndSubmit(
      source: source,
      input: SpotDraftInput(
        name: 'Revised Owner Garden',
        category: source.category,
        description:
            'A detailed revised place description requiring another review.',
        state: source.state,
        city: source.city,
        address: source.address,
        priceRange: source.priceRange,
        bestTime: 'Late morning',
        thingsToDo: 'Walk through the revised garden',
      ),
      imageRightsConfirmed: true,
    );
    expect(revision, isNotNull);
    final revisedDraft = revision!;
    expect(
      controller.ownedSubmissions
          .singleWhere((spot) => spot.id == originalDraft.spotId)
          .status,
      'submitted',
    );
    await controller.loadSpots();
    expect(
      controller.approvedSpots
          .singleWhere((spot) => spot.id == originalDraft.spotId)
          .name,
      'Owner Revision Garden',
    );

    await authRepository.signOut();
    await authRepository.signIn(
      email: 'admin@livelocal.com',
      password: SeedDataService.demoPassword,
    );
    await controller.loadPendingSpots();
    await controller.approveSpotWithReason(
      controller.pendingSpots.singleWhere(
        (spot) => spot.revisionId == revisedDraft.revisionId,
      ),
      'Revised details verified.',
    );
    expect(
      controller.approvedSpots
          .singleWhere((spot) => spot.id == originalDraft.spotId)
          .name,
      'Revised Owner Garden',
    );
  });

  test('owner can withdraw a pending spot without deleting its history',
      () async {
    final draft = await controller.submitDraft(
      input: const SpotDraftInput(
        name: 'Withdrawal Test Garden',
        category: 'Park / Walkway',
        description: 'A detailed submission used to verify owner withdrawal.',
        state: 'Penang',
        city: 'George Town',
        address: '82 Withdrawal Test Road, George Town',
        priceRange: r'$',
        bestTime: 'Morning',
        thingsToDo: 'Walk through the withdrawal test garden',
      ),
      imageBytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
      imageMimeType: 'image/jpeg',
      imageRightsConfirmed: true,
    );
    expect(draft, isNotNull);
    final submittedDraft = draft!;
    await controller.loadOwnedSubmissions();
    final pending = controller.ownedSubmissions.singleWhere(
      (spot) => spot.id == submittedDraft.spotId,
    );

    expect(await controller.withdrawSubmission(pending), isTrue);
    expect(
      controller.ownedSubmissions
          .singleWhere((spot) => spot.id == submittedDraft.spotId)
          .status,
      'withdrawn',
    );
  });
}
