import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/screens/states_screen.dart';
import 'package:plainregs/shepherd/shepherd.dart';
import 'package:plainregs/states/states_matrix.dart';
import 'package:plainregs/theme.dart';

List<StateMatrixEntry> loadAsset() {
  final doc = jsonDecode(
    File('assets/states_matrix.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (doc['states'] as List)
      .map((e) => StateMatrixEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  final states = loadAsset();
  StateMatrixEntry byCode(String code) =>
      states.firstWhere((s) => s.code == code);

  group('bundled matrix (converter output)', () {
    test('all 50 states, verified dates attached', () {
      expect(states.length, 50);
      expect(states.map((s) => s.code).toSet().length, 50);
      for (final s in states) {
        expect(s.verifiedDate, '2026-10-23', reason: s.code);
      }
    });

    test('verified/partial states carry all 13 categories', () {
      for (final s in states.where((s) => s.hasData)) {
        expect(s.categories.length, 13, reason: s.code);
        expect(
          s.categories.map((c) => c.n).toSet(),
          {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
          reason: s.code,
        );
      }
    });

    test('NC carries the repeal, not the repealed permit', () {
      final nc = byCode('NC');
      expect(nc.status, StateMatrixStatus.verified);
      final reg = nc.categories.firstWhere((c) => c.n == 9);
      expect(reg.headline, contains('Repealed'));
      final privacy = nc.categories.firstWhere((c) => c.n == 1);
      expect(privacy.headline, contains('Consent-based ban'));
    });

    test('Indiana verified via the live-browser addendum', () {
      final indiana = byCode('IN');
      expect(indiana.status, StateMatrixStatus.verified);
      expect(indiana.categories.length, 13);
      // Short form confirmed on official text — the pre-2019 (A)–(H)
      // list must not come back.
      final le = indiana.categories.firstWhere((c) => c.n == 3);
      expect(le.headline, 'warrant required');
      final exceptions = indiana.categories.firstWhere((c) => c.n == 13);
      expect(exceptions.headline, 'narrow');
      // The contingent counter-UAS article is named as contingent,
      // never as active law.
      final other = indiana.categories.firstWhere((c) => c.n == 10);
      expect(other.detail, contains('CONTINGENT — NOT ACTIVE LAW'));
      expect(other.detail, contains('10-22-1-1'));
      expect(indiana.caveat, contains('contingent'));
    });

    test('no state is left unverified', () {
      expect(
        states.where((s) => s.status == StateMatrixStatus.unverified),
        isEmpty,
      );
      expect(states.where((s) => s.hasData).length, 50);
    });

    test('FL privacy headline is the § 934.50 consent ban', () {
      final fl = byCode('FL');
      expect(fl.categories.first.headline, contains('consent'));
    });
  });

  group('matchStateInText', () {
    test('finds the state in a geocoder display name', () {
      expect(
        matchStateInText(
          'Fayetteville, North Carolina, United States',
          states,
        )?.code,
        'NC',
      );
    });

    test('West Virginia never false-matches as Virginia', () {
      expect(
        matchStateInText('Charleston, West Virginia', states)?.code,
        'WV',
      );
      expect(
        matchStateInText('Richmond, Virginia', states)?.code,
        'VA',
      );
    });

    test('no state named, no match', () {
      expect(matchStateInText('entered location (35.0, -78.9)', states),
          isNull);
    });
  });

  group('shepherd state flip', () {
    List<ShepherdSection> summaryFor(String label) => buildShepherdSummary(
          group: UasGroup.g1,
          liveMunitions: false,
          check: null,
          locationLabel: label,
          stateMatrix: states,
        );

    test('place name in a verified state flips to REAL DATA', () {
      final sections =
          summaryFor('Fayetteville, North Carolina, United States');
      final state = sections.firstWhere(
        (s) => s.title.startsWith('State rules layer'),
      );
      expect(state.layerKind, 'REAL DATA');
      expect(state.title, contains('North Carolina'));
      expect(state.lines.join(' '), contains('Consent-based ban'));
      expect(state.lines.join(' '), contains('repealed Dec 1, 2024'));
      expect(state.lines.join(' '), contains('2026-10-23'));
    });

    test('Indiana flips to REAL DATA with the warrant rule', () {
      final sections = summaryFor('Indianapolis, Indiana');
      final state = sections.firstWhere(
        (s) => s.title.startsWith('State rules layer'),
      );
      expect(state.layerKind, 'REAL DATA');
      expect(state.lines.join(' '), contains('warrant required'));
    });

    test('coordinates get the pointer section', () {
      final sections = summaryFor('entered location (35.0, -78.9)');
      final state = sections.firstWhere(
        (s) => s.title.startsWith('State rules layer'),
      );
      expect(state.lines.join(' '), contains('place name'));
    });
  });

  testWidgets('states screen lists all states and opens NC detail',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: StatesScreen(states: states),
    ));
    await tester.pumpAndSettle();
    // The list is lazy — Indiana is near the top and visible; NC is
    // reached through search.
    expect(find.text('Indiana (IN)'), findsOneWidget);
    expect(find.textContaining('VERIFIED · 2026-10-23'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'North Carolina');
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Carolina (NC)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verified 2026-10-23'), findsWidgets);
    expect(find.text('Consent-based ban'), findsOneWidget);
    expect(find.textContaining('15A-300.1'), findsWidgets);
  });
}
