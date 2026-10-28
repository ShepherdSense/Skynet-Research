import '../models/models.dart';

/// One deciding (or related) regulation inside a research brief.
/// [ref] is non-null only when the citation can actually be opened in
/// the Reader today (a live eCFR section or part). Statutes, state
/// laws, and DoW publications that aren't ingested yet are cited by
/// label with ref == null — named honestly, never dressed up as
/// openable text.
class BriefCitation {
  final String label;
  final String why;
  final RegulationRef? ref;

  const BriefCitation({required this.label, required this.why, this.ref});

  bool get openable => ref != null;

  Map<String, dynamic> toJson() => {
        'label': label,
        'why': why,
        'ref': ref?.toJson(),
      };

  factory BriefCitation.fromJson(Map<String, dynamic> j) => BriefCitation(
        label: j['label'] as String,
        why: j['why'] as String,
        ref: j['ref'] == null
            ? null
            : RegulationRef.fromJson(j['ref'] as Map<String, dynamic>),
      );
}

/// A research brief: the answer to a plain-language question, shaped
/// for a non-lawyer. See DESIGN.md §14.
///
/// Anatomy (fixed — every brief has all of it):
/// 1. [shortAnswer] — plain English first.
/// 2. [why] — the regulations that actually decide it, cited.
/// 3. [gaps] — what we don't know. Never empty by accident on purpose:
///    a brief with no gaps says so explicitly.
/// 4. [followUps] — dig-deeper questions worth asking next.
class ResearchBrief {
  final String question;
  final bool covered;
  final String shortAnswer;
  final List<BriefCitation> why;
  final List<String> gaps;
  final List<String> followUps;

  /// True while briefs come from the hand-written stub.
  final bool isStub;

  const ResearchBrief({
    required this.question,
    required this.covered,
    required this.shortAnswer,
    this.why = const [],
    this.gaps = const [],
    this.followUps = const [],
    this.isStub = true,
  });

  static const String disclaimer =
      'Research briefs are guidance and explanation — not legal '
      'advice. The original regulation text is what legally counts.';

  Map<String, dynamic> toJson() => {
        'question': question,
        'covered': covered,
        'shortAnswer': shortAnswer,
        'why': why.map((c) => c.toJson()).toList(),
        'gaps': gaps,
        'followUps': followUps,
        'isStub': isStub,
      };

  factory ResearchBrief.fromJson(Map<String, dynamic> j) => ResearchBrief(
        question: j['question'] as String,
        covered: j['covered'] as bool,
        shortAnswer: j['shortAnswer'] as String,
        why: ((j['why'] as List?) ?? [])
            .map((e) => BriefCitation.fromJson(e as Map<String, dynamic>))
            .toList(),
        gaps: ((j['gaps'] as List?) ?? []).cast<String>(),
        followUps: ((j['followUps'] as List?) ?? []).cast<String>(),
        isStub: (j['isStub'] as bool?) ?? true,
      );
}

/// The research engine behind an interface — same pattern as
/// RegulationSource and SimplificationService. Today: a hand-written
/// stub over the mapped drone material. The real engine (the
/// still-open cloud vs on-device vs curated question) slots in behind
/// this interface without UI changes.
abstract class ResearchService {
  Future<ResearchBrief> ask(String question);
  List<String> get exampleQuestions;
}

RegulationRef _cfr(String part, String? section, String heading,
        {String? label}) =>
    RegulationRef(
      sourceId: 'ecfr',
      titleNumber: 14,
      part: part,
      section: section,
      heading: heading,
      citationLabel: label,
    );

class _Topic {
  final List<String> keywords;
  final ResearchBrief Function(String q) build;
  const _Topic(this.keywords, this.build);
}

/// Hand-written stub: curated briefs over the material the research
/// maps and the fly-checker already verified (FAA drone rules, NC
/// state law, the DoW framework). Anything outside that range gets an
/// honest not-covered brief — gaps named, no fabricated answer.
class StubResearchService implements ResearchService {
  @override
  List<String> get exampleQuestions => _topics
      .map((t) => t.build('').question)
      .toList(growable: false);

