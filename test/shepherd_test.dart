import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/airspace/airspace_service.dart';
import 'package:plainregs/shepherd/shepherd.dart';

void main() {
  group('uasGroups table', () {
    test('all five groups present with bands and examples', () {
      expect(uasGroups.length, 5);
      expect(uasGroups[UasGroup.g2]!.examples, contains('ScanEagle'));
      expect(uasGroups[UasGroup.g3]!.examples, contains('V-BAT'));
      expect(uasGroups[UasGroup.g5]!.altitudeBand, contains('18,000'));
    });
  });

  group('buildShepherdSummary', () {
    test(
      'Group 2 + live munitions + 200 ft grid: armed block, real ceiling',
      () {
        final sections = buildShepherdSummary(
          group: UasGroup.g2,
          liveMunitions: true,
          check: const GridHitCheck(200, 35.05, -78.88),
          locationLabel: 'entered location',
        );
        final airspace = sections.firstWhere(
          (s) => s.title.contains('airspace'),
        );
        expect(airspace.layerKind, 'REAL DATA');
        expect(airspace.lines.join(' '), contains('200 feet'));
        final munitions = sections.firstWhere(
          (s) => s.title.contains('Live munitions'),
        );
        expect(munitions.tone, ShepherdTone.block);
        expect(munitions.lines.join(' '), contains('never authorized'));
        // The armed section names governing pubs + approval authorities
        // from the DoW map — and nothing beyond them.
        expect(munitions.lines.join(' '), contains('DAFMAN 11-501'));
        expect(munitions.lines.join(' '), contains('public aircraft'));
        expect(munitions.lines.join(' '), contains('clears nothing'));
        // Researching layers are labelled, never faked — and now cite
        // the landed maps.
        final researching =
            sections.where((s) => s.layerKind == 'RESEARCHING').toList();
        expect(researching.length, 2);
        expect(
          researching.map((s) => s.lines.join(' ')).join(' '),
          contains('source map has landed'),
        );
      },
    );

    test('0-foot grid reads as a block, not a clearance', () {
      final sections = buildShepherdSummary(
        group: UasGroup.g1,
        liveMunitions: false,
        check: const GridHitCheck(0, 33.94, -118.40),
        locationLabel: 'your current location',
      );
      final airspace = sections.first;
      expect(airspace.tone, ShepherdTone.block);
      expect(airspace.lines.join(' '), contains('0-foot'));
    });

    test('Group 5 unarmed, no grid: civil layer warns, munitions ok', () {
      final sections = buildShepherdSummary(
        group: UasGroup.g5,
        liveMunitions: false,
        check: const NoGridCheck(39.0, -104.0),
        locationLabel: 'your current location',
      );
      final civil = sections.firstWhere((s) => s.title.contains('Civil'));
      expect(civil.tone, ShepherdTone.warn);
      final munitions = sections.firstWhere((s) => s.title == 'Live munitions');
      expect(munitions.tone, ShepherdTone.ok);
    });

    test('failed location draws NO airspace conclusion', () {
      final sections = buildShepherdSummary(
        group: UasGroup.g3,
        liveMunitions: false,
        check: const LocationFailedCheck('Location permission not granted.'),
        locationLabel: '',
      );
      final airspace = sections.first;
      expect(airspace.tone, ShepherdTone.warn);
      expect(
        airspace.lines.join(' '),
        contains('No airspace conclusion is drawn'),
      );
    });
  });
}
