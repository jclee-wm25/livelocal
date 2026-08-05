import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/app/theme/app_theme.dart';
import 'package:live_local/shared/presentation/app_state_view.dart';

void main() {
  test('interactive theme controls preserve 48 pixel minimum targets', () {
    final theme = AppTheme.light;
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(48),
    );
    expect(
      theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(48),
    );
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('shared state view remains usable at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: AppStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Places could not be loaded',
            message:
                'Check your connection and try again without losing context.',
            actionLabel: 'Try again',
            onAction: () {},
            scrollable: true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    expect(tester.takeException(), isNull);
  });
}