  static final List<_Topic> _topics = [
    _Topic(
      ['over people', 'over a parade', 'parade', 'crowd', 'over people',
       'fly over people', 'spectator', 'concert', 'over a person',
       'open-air', 'gathering'],
      (q) => ResearchBrief(
        question: 'Can I fly my drone over a parade?',
        covered: true,
        shortAnswer:
            'Almost certainly not the way you\'re picturing it. Flying '
            'a drone over people — and especially over a crowd like a '
            'parade — is one of the most restricted things you can do. '
            'Recreational flyers must stay away from people who aren\'t '
            'part of the flight. Commercial (Part 107) pilots may only '
            'fly over people when the drone and the operation fit one '
            'of the FAA\'s categories in Subpart D, and sustained '
            'flight over an open-air gathering like a parade is '
            'outside those categories for nearly every drone. When in '
            'doubt: film from the side, not from above.',
        why: [
          BriefCitation(
            label: '14 CFR 107.39',
            why: 'The rule that ties flying over people to the '
                'Subpart D categories.',
            ref: _cfr('107', '107.39', 'Operations over human beings'),
          ),
          BriefCitation(
            label: '14 CFR Part 107, Subpart D',
            why: 'The four categories of drones/operations allowed '
                'over people, and their conditions.',
            ref: _cfr('107', null, 'Operations over human beings',
                label: '14 CFR Part 107, Subpart D'),
          ),
          const BriefCitation(
            label: '49 U.S.C. § 44809',
            why: 'Recreational flyers must follow community safety '
                'guidelines, which prohibit flying over people.',
          ),
        ],
        gaps: [
          'Whether a specific drone model qualifies for a Subpart D '
              'category depends on its FAA declaration of compliance — '
              'the declaration database isn\'t readable from inside '
              'the app yet, so check your exact model before relying '
              'on a category.',
          'Local rules for the parade itself (permits, police '
              'restrictions, temporary flight restrictions for big '
              'events) aren\'t in the app yet.',
        ],
        followUps: [
          'What are the Subpart D categories for flying over people?',
          'Can I fly my drone at night?',
          'Do I need permission to fly near an airport?',
        ],
      ),
    ),
    _Topic(
      ['north carolina', ' nc', 'nc ', 'roof inspection', 'roof',
       'state permit', 'permit to film', 'film a roof', 'charlotte',
       'raleigh'],
      (q) => ResearchBrief(
        question: 'Do I need a state permit to film a roof inspection '
            'in NC?',
        covered: true,
        shortAnswer:
            'No state permit — not anymore. North Carolina used to '
            'require a state knowledge test and a commercial drone '
            'permit, but that law was repealed on December 1, 2024. '
            'Most websites still describe the old permit because the '
            'state still prints the repealed text — don\'t let them '
            'fool you. What you do still need: an FAA Remote Pilot '
            'certificate (roof inspection work is commercial flying '
            'under Part 107), the property owner\'s permission to '
            'launch and land, and care with North Carolina\'s privacy '
            'law — filming people or their property in a way that '
            'counts as surveillance without consent can create civil '
            'liability.',
        why: [
          BriefCitation(
            label: '14 CFR 107.61',
            why: 'Who may fly commercially: the Remote Pilot '
                'certificate requirement.',
            ref: _cfr('107', '107.61', 'Eligibility'),
          ),
          const BriefCitation(
            label: 'N.C.G.S. §§ 63-95/96 — REPEALED Dec 1, 2024',
            why: 'The former NC knowledge test and commercial permit. '
                'Repealed by S.L. 2024-15; still printed on the '
                'legislature\'s site, but not current law.',
          ),
          const BriefCitation(
            label: 'N.C.G.S. § 15A-300.1',
            why: 'North Carolina\'s drone privacy/surveillance '
                'statute — consent-based, with a civil action and '
                '\$5,000 per published photo/video.',
          ),
          const BriefCitation(
            label: 'N.C.G.S. § 15A-300.2',
            why: 'No launching or landing from state or private '
                'property without the owner\'s consent.',
          ),
        ],
        gaps: [
          'Research briefs are still written for North Carolina '
              'only. The other 49 states now have researched matrix '
              'data in Browse → State Regulations (with verification '
              'dates) — check your state there; this brief does not '
              'speak for them.',
          'The state-park takeoff/landing rule text was flagged '
              'unverified in the research (secondary sources only).',
          'City and county ordinances for the specific property '
              'aren\'t in the app yet.',
        ],
        followUps: [
          'Can I fly my drone over a parade?',
          'Do I have to register my drone?',
          'What changed in the new Part 107?',
        ],
      ),
    ),
    _Topic(
      ['what changed', 'changed in', 'new part 107', 'part 107 update',
       '107 changes', 'amendment', 'new rules', 'latest rules'],
      (q) => ResearchBrief(
        question: 'What changed in the new Part 107?',
        covered: true,
        shortAnswer:
            'Three changes matter most. (1) Flying over people and at '
            'night became possible under conditions — the 2021 rule '
            'created the Subpart D categories for over-people flight '
            'and let certificated pilots fly at night after updated '
            'training, with an anti-collision light. (2) Remote ID '
            'arrived as its own rulebook (Part 89): most drones must '
            'broadcast identification, and compliance has been '
            'required since 2023–24. (3) Recreational flyers got the '
            'TRUST safety test (free, online) under the recreational '
            'exception statute. The statute itself was amended again '
            'by the FAA Reauthorization Act of 2024 — see the gap '
            'note below before quoting it.',
        why: [
          BriefCitation(
            label: '14 CFR Part 89',
            why: 'Remote Identification — the broadcast-ID rulebook '
                'that now sits beside Part 107.',
            ref: _cfr('89', null, 'Remote Identification of Unmanned '
                'Aircraft', label: '14 CFR Part 89'),
          ),
          BriefCitation(
            label: '14 CFR 107.29',
            why: 'The night-flying rule as amended: updated training '
                'plus a 3-mile anti-collision light.',
            ref: _cfr('107', '107.29', 'Operation at night'),
          ),
          BriefCitation(
            label: '14 CFR Part 107, Subpart D',
            why: 'The over-people categories created by the 2021 '
                'rule.',
            ref: _cfr('107', null, 'Operations over human beings',
                label: '14 CFR Part 107, Subpart D'),
          ),
          const BriefCitation(
            label: '49 U.S.C. § 44809',
            why: 'The recreational exception, including TRUST — '
                'amended by Pub. L. 118-63 (2024).',
          ),
        ],
        gaps: [
          'The consolidated post-2024 text of § 44809 was flagged '
              'UNREAD in the research maps — the amendment is '
              'confirmed, but this brief won\'t quote the new '
              'statutory language until the current text is pulled.',
          'This brief covers the headline changes, not every '
              'amendment — the Reader shows the current eCFR text of '
              'each cited section.',
        ],
        followUps: [
          'Can I fly my drone at night?',
          'Do I have to register my drone?',
          'Can I fly my drone over a parade?',
        ],
      ),
    ),
    _Topic(
      ['night', 'after dark', 'in the dark', 'sunset'],
      (q) => ResearchBrief(
        question: 'Can I fly my drone at night?',
        covered: true,
        shortAnswer:
            'Yes — if you\'re set up for it. Part 107 pilots: '
            'complete the FAA\'s updated night training (it\'s part '
            'of the free recurrent training online) and put an '
            'anti-collision light on the drone that can be seen from '
            '3 miles away. Recreational flyers: the recreational '
            'rules follow community safety guidelines, which expect '
            'the same strobe light so others can see your drone. '
            'Either way, you still have to see the drone with your '
            'own eyes (or a helper\'s) the whole flight.',
        why: [
          BriefCitation(
            label: '14 CFR 107.29',
            why: 'The night rule: training currency plus the '
                '3-statute-mile anti-collision light.',
            ref: _cfr('107', '107.29', 'Operation at night'),
          ),
          BriefCitation(
            label: '14 CFR 107.31',
            why: 'Visual line of sight — it does not relax at night.',
            ref:
                _cfr('107', '107.31', 'Visual line of sight operation'),
          ),
          const BriefCitation(
            label: '49 U.S.C. § 44809',
            why: 'The recreational exception — night flight rides on '
                'community safety guidelines under it.',
          ),
        ],
        gaps: [
          'Whether your specific strobe meets the 3-mile visibility '
              'standard is a product-spec question the app can\'t '
              'verify.',
        ],
        followUps: [
          'What changed in the new Part 107?',
          'Do I have to register my drone?',
        ],
      ),
    ),
    _Topic(
      ['register', 'registration', 'dronezone', 'mark my drone'],
      (q) => ResearchBrief(
        question: 'Do I have to register my drone?',
        covered: true,
        shortAnswer:
            'If it weighs 250 grams (0.55 lb) or more at takeoff — '
            'yes, in almost every case. Registration is through the '
            'FAA\'s DroneZone site and costs \$5. Recreational '
            'flyers register once and put the same number on every '
            'drone they own; Part 107 pilots register each drone '
            'separately. Drones under 250 grams flown purely for fun '
            'don\'t need registration — but the moment a light drone '
            'is flown for work, it does.',
        why: [
          BriefCitation(
            label: '14 CFR Part 48',
            why: 'The registration and marking rulebook.',
            ref: _cfr('48', null,
                'Registration and Marking Requirements for Small '
                'Unmanned Aircraft',
                label: '14 CFR Part 48'),
          ),
          const BriefCitation(
            label: '49 U.S.C. § 44809',
            why: 'The recreational exception — its conditions ride on '
                'proper registration for drones that meet the '
                'weight threshold.',
          ),
        ],
        gaps: [
          'Registration happens on DroneZone (the FAA site) — the '
              'app explains the rule but can\'t register the drone '
              'for you.',
          'Government and military fleets register through their '
              'own channels, not DroneZone.',
        ],
        followUps: [
          'Can I fly my drone at night?',
          'Do I need permission to fly near an airport?',
        ],
      ),
    ),
    _Topic(
      ['laanc', 'controlled airspace', 'near an airport', 'airport',
       'airspace permission', 'authorization to fly in'],
      (q) => ResearchBrief(
        question: 'Do I need permission to fly near an airport?',
        covered: true,
        shortAnswer:
            'Inside controlled airspace (the airspace around most '
            'towered airports) — yes, you need FAA authorization '
            'before you fly, usually through LAANC, the automated '
            'approval system built into drone apps. The FAA\'s '
            'facility maps divide that airspace into squares, each '
            'with a maximum altitude LAANC can approve instantly. '
            'This app carries those maps: the Can I Fly checker and '
            'the Shepherd button both look your location up in the '
            'grid and tell you the ceiling — a 0-foot square means '
            'no instant approval, and you\'d need a manual '
            'authorization or a different spot.',
        why: [
          BriefCitation(
            label: '14 CFR 107.41',
            why: 'No operations in Class B/C/D or surface Class E '
                'airspace without prior authorization.',
            ref: _cfr('107', '107.41',
                'Operation in certain airspace'),
          ),
          BriefCitation(
            label: '14 CFR 107.51',
            why: 'The standing operating limits (400 ft, visibility, '
                'speed) that apply wherever you fly.',
            ref: _cfr('107', '107.51', 'Operating limitations'),
          ),
        ],
        gaps: [
          'The grid shows LAANC ceilings only. Temporary flight '
              'restrictions (TFRs) and NOTAMs have no public '
              'machine-readable feed — always check them before '
              'flight; the grid can\'t see them.',
          'LAANC approval itself happens in an FAA-approved app or '
              'DroneZone — this app tells you the ceiling, it '
              'doesn\'t grant the authorization.',
        ],
        followUps: [
          'Can I fly my drone over a parade?',
          'What changed in the new Part 107?',
          'Can I fly near the U.S.-Mexico border?',
        ],
      ),
    ),
    _Topic(
      ['southern border', 'mexico border', 'u.s.-mexico border',
       'border zone', 'border restriction', 'fly near the border',
       'cbp approval'],
      (q) => ResearchBrief(
        question: 'Can I fly near the U.S.-Mexico border?',
        covered: true,
        shortAnswer:
            'No unauthorized flights — from the surface to 400 feet '
            'above the ground, within 1 nautical mile north of the '
            'U.S.-Mexico border, from the Pacific coast to the Gulf '
            'coast, from October 20, 2026 through October 19, 2027. '
            'The band is designated National Defense Airspace. To fly '
            'inside it, you need approval from U.S. Customs and Border '
            'Protection, requested at least 48 hours ahead — and the '
            'approved categories are narrow (national defense, homeland '
            'security, law enforcement, firefighting, medical evacuation, '
            'search and rescue, disaster response, event operations). '
            'Ordinary commercial or hobby flying inside the zone has no '
            'approval route. This covers every drone, including '
            'recreational models under 250 grams.',
        why: [
          const BriefCitation(
            label: 'FAA NOTAMs ZLA 6/9954, ZAB 6/9978, ZHU 6/9956',
            why: 'The three NOTAMs that publish the restriction — the '
                'legally controlling source. They enforce it from 0000 '
                'UTC October 20, 2026 through 2359 UTC October 19, 2027.',
          ),
          const BriefCitation(
            label: 'DOT / DoW / DHS announcement, October 16, 2026',
            why: 'The joint announcement of the restriction, framing it '
                'as protection for southern border airspace and a '
                'counter to cartel drone activity. Its notice lists the '
                'run as October 19, 2026 to October 19, 2027 — the '
                'NOTAMs control where the two differ.',
          ),
          const BriefCitation(
            label: '49 U.S.C. § 40103(b)(3)',
            why: 'The statute behind National Defense Airspace '
                'designations.',
          ),
        ],
        gaps: [
          'The NOTAMs are the controlling source — check them before '
              'any flight near the border; press coverage and the '
              'announcement round the dates differently.',
          'This app cannot measure your distance to the border — '
              'confirm you are outside the 1-nautical-mile band '
              'yourself.',
          'The restriction is temporary (through October 19, 2027) '
              'and could be extended or changed.',
        ],
        followUps: [
          'Do I need permission to fly near an airport?',
          'Can I inspect a tower above the LAANC grid ceiling?',
        ],
      ),
    ),
    _Topic(
      ['tower inspection', 'inspect a tower', 'vertical structure',
       'above the grid ceiling', 'tower above the grid',
       'laanc grid ceiling', 'grid ceiling'],
      (q) => ResearchBrief(
        question: 'Can I inspect a tower above the LAANC grid ceiling?',
        covered: true,
        shortAnswer:
            'Yes — with a Part 107 airspace authorization from '
            'FAADroneZone, not LAANC. Under FAA Order JO 7200.23E '
            '¶3-5 (effective October 31, 2026), a visual-line-of-sight '
            'inspection of a vertical structure above the facility-map '
            'altitude is processed without coordinating with the air '
            'traffic facility, as long as it stays within a 100-foot '
            'radius of the structure and no more than 100 feet above '
            'its top — the rule\'s own words: "Remains within a '
            '100-foot radius of the structure and no more than 100 '
            'feet above the upper-most portion of the vertical '
            'structure." It must also stay at least 2 nautical miles '
            'from any airport, heliport, seaplane base, or vertiport '
            'landing surface (unless separately authorized), with 3 '
            'miles visibility and clear of clouds. You still need the '
            'authorization — the order removes the coordination step, '
            'not the authorization. Bridges and power lines do not '
            'qualify, and airspace delegated to the Department of War '
            'is excluded.',
        why: [
          const BriefCitation(
            label: 'FAA Order JO 7200.23E, ¶3-5',
            why: 'The standing procedure: no facility coordination for '
                'a qualifying vertical-structure inspection above the '
                'facility-map altitude. Issued October 1, 2026, '
                'effective October 31, 2026; cancels JO 7200.23D.',
          ),
          BriefCitation(
            label: '14 CFR 107.41',
            why: 'No operations in Class B/C/D or surface Class E '
                'airspace without prior authorization — the '
                'authorization this procedure processes.',
            ref: _cfr('107', '107.41',
                'Operation in certain airspace'),
          ),
        ],
        gaps: [
          'Before October 31, 2026, the old process applies — the '
              'provision is not yet in effect.',
          'FAADroneZone authorizations are manual, not instant — '
              'allow weeks.',
          'LAANC still cannot approve above the grid ceiling for any '
              'flight, inspection or not.',
        ],
        followUps: [
          'Do I need permission to fly near an airport?',
          'Can I fly near the U.S.-Mexico border?',
        ],
      ),
    ),
    _Topic(
      ['military', 'army', 'air force', 'navy', 'marine', 'government',
       'public aircraft', 'on duty', 'my unit', 'coa'],
      (q) => ResearchBrief(
        question: 'What rules apply when the military flies drones?',
        covered: true,
        shortAnswer:
            'Different rulebook entirely. Military drones don\'t fly '
            'under Part 107 — they fly as "public aircraft," and '
            'access to shared airspace runs through FAA Certificates '
            'of Authorization arranged service-by-service. Each '
            'service stacks its own publications on top: the Air '
            'Force runs on DAFMAN 11-501 (management and approvals) '
            'and 11-502 (Group 1–2 operations), the Army on AR 95-1, '
            'the Navy on its NATOPS umbrella plus NAVAIR flight '
            'clearances, the Marines on NAVMC 3500.107 and '
            'MARADMINs. Space Force has no drone publications of its '
            'own — it flies under the Air Force stack. The Shepherd '
            'button walks this flow directly: group, munitions, '
            'location.',
        why: [
          const BriefCitation(
            label: 'DAFMAN 11-501',
            why: 'Air Force sUAS management — approval chain, '
                'airworthiness, airspace coordination; states the '
                'public-aircraft position in ¶1.1.',
          ),
          const BriefCitation(
            label: 'AR 95-1',
            why: 'The Army\'s single flight regulation, manned and '
                'unmanned.',
          ),
          const BriefCitation(
            label: 'FAA Certificate of Authorization (COA)',
            why: 'The instrument that lets public aircraft into '
                'shared airspace.',
          ),
        ],
        gaps: [
          'The DoW publication corpus is mapped (22 entries) but '
              'not yet ingested — these briefs name the governing '
              'publications; their full text arrives with the DoW '
              'adapter.',
          'Anything CAC-gated stays out of the app entirely — '
              'titles only, never summarized.',
        ],
        followUps: [
          'Do I need permission to fly near an airport?',
          'What changed in the new Part 107?',
        ],
      ),
    ),
    _Topic(
      ['waiver', 'waive', 'exception to fly', 'beyond visual',
       'bvlos'],
      (q) => ResearchBrief(
        question: 'Can I get a waiver to fly beyond the normal rules?',
        covered: true,
        shortAnswer:
            'For many Part 107 limits — yes, if you can convince the '
            'FAA the flight can be done safely. The FAA publishes '
            'exactly which sections can be waived: flying beyond '
            'visual line of sight, over people, at night without '
            'the usual lighting, in controlled airspace, and the '
            'operating limits are all on the list. Some things can '
            'never be waived — carrying hazardous material is the '
            'big one. Waivers are requested through DroneZone, and '
            'the application has to describe the operation and '
            'justify its safety in detail.',
        why: [
          BriefCitation(
            label: '14 CFR 107.200',
            why: 'The waiver standard: the FAA may waive if the '
                'operation can be conducted safely.',
            ref: _cfr('107', '107.200', 'Waiver policy and '
                'requirements'),
          ),
          BriefCitation(
            label: '14 CFR 107.205',
            why: 'The complete list of waivable sections — check '
                'your rule is on it before applying.',
            ref: _cfr('107', '107.205', 'Waivable sections'),
          ),
        ],
        gaps: [
          'Waiver decisions are case-by-case; approval timelines '
              'and the FAA\'s current processing guidance live on '
              'DroneZone, outside the app.',
        ],
        followUps: [
          'Can I fly my drone over a parade?',
          'Can I fly my drone at night?',
        ],
      ),
    ),
  ];

