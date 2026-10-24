import '../airspace/airspace_service.dart';
import '../states/states_matrix.dart';

/// Shepherd mode: the fused view. One aircraft, one location — every
/// layer we have (FAA airspace grid, civil rules, DoW group framework,
/// munitions status) summarized in one place, with each layer labelled
/// as REAL data, FRAMEWORK, or RESEARCHING. Nothing fakes a layer that
/// isn't built yet. See DESIGN.md §10.

enum UasGroup { g1, g2, g3, g4, g5 }

class UasGroupInfo {
  final UasGroup group;
  final String label;
  final String weightBand;
  final String altitudeBand;
  final String speedBand;
  final String examples;
  final String civilNote;

  const UasGroupInfo({
    required this.group,
    required this.label,
    required this.weightBand,
    required this.altitudeBand,
    required this.speedBand,
    required this.examples,
    required this.civilNote,
  });
}

/// DoD joint UAS groups (highest-attribute rule: any one attribute in a
/// higher group puts the system in that group).
const Map<UasGroup, UasGroupInfo> uasGroups = {
  UasGroup.g1: UasGroupInfo(
    group: UasGroup.g1,
    label: 'Group 1',
    weightBand: '0–20 lb',
    altitudeBand: 'under 1,200 ft AGL',
    speedBand: 'under 100 knots',
    examples: 'RQ-11 Raven, Puma, WASP, FPV quads, most small drones',
    civilNote:
        'Squarely inside the civil small-drone weight range — when flown '
        'civilly, recreational / Part 107 rules can apply (registration '
        'kicks in at 0.55 lb).',
  ),
  UasGroup.g2: UasGroupInfo(
    group: UasGroup.g2,
    label: 'Group 2',
    weightBand: '21–55 lb',
    altitudeBand: 'under 3,500 ft AGL',
    speedBand: 'under 250 knots',
    examples: 'ScanEagle, Flexrotor',
    civilNote:
        'At the very top of the civil range: 55 lb is the hard ceiling '
        'for recreational and Part 107 flight, and registration + Remote '
        'ID are always required at this weight.',
  ),
  UasGroup.g3: UasGroupInfo(
    group: UasGroup.g3,
    label: 'Group 3',
    weightBand: 'under 1,320 lb',
    altitudeBand: 'under 18,000 ft MSL',
    speedBand: 'under 250 knots',
    examples: 'RQ-7B Shadow, RQ-21 Blackjack, V-BAT',
    civilNote:
        'Above the 55 lb civil small-drone ceiling in almost every '
        'configuration — civil flight needs certification paths outside '
        'Part 107, and NAS access normally runs through FAA '
        'authorization (COA) for public/military operations.',
  ),
  UasGroup.g4: UasGroupInfo(
    group: UasGroup.g4,
    label: 'Group 4',
    weightBand: 'over 1,320 lb',
    altitudeBand: 'under 18,000 ft MSL',
    speedBand: 'any speed',
    examples: 'MQ-1C Gray Eagle, MQ-8 Fire Scout',
    civilNote:
        'Large UAS. No recreational/Part 107 path exists; airspace '
        'access is by COA, restricted areas, or segregated operations.',
  ),
  UasGroup.g5: UasGroupInfo(
    group: UasGroup.g5,
    label: 'Group 5',
    weightBand: 'over 1,320 lb',
    altitudeBand: 'over 18,000 ft MSL',
    speedBand: 'any speed',
    examples: 'MQ-9 Reaper, RQ-4 Global Hawk, MQ-4C Triton',
    civilNote:
        'Large, high-altitude UAS operating in the flight levels — '
        'governed by military airworthiness, COAs, and ATC integration, '
        'not small-drone rules.',
  ),
};

enum ShepherdTone { ok, info, warn, block }

class ShepherdSection {
  final String title;

  /// REAL (measured/published data), FRAMEWORK (established public
  /// framework), or RESEARCHING (layer not built yet — stated plainly).
  final String layerKind;
  final ShepherdTone tone;
  final List<String> lines;

  const ShepherdSection({
    required this.title,
    required this.layerKind,
    required this.tone,
    required this.lines,
  });
}

