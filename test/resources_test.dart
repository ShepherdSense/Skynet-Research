import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/resources/resources.dart';
import 'package:plainregs/screens/resources_screen.dart';
import 'package:plainregs/theme.dart';

ResourceEntry _e(
  String id,
  String name, {
  String platform = 'Website',
  List<String> tags = const [],
  List<String> reports = const [],
  String description = '',
}) =>
    ResourceEntry(
      id: id,
      name: name,
      url: 'https://example.com/$id',
      platform: platform,
      tags: tags,
      reports: reports,
      description: description,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalogue asset', () {
    test('parses fully and reconciles with the catalogue totals', () async {
      final catalog = await ResourceCatalog.load();
      expect(catalog.entries.length, 3419);
      expect(catalog.catalogueDate, '2026-10-23');
      final counts = <String, int>{};
      for (final e in catalog.entries) {
        counts[e.platform] = (counts[e.platform] ?? 0) + 1;
        // The parser guarantees every entry is openable and classified.
        expect(e.url, isNotNull, reason: e.id);
        expect(e.tags, isNotEmpty, reason: e.id);
        expect(e.reports, isNotEmpty, reason: e.id);
        expect(e.kind, isNotNull, reason: e.id);
      }
      expect(counts, {
        'Reddit': 66,
        'X': 127,
        'LinkedIn': 388,
        'YouTube': 138,
        'Facebook': 54,
        'Instagram': 16,
        'Threads': 3,
        'GitHub': 9,
        'Website': 2609,
        'Substack': 6,
        'Bluesky': 3,
      });
    });

    test('updated catalogue carries the review additions', () async {
      final catalog = await ResourceCatalog.load();
      // 184 review additions in the updated catalogue; 20 of them are
      // Telegram and excluded, leaving 164 shipped.
      expect(
        catalog.entries.where((e) => e.kind == 'Review addition').length,
        164,
      );
      expect(
        catalog.entries.where((e) => e.platform == 'Bluesky').length,
        3,
      );
      expect(
        catalog.entries.where((e) => e.platform == 'Substack').length,
        6,
      );
    });

    test('first entry matches the catalogue ground truth', () async {
      final catalog = await ResourceCatalog.load();
      // Telegram is excluded from the shipped bundle (Draco,
      // 2026-10-23) — the first Telegram entry (SRC-0001) is gone
      // and no Telegram entries remain at all.
      expect(
        catalog.entries.where((e) => e.platform == 'Telegram'),
        isEmpty,
      );
      final first = catalog.entries.first;
      expect(first.id, 'SRC-0093');
      expect(first.name, 'r/anormaldayinrussia');
      expect(first.url, 'https://www.reddit.com/r/anormaldayinrussia/');
      expect(first.platform, 'Reddit');
      expect(first.tags, containsAll(['Russia', 'Ukraine']));
      expect(first.reports, ['RU']);
      expect(first.kind, 'Current task source');
    });
  });

  group('filterResources', () {
    final entries = [
      _e('SRC-1', '@rybar', platform: 'Telegram',
          tags: ['Russia', 'Ukraine'], reports: ['RU']),
      _e('SRC-2', 'Skydio', platform: 'Website',
          tags: ['UAS', 'RAS'], reports: ['UAS-W'],
          description: 'Drone manufacturer'),
      _e('SRC-3', '@skydiohq', platform: 'X',
          tags: ['UAS'], reports: ['LINKEDIN-M']),
    ];

    test('query matches name, description, tags and reports', () {
      expect(filterResources(entries, query: 'rybar').single.id, 'SRC-1');
      expect(filterResources(entries, query: 'manufacturer').single.id,
          'SRC-2');
      expect(filterResources(entries, query: 'uas-w').single.id, 'SRC-2');
    });

    test('platform and tag filters combine', () {
      expect(filterResources(entries, platform: 'X').single.id, 'SRC-3');
      expect(
        filterResources(entries, tag: 'UAS', platform: 'Website').single.id,
        'SRC-2',
      );
      expect(filterResources(entries, tag: 'UAS').length, 2);
      expect(filterResources(entries, tag: 'UAS', query: 'skydio').length, 2);
    });
  });

  testWidgets('resources screen searches and filters the catalogue',
      (tester) async {
    final catalog = ResourceCatalog(
      catalogueDate: '2026-10-23',
      note: 'test note',
      entries: [
        _e('SRC-1', '@rybar', platform: 'Telegram',
            tags: ['Russia'], reports: ['RU']),
        _e('SRC-2', 'Skydio', platform: 'Website',
            tags: ['UAS'], reports: ['UAS-W']),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: Scaffold(body: ResourcesScreen(catalog: catalog)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('@rybar'), findsOneWidget);
    expect(find.text('Skydio'), findsOneWidget);
    expect(find.textContaining('2 sources'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'skydio');
    await tester.pumpAndSettle();
    expect(find.text('@rybar'), findsNothing);
    expect(find.text('Skydio'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Telegram (1)'));
    await tester.pumpAndSettle();
    expect(find.text('@rybar'), findsOneWidget);
    expect(find.text('Skydio'), findsNothing);
  });
}
