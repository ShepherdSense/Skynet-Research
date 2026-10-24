import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/resources/events.dart';
import 'package:plainregs/resources/resources.dart';
import 'package:plainregs/screens/resources_screen.dart';
import 'package:plainregs/theme.dart';

DroneEvent _ev(
  String id,
  String name, {
  String status = 'Completed',
  String window = '1–2 Jan 2026',
  String location = 'Somewhere',
  String host = 'Some host',
  String category = 'Warfighter competition',
  String focus = 'Focus text.',
  String? exactStart,
  String? exactEnd,
}) =>
    DroneEvent(
      id: id,
      name: name,
      window: window,
      status: status,
      location: location,
      host: host,
      category: category,
      focus: focus,
      notes: 'Evidence note.',
      exactStart: exactStart,
      exactEnd: exactEnd,
      primaryUrl: 'https://example.com/$id',
      verifiedAsOf: '2026-10-09',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled events asset', () {
    test('parses fully and reconciles with the register totals',
        () async {
      final catalog = await DroneEventsCatalog.load();
      expect(catalog.verifiedAsOf, '2026-10-09');
      expect(catalog.events.length, 74);
      final counts = <String, int>{};
      for (final e in catalog.events) {
        counts[e.status] = (counts[e.status] ?? 0) + 1;
        expect(e.name, isNotEmpty, reason: e.id);
        expect(e.window, isNotEmpty, reason: e.id);
        expect(e.location, isNotEmpty, reason: e.id);
        expect(e.host, isNotEmpty, reason: e.id);
        expect(e.category, isNotEmpty, reason: e.id);
        expect(e.focus, isNotEmpty, reason: e.id);
        expect(e.notes, isNotEmpty, reason: e.id);
        expect(e.primaryUrl, startsWith('https://'), reason: e.id);
        expect(e.verifiedAsOf, '2026-10-09', reason: e.id);
      }
      expect(counts, {
        'Completed': 40,
        'Announced dates': 17,
        'Announced window': 7,
        'Past schedule only': 5,
        'Tentative planning': 3,
        'Date unconfirmed': 2,
      });
      // Register order is preserved in the asset.
      expect(catalog.events.first.id, 'E001');
      expect(catalog.events.last.id, 'E074');
    });

    test('first register entry matches ground truth', () async {
      final catalog = await DroneEventsCatalog.load();
      final first = catalog.events.first;
      expect(first.name, '1st SFC(A) Best Drone Team Competition');
      expect(first.status, 'Completed');
      expect(first.location, 'Fort McClellan and Clarke Range, Alabama');
      expect(first.exactStart, '2026-08-24');
      expect(first.exactEnd, '2026-08-28');
    });
  });

  group('filterEvents', () {
    final events = [
      _ev('E001', 'Alpha Competition',
          exactStart: '2026-08-24', exactEnd: '2026-08-28'),
      _ev('E002', 'Beta Expo',
          status: 'Announced dates', window: '17–20 May 2027',
          location: 'Miami Beach, Florida', category: 'Conference/expo',
          exactStart: '2027-05-17', exactEnd: '2027-05-20'),
      _ev('E003', 'Gamma Test',
          status: 'Date unconfirmed', window: '2026; exact dates TBD',
          category: 'Industry day'),
    ];

    test('sorts newest first, undated last', () {
      final sorted = filterEvents(events);
      expect(
        sorted.map((e) => e.id).toList(),
        ['E002', 'E001', 'E003'],
      );
    });

    test('query matches name, location, category and host', () {
      expect(filterEvents(events, query: 'miami').single.id, 'E002');
      expect(filterEvents(events, query: 'competition').length, 1);
      expect(filterEvents(events, query: 'alpha').single.id, 'E001');
    });

    test('status filter and upcoming toggle combine', () {
      expect(filterEvents(events, status: 'Completed').single.id, 'E001');
      final upcoming = filterEvents(events, upcomingOnly: true);
      // Only the 2027 event can possibly be upcoming at any test
      // date in this era; the undated one never counts as upcoming.
      expect(upcoming.map((e) => e.id), contains('E002'));
      expect(upcoming.map((e) => e.id), isNot(contains('E003')));
    });
  });

  testWidgets('resources screen switches to the Events section',
      (tester) async {
    final catalog = ResourceCatalog(
      catalogueDate: '2026-10-23',
      note: 'test note',
      entries: [
        ResourceEntry(
          id: 'SRC-1',
          name: 'Skydio',
          url: 'https://example.com/skydio',
          platform: 'Website',
          tags: const ['UAS'],
          reports: const ['UAS-W'],
        ),
      ],
    );
    final events = DroneEventsCatalog(
      verifiedAsOf: '2026-10-09',
      note: 'test note',
      events: [
        _ev('E001', 'Alpha Competition',
            exactStart: '2026-08-24', exactEnd: '2026-08-28'),
        _ev('E002', 'Beta Expo',
            status: 'Announced dates', window: '17–20 May 2027',
            exactStart: '2027-05-17', exactEnd: '2027-05-20'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: Scaffold(body: ResourcesScreen(catalog: catalog, events: events)),
    ));
    await tester.pumpAndSettle();

    // Sources view is the default.
    expect(find.text('Skydio'), findsOneWidget);
    expect(find.text('Alpha Competition'), findsNothing);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Competition'), findsOneWidget);
    expect(find.text('Beta Expo'), findsOneWidget);
    expect(find.text('2 events · verified 2026-10-09'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Competition'), findsOneWidget);
    expect(find.text('Beta Expo'), findsNothing);

    // Expanding a card reveals its sources.
    await tester.tap(find.text('Alpha Competition'));
    await tester.pumpAndSettle();
    expect(find.text('Primary source'), findsOneWidget);
  });
}
