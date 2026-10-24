import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/models/models.dart';

void main() {
  group('RegulationRef', () {
    test('formats a section citation', () {
      const ref = RegulationRef(
        sourceId: 'ecfr',
        titleNumber: 14,
        part: '107',
        section: '107.51',
        heading: 'Operating limitations',
      );
      expect(ref.citation, '14 CFR 107.51');
      expect(ref.key, 'ecfr|14 CFR 107.51');
    });

    test('formats a part-only citation', () {
      const ref = RegulationRef(
        sourceId: 'ecfr',
        titleNumber: 40,
        part: '262',
        heading: '',
      );
      expect(ref.citation, '40 CFR Part 262');
    });

    test('json round trip', () {
      const ref = RegulationRef(
        sourceId: 'ecfr',
        titleNumber: 29,
        part: '1910',
        section: '1910.95',
        heading: 'Occupational noise exposure.',
      );
      final back = RegulationRef.fromJson(ref.toJson());
      expect(back, ref);
      expect(back.heading, ref.heading);
    });
  });

  group('CfrTitle', () {
    test('parses eCFR titles.json shape', () {
      final t = CfrTitle.fromJson({
        'number': 14,
        'name': 'Aeronautics and Space',
        'up_to_date_as_of': '2026-10-21',
        'reserved': false,
      });
      expect(t.number, 14);
      expect(t.upToDateAsOf, '2026-10-21');
    });
  });

  group('StructureNode', () {
    test('findAll flattens descendants by type', () {
      final tree = StructureNode.fromJson({
        'identifier': '14',
        'label': 'Title 14',
        'type': 'title',
        'children': [
          {
            'identifier': '107',
            'label': 'Part 107',
            'type': 'part',
            'children': [
              {'identifier': '107.51', 'label': '§ 107.51', 'type': 'section'},
              {'identifier': '107.49', 'label': '§ 107.49', 'type': 'section'},
            ],
          },
        ],
      });
      expect(tree.findAll('section').length, 2);
      expect(tree.findAll('part').single.identifier, '107');
    });
  });

  group('Simplification guardrails', () {
    test('disclaimer is a constant that names the original as what counts', () {
      expect(Simplification.disclaimer, contains('not the law'));
      expect(
        Simplification.disclaimer,
        contains('original text is what legally counts'),
      );
    });
  });
}
