import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/flycheck/fly_check.dart';

FlyAnswers baseRec() => FlyAnswers()
  ..purpose = FlyPurpose.recreational
  ..weight = WeightClass.under250g
  ..credential = TriState.yes
  ..airspace = AirspaceClass.uncontrolled
  ..above400 = false
  ..keepInSight = true
  ..overPeople = false
  ..atNight = false;

FlyAnswers baseWork() => FlyAnswers()
  ..purpose = FlyPurpose.work
  ..weight = WeightClass.between250gAnd55lb
  ..registered = TriState.yes
  ..credential = TriState.yes
  ..remoteId = RemoteIdStatus.builtIn
  ..airspace = AirspaceClass.uncontrolled
  ..above400 = false
  ..keepInSight = true
  ..overPeople = false
  ..atNight = false;

void main() {
  group('evaluateFlyCheck', () {
    test('light recreational drone, everything in order: CAN FLY', () {
      final r = evaluateFlyCheck(baseRec());
      expect(r.verdict, FlyVerdict.canFly);
      // Sub-250g recreational: registration and Remote ID not required.
      expect(
        r.passed.map((o) => o.title),
        containsAll(['Registration: not required', 'Remote ID: not required']),
      );
      expect(r.conditions, isNotEmpty);
    });

    test('recreational, heavier drone, unregistered + no TRUST: NOT YET '
        'with both fixes named', () {
      final a = baseRec()
        ..weight = WeightClass.between250gAnd55lb
        ..registered = TriState.no
        ..credential = TriState.no
        ..remoteId = RemoteIdStatus.builtIn;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.notYet);
      final fixes = r.toFix.map((o) => o.title).toList();
      expect(fixes, contains('Your drone must be registered'));
      expect(fixes, contains('Take the TRUST test before you fly'));
      // Every fixable outcome must cite a rule.
      for (final o in r.toFix) {
        expect(o.ref, isNotNull, reason: o.title);
      }
    });

    test('over 55 lb: CANNOT as described', () {
      final a = baseRec()..weight = WeightClass.over55lb;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.cannotAsDescribed);
      expect(r.blocked.single.title, 'Too heavy for these rules');
    });

    test(
      'work without a Remote Pilot certificate: NOT YET, cert is the fix',
      () {
        final a = baseWork()..credential = TriState.no;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.notYet);
        expect(
          r.toFix.map((o) => o.title),
          contains('You need a Remote Pilot certificate'),
        );
      },
    );

    test('work, beyond visual line of sight: CANNOT as described', () {
      final a = baseWork()..keepInSight = false;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.cannotAsDescribed);
      expect(
        r.blocked.map((o) => o.title),
        contains('You must keep the drone in sight'),
      );
      expect(r.blocked.single.ref?.citation, '14 CFR 107.31');
    });

    test(
      'work, fully compliant in controlled airspace WITH LAANC: CAN FLY',
      () {
        final a = baseWork()
          ..airspace = AirspaceClass.controlled
          ..airspaceAuthorization = TriState.yes;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.canFly);
        expect(r.conditions.join(' '), contains('107.51'));
      },
    );

    test('controlled airspace without authorization: NOT YET (LAANC fix)', () {
      final a = baseRec()
        ..airspace = AirspaceClass.controlled
        ..airspaceAuthorization = TriState.no;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.notYet);
      expect(
        r.toFix.map((o) => o.title),
        contains('Get airspace authorization first'),
      );
    });

    test('work at night without night readiness: NOT YET', () {
      final a = baseWork()
        ..atNight = true
        ..nightReady = TriState.no;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.notYet);
      expect(
        r.toFix.map((o) => o.title),
        contains('Night flying needs two things first'),
      );
    });

    test('work over people: never a silent pass — always a check', () {
      final a = baseWork()..overPeople = true;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.notYet);
      final o = r.toFix.singleWhere(
        (o) => o.title == 'Flying over people has extra rules',
      );
      expect(o.status, OutcomeStatus.check);
      expect(o.ref?.citation, contains('Subpart D'));
    });

    test('unknown weight degrades to a check, never a pass', () {
      final a = baseRec()..weight = WeightClass.unknown;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.notYet);
      expect(r.toFix.map((o) => o.title), contains('Weigh your drone'));
    });

    test('government flying is out of scope, honestly', () {
      final a = FlyAnswers()..purpose = FlyPurpose.government;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.outOfScope);
    });

    test('unsure purpose is undetermined with the rulebook explained', () {
      final a = FlyAnswers()..purpose = FlyPurpose.unsure;
      final r = evaluateFlyCheck(a);
      expect(r.verdict, FlyVerdict.undetermined);
      expect(r.outcomes.single.ref?.citation, '49 U.S.C. § 44809');
    });

    group('LAANC grid-checked airspace', () {
      test('0-foot grid: NOT YET with the manual-authorization fix', () {
        final a = baseRec()
          ..airspaceFromGrid = true
          ..gridCeilingFt = 0;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.notYet);
        final o = r.toFix.singleWhere((o) => o.title.contains('0-foot grid'));
        expect(o.fix, contains('DroneZone'));
      });

      test('grid 200 without LAANC: fixable and names the ceiling', () {
        final a = baseRec()
          ..airspaceFromGrid = true
          ..gridCeilingFt = 200
          ..airspaceAuthorization = TriState.no;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.notYet);
        final o = r.toFix.singleWhere(
          (o) => o.title.contains('Get LAANC authorization'),
        );
        expect(o.plainWhy, contains('200'));
        expect(o.fix, contains('200'));
      });

      test('grid 200 with LAANC: CAN FLY, ceiling becomes a condition', () {
        final a = baseRec()
          ..airspaceFromGrid = true
          ..gridCeilingFt = 200
          ..airspaceAuthorization = TriState.yes;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.canFly);
        expect(r.conditions.join(' '), contains('200'));
      });

      test('checked, no grid covers the point: airspace passes honestly', () {
        final a = baseRec()
          ..airspaceFromGrid = true
          ..gridCeilingFt = null;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.canFly);
        final o = r.passed.singleWhere(
          (o) => o.title.contains('outside the LAANC grids'),
        );
        expect(o.plainWhy, contains('do not show'));
      });

      test('grid answer overrides a contradictory self-report', () {
        // User says "uncontrolled" but the grid says controlled 100 ft
        // with no authorization: the grid branch must win.
        final a = baseRec()
          ..airspace = AirspaceClass.uncontrolled
          ..airspaceFromGrid = true
          ..gridCeilingFt = 100
          ..airspaceAuthorization = TriState.no;
        final r = evaluateFlyCheck(a);
        expect(r.verdict, FlyVerdict.notYet);
        expect(
          r.toFix.map((o) => o.title),
          contains('Get LAANC authorization for this spot'),
        );
      });
    });

    test('every outcome in a full run carries a citation or is a pure '
        'airspace/weight check', () {
      final r = evaluateFlyCheck(baseWork());
      for (final o in r.outcomes) {
        if (o.status == OutcomeStatus.fixable ||
            o.status == OutcomeStatus.blocked) {
          expect(o.ref, isNotNull, reason: '${o.title} must cite its rule');
        }
      }
    });
  });
}
