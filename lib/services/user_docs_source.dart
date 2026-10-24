import '../models/models.dart';
import '../state/user_docs_store.dart';
import '../userdocs/user_document.dart';
import 'regulation_source.dart';

/// The user's own added documents, exposed as a [RegulationSource] so
/// they flow through Search and the Reader exactly like an ingested
/// corpus — the adapter pattern doing its job (DESIGN.md §13).
/// Not part of the CFR structure: titles/agencies/structure are empty.
class UserDocsSource implements RegulationSource {
  final UserDocsStore store;

  UserDocsSource(this.store);

  @override
  String get id => 'userdocs';

  @override
  String get displayName => 'Your Documents';

  RegulationRef refFor(UserDocument doc) => RegulationRef(
        sourceId: id,
        titleNumber: 0,
        section: doc.id,
        heading: doc.title,
        citationLabel: doc.label,
      );

  @override
  Future<List<SearchHit>> search(
    String query, {
    int page = 1,
    int perPage = 20,
    String? agencySlug,
  }) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final doc in store.items) {
      final haystack =
          '${doc.title} ${doc.citation} ${doc.authority} ${doc.text}'
              .toLowerCase();
      if (!terms.every(haystack.contains)) continue;
      hits.add(SearchHit(ref: refFor(doc), excerpt: _excerpt(doc, terms)));
      if (hits.length >= perPage) break;
    }
    return hits;
  }

  String _excerpt(UserDocument doc, List<String> terms) {
    if (doc.isLinkOnly) {
      return 'Link you added — ${doc.authority}. Tap to read the details.';
    }
    final lower = doc.text.toLowerCase();
    var start = 0;
    for (final t in terms) {
      final i = lower.indexOf(t);
      if (i >= 0) {
        start = i;
        break;
      }
    }
    final from = (start - 60).clamp(0, doc.text.length);
    final to = (start + 160).clamp(0, doc.text.length);
    final raw = doc.text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ');
    return '${from > 0 ? '…' : ''}$raw${to < doc.text.length ? '…' : ''}';
  }

  @override
  Future<List<CfrTitle>> titles() async => const [];

  @override
  Future<List<Agency>> agencies() async => const [];

  @override
  Future<StructureNode> structure(int titleNumber, {String? date}) async =>
      StructureNode(
        type: 'userdocs',
        identifier: 'userdocs',
        label: 'Your Documents',
        children: const [],
      );

  @override
  Future<RegSection> fetchSection(RegulationRef ref) async {
    final doc = ref.section != null ? store.byId(ref.section!) : null;
    if (doc == null) {
      return RegSection(
        ref: ref,
        bodyText: 'This document is no longer in your library. It may '
            'have been removed on this device.',
      );
    }
    final body = doc.isLinkOnly
        ? 'You added this as a link to an official document.\n\n'
            '${doc.sourceUrl ?? ''}\n\n'
            'Open the link from the Your Documents page to read it at '
            'the source. To read it inside the app — with search and '
            'the plain-English view alongside — add the document\'s '
            'text instead.'
        : doc.text;
    return RegSection(
      ref: refFor(doc),
      bodyText: body,
      sourceDate: 'Added by you · ${doc.authority} · '
          '${doc.addedAt.toIso8601String().substring(0, 10)}',
    );
  }
}
