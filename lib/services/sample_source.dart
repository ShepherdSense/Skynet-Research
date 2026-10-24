import '../models/models.dart';
import 'regulation_source.dart';

/// Canned offline corpus: three real sections, zero network. Powers the
/// first-run demo and the test suite, and proves the whole flow
/// (search → read → simplify → bookmark) with no connection and no key.
class SampleSource implements RegulationSource {
  @override
  String get id => 'sample';

  @override
  String get displayName => 'Sample sections (offline)';

  static final Map<String, RegSection> _sections = {
    '14 CFR 107.51': RegSection(
      ref: const RegulationRef(
        sourceId: 'sample',
        titleNumber: 14,
        part: '107',
        section: '107.51',
        heading: 'Operating limitations for small unmanned aircraft.',
      ),
      sourceDate: 'sample',
      bodyText:
          '§ 107.51 Operating limitations for small unmanned aircraft.\n\n'
          'A remote pilot in command and the person manipulating the flight '
          'controls of the small unmanned aircraft system must comply with '
          'all of the following operating limitations when operating a small '
          'unmanned aircraft system:\n\n'
          '(a) The groundspeed of the small unmanned aircraft may not '
          'exceed 87 knots (100 miles per hour).\n\n'
          '(b) The altitude of the small unmanned aircraft cannot be higher '
          'than 400 feet above ground level, unless the small unmanned '
          'aircraft: (1) Is flown within a 400-foot radius of a structure; '
          'and (2) Does not fly higher than 400 feet above the structure\'s '
          'immediate uppermost limit.\n\n'
          '(c) The minimum flight visibility, as observed from the location '
          'of the control station must be no less than 3 statute miles.\n\n'
          '(d) The minimum distance of the small unmanned aircraft from '
          'clouds must be no less than: (1) 500 feet below the cloud; and '
          '(2) 2,000 feet horizontally from the cloud.',
    ),
    '14 CFR 107.49': RegSection(
      ref: const RegulationRef(
        sourceId: 'sample',
        titleNumber: 14,
        part: '107',
        section: '107.49',
        heading: 'Preflight familiarization, inspections, and actions.',
      ),
      sourceDate: 'sample',
      bodyText:
          '§ 107.49 Preflight familiarization, inspections, and actions.\n\n'
          'Prior to beginning flight, the remote pilot in command must:\n\n'
          '(a) Be familiar with, and have available, all information '
          'necessary to ensure the flight can be safely conducted in '
          'compliance with this part. This includes information regarding '
          'local weather conditions, the airspace and any flight '
          'restrictions in the area of operation, the location of persons '
          'and property on the surface, and other ground hazards.\n\n'
          '(b) Inform all persons directly participating in the operation '
          'of the small unmanned aircraft system of the operating '
          'conditions, emergency procedures, contingency procedures, roles '
          'and responsibilities, and potential hazards.\n\n'
          '(c) Inspect the small unmanned aircraft system to ensure it is '
          'in a condition for safe operation and that its systems, '
          'including communications and power systems, are sufficient for '
          'the planned operation.',
    ),
    '29 CFR 1910.95': RegSection(
      ref: const RegulationRef(
        sourceId: 'sample',
        titleNumber: 29,
        part: '1910',
        section: '1910.95',
        heading: 'Occupational noise exposure.',
      ),
      sourceDate: 'sample',
      bodyText:
          '§ 1910.95 Occupational noise exposure. (Sample excerpt — the full '
          'section is much longer.)\n\n'
          '(a) Protection against the effects of noise exposure shall be '
          'provided when the sound levels exceed those shown in Table G-16 '
          'when measured on the A scale of a standard sound level meter at '
          'slow response.\n\n'
          '(b)(1) When employees are subjected to sound exceeding those '
          'listed in Table G-16, feasible administrative or engineering '
          'controls shall be utilized. If such controls fail to reduce '
          'sound levels within the levels of Table G-16, personal '
          'protective equipment shall be provided and used to reduce sound '
          'levels.\n\n'
          '(c)(1) The employer shall administer a continuing, effective '
          'hearing conservation program whenever employee noise exposures '
          'equal or exceed an 8-hour time-weighted average sound level '
          '(TWA) of 85 decibels measured on the A scale.',
    ),
  };

  static List<RegSection> get samples => _sections.values.toList();

  /// Everyday words users type that the legal text phrases differently.
  /// (Live eCFR search handles this server-side; the offline sample matcher
  /// needs the help.)
  static const Map<String, String> _aliases = {
    'drone': 'unmanned',
    'drones': 'unmanned',
    'uav': 'unmanned',
    'uas': 'unmanned',
  };

  @override
  Future<List<SearchHit>> search(
    String query, {
    int page = 1,
    int perPage = 20,
    String? agencySlug,
  }) async {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    bool matches(RegSection s) {
      final haystack = '${s.ref.citation} ${s.ref.heading} ${s.bodyText}'
          .toLowerCase();
      return tokens.every(
        (t) =>
            haystack.contains(t) ||
            (_aliases[t] != null && haystack.contains(_aliases[t]!)),
      );
    }

    return _sections.values
        .where(matches)
        .map(
          (s) => SearchHit(
            ref: s.ref,
            excerpt: s.bodyText
                .replaceAll('\n\n', ' ')
                .substring(
                  0,
                  s.bodyText.length > 220 ? 220 : s.bodyText.length,
                ),
          ),
        )
        .toList();
  }

  @override
  Future<List<CfrTitle>> titles() async => const [
    CfrTitle(number: 14, name: 'Aeronautics and Space'),
    CfrTitle(number: 29, name: 'Labor'),
  ];

  @override
  Future<List<Agency>> agencies() async => const [
    Agency(
      name: 'Federal Aviation Administration',
      slug: 'federal-aviation-administration',
      cfrReferences: ['Title 14, Chapter I'],
    ),
    Agency(
      name: 'Occupational Safety and Health Administration',
      slug: 'occupational-safety-and-health-administration',
      cfrReferences: ['Title 29, Chapter XVII'],
    ),
  ];

  @override
  Future<StructureNode> structure(int titleNumber, {String? date}) async {
    final sections = _sections.values
        .where((s) => s.ref.titleNumber == titleNumber)
        .map(
          (s) => StructureNode(
            identifier: s.ref.section!,
            label: '§ ${s.ref.section} ${s.ref.heading}',
            type: 'section',
          ),
        )
        .toList();
    return StructureNode(
      identifier: '$titleNumber',
      label: 'Title $titleNumber',
      type: 'title',
      children: [
        StructureNode(
          identifier: 'sample-part',
          label: 'Sample part',
          type: 'part',
          children: sections,
        ),
      ],
    );
  }

  @override
  Future<RegSection> fetchSection(RegulationRef ref) async {
    final hit = _sections[ref.citation];
    if (hit == null) {
      throw Exception('Not in the sample set: ${ref.citation}');
    }
    return hit;
  }
}
