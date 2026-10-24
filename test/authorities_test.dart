import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainregs/airspace/geocoder.dart';
import 'package:plainregs/app_services.dart';
import 'package:plainregs/screens/browse_screen.dart';
import 'package:plainregs/services/sample_source.dart';
import 'package:plainregs/services/stub_simplification_service.dart';
import 'package:plainregs/state/bookmarks_store.dart';
import 'package:plainregs/theme.dart';

AppServices _services() => AppServices(
      sources: [SampleSource()],
      simplifier: StubSimplificationService(),
      bookmarks: BookmarksStore(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NominatimGeocoder', () {
    test('parses the first result', () async {
      final client = MockClient((req) async {
        expect(req.url.host, 'nominatim.openstreetmap.org');
        expect(req.url.queryParameters['q'], 'Fayetteville, NC');
        return http.Response(
          jsonEncode([
            {
              'lat': '35.0526',
              'lon': '-78.8789',
              'display_name': 'Fayetteville, North Carolina, United States',
            },
          ]),
          200,
        );
      });
      final place =
          await NominatimGeocoder(client: client).lookup('Fayetteville, NC');
      expect(place, isNotNull);
      expect(place!.lat, closeTo(35.0526, 1e-9));
      expect(place.lon, closeTo(-78.8789, 1e-9));
      expect(place.displayName, contains('Fayetteville'));
    });

    test('no result is null, never a guess', () async {
      final client = MockClient((req) async => http.Response('[]', 200));
      expect(
        await NominatimGeocoder(client: client).lookup('Nowheresville'),
        isNull,
      );
    });

    test('HTTP failure is null', () async {
      final client = MockClient((req) async => http.Response('nope', 503));
      expect(
        await NominatimGeocoder(client: client).lookup('Fayetteville, NC'),
        isNull,
      );
    });
  });

  testWidgets('browse hub shows every authority and service button',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: PlainRegsTheme.dark,
      home: BrowseScreen(services: _services()),
    ));
    await tester.pump();

    expect(find.text('SHEPHERD'), findsOneWidget);
    for (final label in [
      'FAA Regulations',
      'Federal — All Titles',
      'State Regulations · all 50 live',
      'Department of War · map landed',
      'Air Force',
      'Army',
      'Navy',
      'Marine Corps',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // No Space Force button (removed per Draco, 2026-10-23).
    expect(find.textContaining('Space Force'), findsNothing);

    // The Air Force page names its governing publications.
    await tester.tap(find.text('Air Force'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DAFMAN 11-501'), findsWidgets);
  });
}
