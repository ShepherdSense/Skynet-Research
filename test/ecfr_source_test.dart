import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plainregs/models/models.dart';
import 'package:plainregs/services/ecfr_source.dart';

void main() {
  group('EcfrSource.parseSearchResults', () {
    test('parses a real-shaped search result and strips highlights', () {
      final data = jsonDecode('''
      {"results": [{
        "type": "Section",
        "hierarchy": {"title": "14", "part": "107", "section": "107.51"},
        "headings": {"title": "Aeronautics and Space",
                     "section": "Operating limitations for small unmanned aircraft."},
        "full_text_excerpt": "may not exceed <strong>87 knots</strong> (100 mph)"
      }]}''') as Map<String, dynamic>;

      final hits = EcfrSource.parseSearchResults(data, sourceId: 'ecfr');
      expect(hits.length, 1);
      expect(hits.single.ref.citation, '14 CFR 107.51');
      expect(hits.single.ref.heading, contains('Operating limitations'));
      expect(hits.single.excerpt, isNot(contains('<strong>')));
      expect(hits.single.excerpt, contains('87 knots'));
    });

    test('strips markup from headings and dedupes historical versions', () {
      // Shape captured from the live API 2026-10-23: headings carry
      // <strong> markup, and one section repeats per historical version.
      Map<String, dynamic> row(String startsOn) => {
        'starts_on': startsOn,
        'hierarchy': {'title': '14', 'part': '48', 'section': '48.115'},
        'headings': {
          'title': 'Aeronautics and Space',
          'section':
              'Registration: <strong>small unmanned aircraft</strong> use.',
        },
        'full_text_excerpt': 'excerpt',
      };
      final data = {
        'results': [row('2021-01-15'), row('2017-07-07'), row('2016-01-01')],
      };
      final hits = EcfrSource.parseSearchResults(data, sourceId: 'ecfr');
      expect(hits.length, 1);
      expect(hits.single.ref.heading, isNot(contains('<strong>')));
      expect(hits.single.ref.heading, contains('small unmanned aircraft'));
    });
  });

  group('EcfrSource.xmlToPlainText', () {
    test('extracts HEAD and P paragraphs from section XML', () {
      const xml = '''
      <DIV8 N="107.51" TYPE="SECTION">
      <HEAD>§ 107.51 Operating limitations for small unmanned aircraft.</HEAD>
      <P>(a) The groundspeed may not exceed 87 knots.</P>
      <P>(b) The altitude cannot be higher than 400 feet.</P>
      </DIV8>''';
      final text = EcfrSource.xmlToPlainText(xml);
      expect(text, contains('§ 107.51'));
      expect(text, contains('87 knots'));
      expect(text, contains('400 feet'));
      expect(text, isNot(contains('<P>')));
    });

    test('unescapes entities', () {
      final text = EcfrSource.xmlToPlainText(
        '<P>Tom &amp; Jerry &lt;tag&gt; &quot;quoted&quot;</P>',
      );
      expect(text, contains('Tom & Jerry'));
      expect(text, contains('"quoted"'));
    });
  });

  group('EcfrSource with MockClient', () {
    test('titles() parses and caches currency dates', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/versioner/v1/titles.json');
        return http.Response(
          jsonEncode({
            'titles': [
              {
                'number': 14,
                'name': 'Aeronautics and Space',
                'up_to_date_as_of': '2026-10-21',
                'reserved': false,
              },
            ],
          }),
          200,
        );
      });
      final titles = await EcfrSource(client).titles();
      expect(titles.single.name, 'Aeronautics and Space');
      expect(titles.single.upToDateAsOf, '2026-10-21');
    });

    test('fetchSection decodes UTF-8 bytes (§ must not become Â§)', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('titles.json')) {
          return http.Response(
            jsonEncode({
              'titles': [
                {
                  'number': 14,
                  'name': 'Aeronautics and Space',
                  'up_to_date_as_of': '2026-10-21',
                  'reserved': false,
                },
              ],
            }),
            200,
          );
        }
        // Serve raw UTF-8 bytes with no charset header, like the live API.
        return http.Response.bytes(
          utf8.encode(
            '<DIV8><HEAD>§ 107.51 Operating limitations.</HEAD>'
            '<P>May not exceed 87 knots — ever.</P></DIV8>',
          ),
          200,
        );
      });
      final section = await EcfrSource(client).fetchSection(
        const RegulationRef(
          sourceId: 'ecfr',
          titleNumber: 14,
          part: '107',
          section: '107.51',
          heading: 'x',
        ),
      );
      expect(section.bodyText, contains('§ 107.51'));
      expect(section.bodyText, isNot(contains('Â§')));
      expect(section.bodyText, contains('—'));
      expect(section.sourceDate, '2026-10-21');
    });

    test('search() hits the search endpoint with the query', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/search/v1/results');
        expect(req.url.queryParameters['query'], 'drone');
        return http.Response(jsonEncode({'results': []}), 200);
      });
      final hits = await EcfrSource(client).search('drone');
      expect(hits, isEmpty);
    });
  });
}
