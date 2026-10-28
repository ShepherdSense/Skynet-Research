import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainregs/airspace/airspace_grid.dart';
import 'package:plainregs/airspace/airspace_service.dart';
import 'package:plainregs/airspace/location_provider.dart';
import 'package:plainregs/app.dart';
import 'package:plainregs/app_services.dart';
import 'package:plainregs/flycheck/fly_check.dart';
import 'package:plainregs/models/models.dart';
import 'package:plainregs/screens/fly_check_screen.dart';
import 'package:plainregs/screens/reader_screen.dart';
import 'package:plainregs/screens/shepherd_screen.dart';
import 'package:plainregs/services/sample_source.dart';
import 'package:plainregs/services/stub_simplification_service.dart';
import 'package:plainregs/state/bookmarks_store.dart';

AppServices _services() => AppServices(
  sources: [SampleSource()],
  simplifier: StubSimplificationService(),
  bookmarks: BookmarksStore(),
);

/// Services whose airspace checker resolves a fix at KFAY into a
/// 200-foot grid cell — the full offline path, faked only at the GPS.
AppServices _servicesWithGrid() {
  final cell = AirspaceGrid.cellOf(35.0625, -78.8792);
  return AppServices(
    sources: [SampleSource()],
    simplifier: StubSimplificationService(),
    bookmarks: BookmarksStore(),
    airspace: AirspaceService(
      locationProvider: const FakeLocationProvider(
        LocationFound(35.0625, -78.8792),
      ),
      loadGrid: () async => AirspaceGrid.fromCells({cell: 200}),
      loadInfo: () async => const AirspaceGridInfo(
        mapEffective: '10/1/2026',
        generatedOn: '2026-10-23',
        cells: 1,
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Without a mock, SharedPreferences.getInstance() never completes in
    // the test environment and any test awaiting it hangs forever.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app shell shows Search / Browse / Bookmarks and samples', (
    tester,
  ) async {
    await tester.pumpWidget(PlainRegsApp(services: _services()));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    // The landing page carries the colorway slider at the bottom.
    expect(find.text('Site color'), findsOneWidget);
    // First-run offline examples are in the (scrollable) list.
    await tester.dragUntilVisible(
      find.text('14 CFR 107.51'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    expect(find.text('14 CFR 107.51'), findsWidgets);
  });

  testWidgets(
    'reader shows original by default and plain view carries the disclaimer',
    (tester) async {
      final services = _services();
      const ref = RegulationRef(
        sourceId: 'sample',
        titleNumber: 14,
        part: '107',
        section: '107.51',
        heading: 'Operating limitations for small unmanned aircraft.',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(services: services, ref: ref),
        ),
      );
      await tester.pumpAndSettle();

      // Original first.
      expect(find.textContaining('87 knots'), findsWidgets);

      // Switch to Plain English: disclaimer must be on screen.
      await tester.tap(find.text('Plain English'));
      await tester.pumpAndSettle();
      expect(find.text(Simplification.disclaimer), findsOneWidget);
      expect(find.textContaining('100 miles per hour'), findsWidgets);
      // And a route back to the original is always present.
      expect(find.text('Read the original text'), findsOneWidget);
    },
  );

  testWidgets('can-i-fly result shows verdict, cited rule, and disclaimer', (
    tester,
  ) async {
    final services = _services();
    final answers = FlyAnswers()
      ..purpose = FlyPurpose.work
      ..weight = WeightClass.between250gAnd55lb
      ..registered = TriState.yes
      ..credential = TriState.no
      ..remoteId = RemoteIdStatus.builtIn
      ..airspace = AirspaceClass.uncontrolled
      ..above400 = false
      ..keepInSight = true
      ..overPeople = false
      ..atNight = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlyResultView(
            services: services,
            result: evaluateFlyCheck(answers),
            onRestart: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not yet — fix these first'), findsOneWidget);
    expect(find.text('You need a Remote Pilot certificate'), findsOneWidget);
    expect(find.text('14 CFR 107.61'), findsOneWidget);
    // The guidance disclaimer is always on the result (scroll to it —
    // the result is a lazy ListView).
    await tester.scrollUntilVisible(
      find.textContaining('not an FAA authorization'),
      200,
    );
    expect(find.textContaining('not an FAA authorization'), findsOneWidget);
  });

  testWidgets('wizard airspace step: grid check fills in the LAANC ceiling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FlyCheckScreen(services: _servicesWithGrid())),
    );
    await tester.pumpAndSettle();

    // purpose -> weight (heavy, so registration/credential/remoteId show)
    await tester.tap(find.text('For Fun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('0.55 to 55 pounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.55 to 55 pounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> registration
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> credential
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> remoteId
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> airspace
    await tester.pumpAndSettle();

    expect(find.text('Use my location'), findsOneWidget);
    await tester.ensureVisible(find.text('Use my location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LAANC grid ceiling 200 feet'), findsOneWidget);
    // Grid provenance stamp shows with the result.
    expect(find.textContaining('effective 10/1/2026'), findsOneWidget);
  });

  testWidgets('wizard plan step asks the southern border question', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FlyCheckScreen(services: _services())),
    );
    await tester.pumpAndSettle();

    // Light recreational: registration and Remote ID steps are skipped.
    await tester.tap(find.text('For Fun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> weight
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under 0.55 pounds (250 grams)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> credential
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> airspace
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> plan
    await tester.pumpAndSettle();

    expect(find.text('About this flight:'), findsOneWidget);
    expect(
      find.text(
        'Will you fly within 1 nautical mile north of the '
        'U.S.-Mexico border?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('wizard airspace step asks work flyers about tower inspections',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FlyCheckScreen(services: _services())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commercial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> weight
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.55 to 55 pounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> registration
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> credential
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> remoteId
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next')); // -> airspace
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Are you inspecting a vertical structure (tower, '
        'high-rise) above the LAANC grid ceiling?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shepherd flow: group, munitions, location -> fused summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShepherdScreen(services: _servicesWithGrid())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Group 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Yes — live munitions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fused summary'), findsOneWidget);
    expect(find.textContaining('LAANC grid ceiling'), findsOneWidget);
    // The munitions section sits below the fold in the summary ListView.
    await tester.scrollUntilVisible(
      find.text('Live munitions — Department of War rules'),
      200,
    );
    expect(
      find.text('Live munitions — Department of War rules'),
      findsOneWidget,
    );
    expect(
      find.textContaining('never authorized by civil drone rules'),
      findsOneWidget,
    );
  });

  testWidgets('shepherd manual location entry validates bad coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShepherdScreen(services: _servicesWithGrid())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Group 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('No — unarmed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Latitude'),
      'not-a-number',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Longitude'),
      '-78.87',
    );
    await tester.tap(find.text('Check this location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter valid coordinates'), findsOneWidget);
    // Still on the location step — no summary was fabricated.
    expect(find.textContaining('Fused summary'), findsNothing);
  });

  testWidgets('bookmark toggle adds and removes', (tester) async {
    final store = BookmarksStore();
    const ref = RegulationRef(
      sourceId: 'sample',
      titleNumber: 14,
      part: '107',
      section: '107.51',
      heading: 'x',
    );
    expect(store.isBookmarked(ref), isFalse);
    await store.toggle(ref);
    expect(store.isBookmarked(ref), isTrue);
    await store.toggle(ref);
    expect(store.isBookmarked(ref), isFalse);
  });
}
