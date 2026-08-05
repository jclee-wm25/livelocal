import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/features/auth/data/demo_auth_repository.dart';
import 'package:live_local/features/guides/data/demo_guide_repository.dart';
import 'package:live_local/features/guides/domain/guide_repository.dart';
import 'package:live_local/features/guides/presentation/guide_controller.dart';
import 'package:live_local/services/seed_data_service.dart';

void main() {
  const draftInput = GuideDraftInput(
    title: 'Brickfields morning walk',
    locationName: 'Brickfields',
    state: 'Kuala Lumpur',
    routeOverview:
        'A calm, accessible morning route through food and heritage stops.',
    stops: ['Breakfast stop', 'Heritage street'],
    walkingSequence: ['Start at breakfast', 'Continue to heritage street'],
    estimatedDuration: '2 hours',
  );

  test('only an active admin can create and publish a guide revision',
      () async {
    final authRepository = DemoAuthRepository();
    final repository = DemoGuideRepository(authRepository);
    final controller = GuideController(repository: repository);

    await authRepository.signIn(
      email: 'tourist@livelocal.my',
      password: SeedDataService.demoPassword,
    );
    expect(await controller.createDraft(draftInput), isFalse);
    expect(controller.errorMessage, contains('Administrator'));

    await authRepository.signIn(
      email: 'admin@livelocal.my',
      password: SeedDataService.demoPassword,
    );
    expect(await controller.createDraft(draftInput), isTrue);
    final draft = controller.adminDrafts.singleWhere(
      (guide) => guide.title == draftInput.title,
    );
    expect(draft.status, 'draft');

    expect(await controller.publishDraft(draft, 'Editorial review complete'),
        isTrue);
    expect(
      controller.guides.any(
        (guide) =>
            guide.id == draft.id &&
            guide.status == 'approved' &&
            guide.version == 2,
      ),
      isTrue,
    );

    expect(
      await controller.publishDraft(draft, 'Attempt duplicate publication'),
      isFalse,
    );
    expect(controller.errorMessage, contains('changed'));

    final published = controller.guides.singleWhere(
      (guide) => guide.id == draft.id,
    );
    expect(
      await controller.createDraft(
        const GuideDraftInput(
          title: 'Brickfields accessible morning walk',
          locationName: 'Brickfields',
          state: 'Kuala Lumpur',
          routeOverview:
              'A revised accessible route through food and heritage stops.',
          stops: ['Breakfast stop', 'Accessible heritage street'],
          walkingSequence: [
            'Start at breakfast',
            'Continue along the accessible path'
          ],
          estimatedDuration: '2 hours',
        ),
        guide: published,
      ),
      isTrue,
    );
    final revision = controller.adminDrafts.singleWhere(
      (guide) => guide.id == published.id,
    );
    expect(revision.version, 3);
    expect(
      await controller.publishDraft(revision, 'Revised route verified'),
      isTrue,
    );
    final revised = controller.guides.singleWhere(
      (guide) => guide.id == published.id,
    );
    expect(revised.version, 4);
    expect(
      await controller.archiveGuide(revised, 'Route is no longer current'),
      isTrue,
    );
    expect(controller.guides.where((guide) => guide.id == revised.id), isEmpty);
  });
}
