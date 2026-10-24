import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainregs/app_services.dart';
import 'package:plainregs/models/models.dart';
import 'package:plainregs/screens/user_docs_screen.dart';
import 'package:plainregs/services/sample_source.dart';
import 'package:plainregs/services/stub_simplification_service.dart';
import 'package:plainregs/services/user_docs_source.dart';
import 'package:plainregs/state/bookmarks_store.dart';
import 'package:plainregs/state/user_docs_store.dart';
import 'package:plainregs/theme.dart';
import 'package:plainregs/userdocs/user_document.dart';

UserDocument _doc({
  String id = 'doc-1',
  String title = 'DAFMAN 11-502 (local copy)',
  String text = 'Group 1 and 2 small UAS operating procedures. '
      'Operators must complete the training program.',
  String? url,
}) =>
    UserDocument(
      id: id,
      title: title,
      citation: 'DAFMAN 11-502',
      authority: 'Department of War — Air Force',
      sourceUrl: url,
      text: text,
      addedAt: DateTime(2026, 10, 23),
    );

AppServices _services(UserDocsStore store) => AppServices(
      sources: [SampleSource(), UserDocsSource(store)],
      simplifier: StubSimplificationService(),
      bookmarks: BookmarksStore(),
      userDocs: store,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UserDocsStore', () {
    test('add, persist, reload roundtrip', () async {
      final store = UserDocsStore();
      await store.load();
      await store.add(_doc());
      expect(store.items.single.title, contains('DAFMAN'));

      final reloaded = UserDocsStore();
      await reloaded.load();
      expect(reloaded.items.single.id, 'doc-1');
      expect(reloaded.items.single.citation, 'DAFMAN 11-502');

      await reloaded.remove('doc-1');
      expect(reloaded.items, isEmpty);
    });

    test('oversize text is refused, never truncated', () async {
      final store = UserDocsStore();
      await store.load();
      final big = _doc(text: 'x' * (UserDocsStore.maxTextChars + 1));
      await expectLater(store.add(big), throwsArgumentError);
      expect(store.items, isEmpty);
    });
  });

  group('UserDocsSource', () {
    test('search matches title, citation and body terms', () async {
      final store = UserDocsStore();
      await store.add(_doc());
      final source = UserDocsSource(store);
      expect((await source.search('training program')).single.ref.section,
          'doc-1');
      expect((await source.search('dafman')).single.ref.citationLabel,
          'DAFMAN 11-502');
      expect(await source.search('nonexistent topic'), isEmpty);
    });

    test('fetchSection returns the stored text with provenance', () async {
      final store = UserDocsStore();
      await store.add(_doc());
      final source = UserDocsSource(store);
      final section = await source.fetchSection(source.refFor(_doc()));
      expect(section.bodyText, contains('training program'));
      expect(section.sourceDate, contains('Added by you'));
    });

    test('link-only doc explains itself; removed doc says so', () async {
      final store = UserDocsStore();
      final link = _doc(id: 'doc-2', text: '', url: 'https://example.mil/x');
      await store.add(link);
      final source = UserDocsSource(store);
      final s = await source.fetchSection(source.refFor(link));
      expect(s.bodyText, contains('https://example.mil/x'));
      final gone = await source.fetchSection(
        const RegulationRef(
          sourceId: 'userdocs',
          titleNumber: 0,
          section: 'nope',
          heading: 'gone',
        ),
      );
      expect(gone.bodyText, contains('no longer in your library'));
    });
  });

  testWidgets('add a document, see it listed, read it in the Reader',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = UserDocsStore();
    await store.load();
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: UserDocsScreen(services: _services(store)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No documents yet'), findsOneWidget);

    await tester.tap(find.text('Add a document'));
    await tester.pumpAndSettle();
    // Form order: title, citation, link, then the document-text area.
    await tester.enterText(find.byType(TextField).at(0), 'My Test Order');
    await tester.enterText(
      find.byType(TextField).at(3),
      'All operators shall check the sky before launch.',
    );
    await tester.tap(find.text('Save to my library'));
    await tester.pumpAndSettle();

    expect(find.text('My Test Order'), findsOneWidget);
    await tester.tap(find.text('My Test Order'));
    await tester.pumpAndSettle();
    expect(find.textContaining('check the sky before launch'),
        findsWidgets);
  });
}
