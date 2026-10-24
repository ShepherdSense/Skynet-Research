import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainregs/app_services.dart';
import 'package:plainregs/research/research.dart';
import 'package:plainregs/screens/research_screen.dart';
import 'package:plainregs/services/sample_source.dart';
import 'package:plainregs/services/stub_simplification_service.dart';
import 'package:plainregs/state/bookmarks_store.dart';
import 'package:plainregs/state/saved_briefs_store.dart';
import 'package:plainregs/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StubResearchService', () {
    final svc = StubResearchService();

    test('parade question gets the over-people brief, cited', () async {
      final brief = await svc.ask('Can I fly my drone over a parade?');
      expect(brief.covered, isTrue);
      expect(brief.why.map((c) => c.label), contains('14 CFR 107.39'));
      // Openable citations are real eCFR refs; the statute is named.
      final openable = brief.why.where((c) => c.openable).toList();
      expect(openable, isNotEmpty);
      expect(
        openable.every((c) => c.ref!.sourceId == 'ecfr'),
        isTrue,
      );
      expect(brief.gaps, isNotEmpty);
      expect(brief.followUps, isNotEmpty);
    });

    test('NC permit question surfaces the repeal, not the stale permit',
        () async {
      final brief = await svc.ask(
        'Do I need a state permit to film a roof inspection in NC?',
      );
      expect(brief.covered, isTrue);
      expect(brief.shortAnswer, contains('repealed'));
      expect(
        brief.why.map((c) => c.label).join(' '),
        contains('REPEALED'),
      );
    });

    test('night, registration, LAANC, military, waiver topics covered',
        () async {
      for (final q in [
        'Can I fly my drone at night?',
        'Do I have to register my drone?',
        'Do I need permission to fly near an airport?',
        'What rules apply when the military flies drones?',
        'Can I get a waiver for BVLOS?',
        'What changed in the new Part 107?',
      ]) {
        final brief = await svc.ask(q);
        expect(brief.covered, isTrue, reason: q);
        expect(brief.why, isNotEmpty, reason: q);
      }
    });

    test('uncovered question is honest: no answer, gaps named', () async {
      final brief = await svc.ask(
        'What are the drone rules for filming weddings in Texas?',
      );
      expect(brief.covered, isFalse);
      expect(brief.shortAnswer, contains('won\'t guess'));
      expect(brief.why, isEmpty);
      expect(brief.gaps.length, greaterThanOrEqualTo(3));
      expect(brief.followUps, isNotEmpty);
    });

    test('every brief carries the disclaimer as a constant', () {
      expect(
        ResearchBrief.disclaimer,
        contains('not legal advice'),
      );
    });

    test('brief JSON roundtrip preserves citations and openability',
        () async {
      final brief = await svc.ask('Can I fly my drone at night?');
      final copy = ResearchBrief.fromJson(brief.toJson());
      expect(copy.shortAnswer, brief.shortAnswer);
      expect(copy.why.length, brief.why.length);
      expect(
        copy.why.map((c) => c.openable).toList(),
        brief.why.map((c) => c.openable).toList(),
      );
    });
  });

  testWidgets('research screen asks, shows the anatomy, saves the brief',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final savedBriefs = SavedBriefsStore();
    await savedBriefs.load();
    final services = AppServices(
      sources: [SampleSource()],
      simplifier: StubSimplificationService(),
      bookmarks: BookmarksStore(),
      research: StubResearchService(),
      savedBriefs: savedBriefs,
    );
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: Scaffold(body: ResearchScreen(services: services)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Can I fly my drone over a parade?'));
    await tester.pumpAndSettle();
    expect(find.text('Short answer'), findsOneWidget);
    expect(find.text('Why — the rules that decide it'), findsOneWidget);
    expect(find.text('What we don\'t know'), findsOneWidget);
    expect(find.text('Dig deeper'), findsOneWidget);
    expect(find.text('14 CFR 107.39'), findsOneWidget);
    expect(find.textContaining('not legal advice'), findsOneWidget);

    await tester.ensureVisible(find.text('Save brief'));
    await tester.tap(find.text('Save brief'));
    await tester.pumpAndSettle();
    expect(savedBriefs.items.single.brief.question,
        'Can I fly my drone over a parade?');
    expect(find.text('Saved briefs'), findsOneWidget);
  });
}