/// Build the fused summary. [check] is the grid result for the chosen
/// location (current fix or manually entered coordinates — pre-planning).
List<ShepherdSection> buildShepherdSummary({
  required UasGroup group,
  required bool liveMunitions,
  required AirspaceCheck? check,
  required String locationLabel,
  List<StateMatrixEntry>? stateMatrix,
}) {
  final info = uasGroups[group]!;
  final sections = <ShepherdSection>[];

  // --- Location & airspace (REAL data) ---
  switch (check) {
    case GridHitCheck c when c.ceilingFt == 0:
      sections.add(
        const ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.block,
          lines: [
            'This location is a 0-foot LAANC grid square: no '
                'pre-authorized small-drone operations there at any '
                'altitude.',
            'The grid is informational, not an approval or a ban — but '
                'any flight here needs manual FAA coordination (or, for '
                'military ops, the applicable airspace authority).',
          ],
        ),
      );
    case GridHitCheck c:
      sections.add(
        ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.info,
          lines: [
            'LAANC grid ceiling at this location: ${c.ceilingFt} feet — '
                'the most LAANC can pre-approve here.',
            'The grid does not authorize anything by itself, and it does '
                'not show TFRs, NOTAMs, stadium restrictions, or '
                'restricted/prohibited areas.',
          ],
        ),
      );
    case NoGridCheck _:
      sections.add(
        const ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.ok,
          lines: [
            'No LAANC grid square covers this location — usually '
                'uncontrolled (Class G) airspace for small-drone '
                'purposes.',
            'Grids only map controlled airspace near airports. Restricted '
                'areas, TFRs, and local rules are not shown — check '
                'B4UFLY before flight.',
          ],
        ),
      );
    case OutsideCoverageCheck _:
      sections.add(
        const ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.warn,
          lines: [
            'This location is outside the US facility-map dataset, so '
                'Shepherd has no grid data for it. No airspace conclusion '
                'is drawn.',
          ],
        ),
      );
    case LocationFailedCheck f:
      sections.add(
        ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.warn,
          lines: [
            'Location check failed: ${f.reason}',
            'No airspace conclusion is drawn from a location we could '
                'not check.',
          ],
        ),
      );
    case null:
      sections.add(
        const ShepherdSection(
          title: 'Location & airspace',
          layerKind: 'REAL DATA',
          tone: ShepherdTone.warn,
          lines: ['No location was checked.'],
        ),
      );
  }

  // --- The aircraft (FRAMEWORK) ---
  sections.add(
    ShepherdSection(
      title: 'Your aircraft — ${info.label}',
      layerKind: 'FRAMEWORK',
      tone: ShepherdTone.info,
      lines: [
        '${info.weightBand} · ${info.altitudeBand} · ${info.speedBand} '
            '(any one attribute in a higher group puts the aircraft in '
            'that group).',
        'Typical: ${info.examples}.',
        info.civilNote,
      ],
    ),
  );

  // --- Live munitions ---
  if (liveMunitions) {
    sections.add(
      const ShepherdSection(
        title: 'Live munitions — Department of War rules',
        layerKind: 'FRAMEWORK',
        tone: ShepherdTone.block,
        lines: [
          'An armed aircraft is never authorized by civil drone rules or '
              'by LAANC. Live-munitions employment runs entirely through '
              'the military chain: service and DoW authorizations, '
              'weapons safety and range control, and designated '
              'restricted/range airspace (or a specific FAA authorization '
              'for the operation).',
          'One-way attack / loitering munitions are employed AS munitions '
              'under the same principle, whatever their weight class.',
          'Governing publications and approval authorities (from the '
              'public DoW source map): military UAS fly as public '
              'aircraft under FAA Certificates of Authorization, not '
              'Part 107 (DoD OGC determination, 16 May 2019, cited in '
              'DAFMAN 11-501 ¶1.1). Air Force: AFPD 11-5 → DAFMAN 11-501 '
              '(approval chain AF/A3S → MAJCOM → installation → squadron '
              '→ unit sUAS program manager). Army: AR 95-1. Navy/USMC: '
              'OPNAVINST 3710.7 + NAVAIRINST 13034.1 flight clearances; '
              'USMC NAVMC 3500.107. Space Force flies under the Air '
              'Force stack — it has no standalone UAS publications.',
          'Shepherd names the governing framework and authorities '
              'only — it gives no employment guidance and clears '
              'nothing.',
        ],
      ),
    );
  } else {
    sections.add(
      const ShepherdSection(
        title: 'Live munitions',
        layerKind: 'FRAMEWORK',
        tone: ShepherdTone.ok,
        lines: [
          'No live munitions: the aircraft is unarmed, so no weapons-'
              'employment layer applies. Civil rules (or standard military '
              'training rules for duty flights) govern.',
        ],
      ),
    );
  }

  // --- Civil layer pointer ---
  if (group == UasGroup.g1 || group == UasGroup.g2) {
    sections.add(
      const ShepherdSection(
        title: 'Civil (FAA) layer',
        layerKind: 'REAL DATA',
        tone: ShepherdTone.info,
        lines: [
          'This weight class can be flown civilly. For the full '
              'determination — registration, TRUST / Remote Pilot '
              'certificate, Remote ID, and your flight plan — use the '
              'Can I Fly checker; Shepherd has already told you the '
              'airspace part above.',
        ],
      ),
    );
  } else {
    sections.add(
      const ShepherdSection(
        title: 'Civil (FAA) layer',
        layerKind: 'FRAMEWORK',
        tone: ShepherdTone.warn,
        lines: [
          'Group 3 and above sit outside the civil small-drone rulebook '
              '(recreational and Part 107 both cap at 55 lb). Civil '
              'operations at this size use type certification, exemptions, '
              'or public-aircraft COAs — a different process than the '
              'Can I Fly checker.',
        ],
      ),
    );
  }

  // --- State + DoW layers: maps landed, corpus ingest is next. The
  // sections stay labelled RESEARCHING — the maps are the plan, not yet
  // ingested regulation text — but they already name what governs.
  final matchedState = stateMatrix == null
      ? null
      : matchStateInText(locationLabel, stateMatrix);
  if (matchedState != null && !matchedState.hasData) {
    sections.add(
      ShepherdSection(
        title: 'State rules layer — ${matchedState.name}',
        layerKind: 'RESEARCHING',
        tone: ShepherdTone.info,
        lines: [
          matchedState.caveat.isNotEmpty
              ? matchedState.caveat
              : 'This state\'s matrix is researched but still being '
                  'verified, so no state values are published yet.',
          'Until it lands: the federal floor applies, and the state '
              'legislature\'s official code site is the source to '
              'trust.',
        ],
      ),
    );
  } else if (matchedState != null) {
    final s = matchedState;
    sections.add(
      ShepherdSection(
        title: 'State rules layer — ${s.name}',
        layerKind: 'REAL DATA',
        tone: ShepherdTone.info,
        lines: [
          if (liveMunitions)
            'Context for local awareness — state civil drone law '
                'does not govern federal military operations.',
          if (s.noDroneLawFound)
            'No state drone law found on top of the federal rules '
                'for ${s.name} — verified ${s.verifiedDate} across '
                'all 13 categories.'
          else ...[
            for (final c in s.substantive.take(6))
              '${c.name}: ${c.headline}',
            if (s.substantive.length > 6)
              '…plus ${s.substantive.length - 6} more categories in '
                  'the full matrix.',
          ],
          'Full 13-category matrix with citations: Browse → State '
              'Regulations → ${s.name}. Verified ${s.verifiedDate} — '
              'state law changes (North Carolina\'s drone permit was '
              'repealed Dec 1, 2024 while the state still printed '
              'it), so mind the date.',
          if (s.status == StateMatrixStatus.partial)
            'Partial verification: a verified core with flagged gaps '
                '— see the state\'s research note in the matrix.',
        ],
      ),
    );
  } else {
    sections.add(
      const ShepherdSection(
        title: 'State rules layer',
        layerKind: 'RESEARCHING',
        tone: ShepherdTone.info,
        lines: [
          'All 50 states now have a researched 13-category drone-law '
              'matrix in this app (Browse → State Regulations), each '
              'with its verification date. This summary pulls your '
              'state in automatically when the location is entered '
              'as a place name (e.g. "Fayetteville, North Carolina") '
              '— raw coordinates don\'t say which state they are in.',
          'One caution the research keeps proving: state drone law '
              'goes stale quietly — North Carolina\'s knowledge-test '
              'and permit sections were repealed Dec 1, 2024 while '
              'the state still printed them. Always check the '
              'verified date.',
        ],
      ),
    );
  }
  sections.add(
    const ShepherdSection(
      title: 'Department of War publications layer',
      layerKind: 'RESEARCHING',
      tone: ShepherdTone.info,
      lines: [
        'The DoW source map has landed: 22 mapped entries — DoD '
            'issuances, the Groups 1–5 definitions, the public-aircraft '
            '/ FAA COA path, and each service\'s stack (Air Force: '
            'DAFMAN 11-501/11-502; Army: AR 95-1; Navy: OPNAVINST 3710.7 '
            '+ NAVAIR flight clearances; Marines: NAVMC 3500.107 + '
            'MARADMINs; Space Force: governed under the Air Force '
            'stack — no standalone USSF publications).',
        'Corpus ingest from those public sources is next. Anything the '
            'map marks restricted or unread stays a titled placeholder: '
            'CAC-gated material is link-out only and is never '
            'summarized here.',
      ],
    ),
  );

  return sections;
}