  @override
  Future<ResearchBrief> ask(String question) async {
    final q = question.toLowerCase();
    _Topic? best;
    var bestScore = 0;
    for (final t in _topics) {
      final score =
          t.keywords.where((k) => q.contains(k)).length;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    if (best != null && bestScore > 0) return best.build(question);
    return ResearchBrief(
      question: question,
      covered: false,
      shortAnswer:
          'That one isn\'t covered yet — and this app won\'t guess '
          'at it. The research library currently answers questions '
          'about FAA drone rules (flying over people, night flight, '
          'registration, airspace permission, waivers, what changed '
          'in Part 107, border restrictions, tower inspections), '
          'North Carolina drone law, and how military '
          'drone operations are governed. Try one of those, or use '
          'Search and Browse to read the regulation directly.',
      gaps: [
        'State drone law beyond North Carolina is an ingest plan, '
            'not verified research yet.',
        'Department of War publications are mapped but not yet '
            'ingested as readable text.',
        'FAA companion documents (Advisory Circulars, FAA Orders, '
            'the AIM) are mapped for Phase 1b and not yet in the '
            'app.',
        'The post-2024 consolidated text of 49 U.S.C. § 44809 is '
            'flagged UNREAD in the research maps.',
      ],
      followUps: exampleQuestions.take(4).toList(),
    );
  }
}
