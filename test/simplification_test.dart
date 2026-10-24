import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/models/models.dart';
import 'package:plainregs/services/sample_source.dart';
import 'package:plainregs/services/stub_simplification_service.dart';

void main() {
  final stub = StubSimplificationService();

  group('StubSimplificationService', () {
    test(
      'known citation returns a hand-written sample, flagged as stub',
      () async {
        final section = await SampleSource().fetchSection(
          const RegulationRef(
            sourceId: 'sample',
            titleNumber: 14,
            part: '107',
            section: '107.51',
            heading: 'Operating limitations',
          ),
        );
        final simp = await stub.simplify(section);
        expect(simp.isStub, isTrue);
        expect(simp.isMissing, isFalse);
        expect(simp.plainText, contains('100 miles per hour'));
        expect(simp.keyPoints, isNotEmpty);
        // Guardrail: the sample must not soften the legal numbers.
        expect(simp.plainText, contains('400 feet'));
        expect(simp.plainText, contains('3 miles'));
      },
    );

    test(
      'unknown citation returns an honest missing result — never invents',
      () async {
        final simp = await stub.simplify(
          const RegSection(
            ref: RegulationRef(
              sourceId: 'ecfr',
              titleNumber: 40,
              part: '262',
              section: '262.14',
              heading: 'Conditions for very small quantity generators',
            ),
            bodyText: 'Some regulatory text the stub has never seen.',
          ),
        );
        expect(simp.isMissing, isTrue);
        expect(simp.plainText, contains('has not been written yet'));
        expect(simp.plainText, contains('will not guess'));
      },
    );
  });

  group('SampleSource (offline end-to-end data)', () {
    test('search finds the drone section by plain words', () async {
      final hits = await SampleSource().search('drone');
      expect(hits.map((h) => h.ref.citation), contains('14 CFR 107.51'));
    });

    test('search finds a section by citation', () async {
      final hits = await SampleSource().search('1910.95');
      expect(hits.single.ref.citation, '29 CFR 1910.95');
    });

    test('fetchSection returns body text for every sample', () async {
      for (final s in SampleSource.samples) {
        final fetched = await SampleSource().fetchSection(s.ref);
        expect(fetched.bodyText, isNotEmpty);
      }
    });
  });
}
