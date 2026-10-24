// Core data models. Corpus-agnostic on purpose: a RegulationRef can point
// at a CFR section today and an AFI paragraph tomorrow.

/// A pointer to one readable unit of regulation (usually a section).
class RegulationRef {
  final String sourceId; // e.g. 'ecfr', 'sample'
  final int titleNumber; // CFR title; 0 for non-CFR corpora later
  final String? part;
  final String? section; // e.g. '107.51'
  final String heading; // human heading, e.g. 'Operating limitations…'

  /// Exact display citation for sources that don't fit the CFR pattern,
  /// e.g. '49 U.S.C. § 44809' (a statute, not a CFR section).
  final String? citationLabel;

  const RegulationRef({
    required this.sourceId,
    required this.titleNumber,
    this.part,
    this.section,
    required this.heading,
    this.citationLabel,
  });

  /// Display citation, e.g. "14 CFR 107.51".
  String get citation {
    if (citationLabel != null) return citationLabel!;
    if (section != null && section!.isNotEmpty) {
      return '$titleNumber CFR $section';
    }
    if (part != null && part!.isNotEmpty) return '$titleNumber CFR Part $part';
    return 'Title $titleNumber';
  }

  /// Stable identity for bookmarks / simplification lookup.
  String get key => '$sourceId|$citation';

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'titleNumber': titleNumber,
    'part': part,
    'section': section,
    'heading': heading,
    'citationLabel': citationLabel,
  };

  factory RegulationRef.fromJson(Map<String, dynamic> j) => RegulationRef(
    sourceId: j['sourceId'] as String,
    titleNumber: (j['titleNumber'] as num).toInt(),
    part: j['part'] as String?,
    section: j['section'] as String?,
    heading: j['heading'] as String? ?? '',
    citationLabel: j['citationLabel'] as String?,
  );

  @override
  bool operator ==(Object other) => other is RegulationRef && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class SearchHit {
  final RegulationRef ref;
  final String excerpt; // plain text, highlight markup already stripped
  final String? titleName;

  const SearchHit({required this.ref, required this.excerpt, this.titleName});
}

class CfrTitle {
  final int number;
  final String name;
  final String? upToDateAsOf; // YYYY-MM-DD from eCFR
  final bool reserved;

  const CfrTitle({
    required this.number,
    required this.name,
    this.upToDateAsOf,
    this.reserved = false,
  });

  factory CfrTitle.fromJson(Map<String, dynamic> j) => CfrTitle(
    number: (j['number'] as num).toInt(),
    name: j['name'] as String? ?? '',
    upToDateAsOf: j['up_to_date_as_of'] as String?,
    reserved: j['reserved'] as bool? ?? false,
  );
}

class Agency {
  final String name;
  final String slug;
  final List<String> cfrReferences; // e.g. 'Title 14, Chapter I'

  const Agency({
    required this.name,
    required this.slug,
    this.cfrReferences = const [],
  });
}

/// One node of a title's structure tree (title → chapter → part → section).
class StructureNode {
  final String identifier;
  final String label;
  final String type; // title | chapter | subchapter | part | section | …
  final List<StructureNode> children;

  const StructureNode({
    required this.identifier,
    required this.label,
    required this.type,
    this.children = const [],
  });

  factory StructureNode.fromJson(Map<String, dynamic> j) => StructureNode(
    identifier: j['identifier']?.toString() ?? '',
    label: (j['label_level'] as String?)?.trim().isNotEmpty == true
        ? (j['label'] as String? ?? j['identifier']?.toString() ?? '')
        : (j['label'] as String? ?? j['identifier']?.toString() ?? ''),
    type: j['type'] as String? ?? '',
    children: (j['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StructureNode.fromJson)
        .toList(),
  );

  /// All descendant nodes of [type], flattened.
  List<StructureNode> findAll(String type) {
    final out = <StructureNode>[];
    void walk(StructureNode n) {
      if (n.type == type) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(this);
    return out;
  }
}

/// The full original text of one section — the thing that legally counts.
class RegSection {
  final RegulationRef ref;
  final String bodyText; // paragraphs joined by blank lines
  final String? sourceDate; // version date the text was pulled for

  const RegSection({
    required this.ref,
    required this.bodyText,
    this.sourceDate,
  });
}

/// A plain-English explanation of a [RegSection].
///
/// Guardrail: [disclaimer] is a constant, not a field — no simplification
/// engine can forget to include it. See DESIGN.md §4.
class Simplification {
  final String citation;
  final String plainText;
  final List<String> keyPoints;

  /// True for the hand-written stub / not-yet-written results. The UI badges
  /// stub output so nobody mistakes a sample for full coverage.
  final bool isStub;

  /// True when no plain version exists yet (plainText is reading guidance,
  /// NOT an explanation). The service never fabricates one.
  final bool isMissing;

  const Simplification({
    required this.citation,
    required this.plainText,
    this.keyPoints = const [],
    this.isStub = false,
    this.isMissing = false,
  });

  static const String disclaimer =
      'This is a plain-English explanation to help you understand. '
      'It is not the law. The original text is what legally counts.';

  static const String targetReadingLevel = 'About an 8th-grade reading level.';
}

class Bookmark {
  final RegulationRef ref;
  final DateTime savedAt;

  const Bookmark({required this.ref, required this.savedAt});

  Map<String, dynamic> toJson() => {
    'ref': ref.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    ref: RegulationRef.fromJson(j['ref'] as Map<String, dynamic>),
    savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
