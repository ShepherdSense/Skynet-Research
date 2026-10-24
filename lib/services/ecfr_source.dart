import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'regulation_source.dart';

/// Live US federal regulations via the official eCFR API.
/// Free, public, no API key. Endpoints verified live 2026-10-23.
/// See DESIGN.md §3 for the endpoint table and the compression trap.
class EcfrSource implements RegulationSource {
  static const String base = 'https://www.ecfr.gov';

  final http.Client _client;
  final Map<int, String> _titleDates = {}; // title -> up_to_date_as_of

  EcfrSource([http.Client? client]) : _client = client ?? http.Client();

  @override
  String get id => 'ecfr';

  @override
  String get displayName => 'US Federal Regulations (CFR)';

  /// eCFR responses are UTF-8 but don't always declare a charset, and
  /// package:http falls back to latin-1 when none is declared — which turns
  /// "§" into "Â§". Always decode the bytes as UTF-8 explicitly.
  static String _utf8(http.Response res) => utf8.decode(res.bodyBytes);

  Future<dynamic> _getJson(String path) async {
    final res = await _client.get(Uri.parse('$base$path'));
    if (res.statusCode != 200) {
      throw Exception('eCFR request failed (${res.statusCode}): $path');
    }
    return jsonDecode(_utf8(res));
  }

  @override
  Future<List<CfrTitle>> titles() async {
    final data = await _getJson('/api/versioner/v1/titles.json');
    final list = (data['titles'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CfrTitle.fromJson)
        .toList();
    for (final t in list) {
      if (t.upToDateAsOf != null) _titleDates[t.number] = t.upToDateAsOf!;
    }
    return list;
  }

  /// The version date to pull [titleNumber]'s text for. eCFR currency is
  /// per-title, so resolve it from titles.json instead of guessing today.
  Future<String> _dateFor(int titleNumber) async {
    if (!_titleDates.containsKey(titleNumber)) await titles();
    return _titleDates[titleNumber] ??
        DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  Future<List<Agency>> agencies() async {
    final data = await _getJson('/api/admin/v1/agencies.json');
    return (data['agencies'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (j) => Agency(
            name: j['display_name'] as String? ?? j['name'] as String? ?? '',
            slug: j['slug'] as String? ?? '',
            cfrReferences: (j['cfr_references'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((r) => 'Title ${r['title']}, Chapter ${r['chapter']}')
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Future<List<SearchHit>> search(
    String query, {
    int page = 1,
    int perPage = 20,
    String? agencySlug,
  }) async {
    final params = {
      'query': query,
      'page': '$page',
      'per_page': '$perPage',
      'agency_slugs[]': ?agencySlug,
    };
    final uri = Uri.parse('$base/api/search/v1/results')
        .replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('eCFR search failed (${res.statusCode})');
    }
    final data = jsonDecode(_utf8(res)) as Map<String, dynamic>;
    return parseSearchResults(data, sourceId: id);
  }

  /// Pure parser (testable without network).
  ///
  /// Two live-API realities handled here (both found in the 2026-10-23 live
  /// smoke check): headings arrive with `<strong>` highlight markup just
  /// like excerpts, and the same section appears once per historical
  /// version — results are deduped by citation, first (best-ranked) wins.
  static List<SearchHit> parseSearchResults(
    Map<String, dynamic> data, {
    required String sourceId,
  }) {
    final seen = <String>{};
    final hits = <SearchHit>[];
    for (final j
        in (data['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()) {
      final hier = j['hierarchy'] as Map<String, dynamic>? ?? {};
      final headings = j['headings'] as Map<String, dynamic>? ?? {};
      final section = hier['section'] as String?;
      final heading = stripHighlight(
        (headings['section'] as String?) ?? (headings['part'] as String?) ?? '',
      );
      final hit = SearchHit(
        ref: RegulationRef(
          sourceId: sourceId,
          titleNumber: int.tryParse(hier['title']?.toString() ?? '') ?? 0,
          part: hier['part'] as String?,
          section: section,
          heading: heading,
        ),
        excerpt: stripHighlight(j['full_text_excerpt'] as String? ?? ''),
        titleName: headings['title'] as String?,
      );
      if (seen.add(hit.ref.citation)) hits.add(hit);
    }
    return hits;
  }

  static String stripHighlight(String s) =>
      s.replaceAll(RegExp(r'</?strong>'), '').trim();

  @override
  Future<StructureNode> structure(int titleNumber, {String? date}) async {
    final d = date ?? await _dateFor(titleNumber);
    final data = await _getJson(
      '/api/versioner/v1/structure/$d/title-$titleNumber.json',
    );
    return StructureNode.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RegSection> fetchSection(RegulationRef ref) async {
    final date = await _dateFor(ref.titleNumber);
    final params = {
      if (ref.part != null) 'part': ref.part!,
      if (ref.section != null) 'section': ref.section!,
    };
    final uri = Uri.parse(
      '$base/api/versioner/v1/full/$date/title-${ref.titleNumber}.xml',
    ).replace(queryParameters: params);
    // NOTE: this endpoint errors unless the request permits compression.
    // package:http advertises gzip by default — do not hand-roll headers
    // here without Accept-Encoding. (Verified 2026-10-23, DESIGN.md §3.)
    // It also throws transient 503s under load (seen live 2026-10-23 while
    // curl got 200s on the same URL), so allow exactly one retry.
    var res = await _client.get(uri);
    if (res.statusCode == 503) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      res = await _client.get(uri);
    }
    if (res.statusCode != 200) {
      throw Exception('eCFR full text failed (${res.statusCode})');
    }
    return RegSection(
      ref: ref,
      bodyText: xmlToPlainText(_utf8(res)),
      sourceDate: date,
    );
  }

  /// Skeleton-grade extraction of eCFR section XML (DIV8/HEAD/P) to plain
  /// text. Paragraph-level only: tables/appendices flatten. See DESIGN.md §6.
  static String xmlToPlainText(String xml) {
    final paras = <String>[];
    final pRe = RegExp(
      r'<(?:P|HEAD)[^>]*>(.*?)</(?:P|HEAD)>',
      dotAll: true,
      caseSensitive: false,
    );
    for (final m in pRe.allMatches(xml)) {
      final text = _stripTags(m.group(1)!);
      if (text.isNotEmpty) paras.add(text);
    }
    if (paras.isEmpty) {
      final whole = _stripTags(xml);
      return whole.isEmpty ? 'No text returned for this section.' : whole;
    }
    return paras.join('\n\n');
  }

  static String _stripTags(String s) {
    var t = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    t = t
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
