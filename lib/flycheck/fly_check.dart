import '../models/models.dart';

/// "Can I fly my drone?" — a guided determination engine.
///
/// Every outcome is tied to a specific cited rule. The engine never guesses:
/// an unanswered or "don't know" fact produces a *check* outcome, not a
/// silent pass. The result is guidance based on the user's answers — not
/// legal advice and not an FAA authorization (the result screen says so).
/// See DESIGN.md §8.

enum FlyPurpose { recreational, work, government, unsure }

enum WeightClass { under250g, between250gAnd55lb, over55lb, unknown }

enum TriState { yes, no, unknown }

enum RemoteIdStatus { builtIn, module, friaOnly, none, unknown }

enum AirspaceClass { controlled, uncontrolled, unknown }

enum OutcomeStatus {
  pass, // requirement met / doesn't apply
  fixable, // can be fixed before flight (register, take TRUST, get LAANC…)
  blocked, // cannot fly as described — the plan itself breaks a rule
  check, // unknown — user must verify before anyone can say yes
  info,
}

enum FlyVerdict { canFly, notYet, cannotAsDescribed, undetermined, outOfScope }

class FlyAnswers {
  FlyPurpose? purpose;
  WeightClass? weight;
  TriState registered = TriState.unknown;
  bool credentialAnswered = false;

  /// Recreational: TRUST passed. Work: Remote Pilot certificate held.
  TriState credential = TriState.unknown;
  RemoteIdStatus remoteId = RemoteIdStatus.unknown;
  AirspaceClass airspace = AirspaceClass.unknown;
  TriState airspaceAuthorization = TriState.unknown;

  /// Set when the airspace step was answered by the on-device LAANC grid
  /// check (FAA UAS Facility Maps bundle) instead of user self-report.
  /// [gridCeilingFt] null + this true = checked, and no grid square
  /// covers the point (usually uncontrolled airspace).
  bool airspaceFromGrid = false;
  int? gridCeilingFt;

  bool? above400;
  bool? keepInSight;
  bool? overPeople;
  bool? atNight;

  /// Part 107 night flying: current night training + anti-collision light.
  TriState nightReady = TriState.unknown;

  /// Southern border drone TFR: the flight is within 1 nautical mile
  /// north of the U.S.-Mexico border. Null = question not asked.
  bool? nearSouthernBorder;

  /// CBP approval for a flight inside the border TFR zone, requested at
  /// least 48 hours ahead. Only evaluated when nearSouthernBorder is true.
  TriState cbpApproval = TriState.unknown;

  /// Part 107 vertical-structure inspection (tower, high-rise) above the
  /// LAANC grid ceiling. Null = question not asked.
  bool? verticalStructureInspection;

  /// Meets ALL FAA Order JO 7200.23E ¶3-5 criteria: within a 100-foot
  /// radius of the structure, no more than 100 feet above its top, at
  /// least 2 nautical miles from any landing surface, visual line of
  /// sight, 3 statute miles visibility, and cloud clearance. Only
  /// evaluated when verticalStructureInspection is true.
  TriState withinStructureLimits = TriState.unknown;
}

class RuleOutcome {
  final String title;
  final OutcomeStatus status;
  final String plainWhy;
  final String? fix;
  final RegulationRef? ref;

  const RuleOutcome({
    required this.title,
    required this.status,
    required this.plainWhy,
    this.fix,
    this.ref,
  });
}

class FlyCheckResult {
  final FlyVerdict verdict;
  final List<RuleOutcome> outcomes;
  final List<String> conditions; // limits that apply even on a "yes"

  const FlyCheckResult({
    required this.verdict,
    required this.outcomes,
    this.conditions = const [],
  });

  List<RuleOutcome> get blocked =>
      outcomes.where((o) => o.status == OutcomeStatus.blocked).toList();
  List<RuleOutcome> get toFix => outcomes
      .where(
        (o) =>
            o.status == OutcomeStatus.fixable ||
            o.status == OutcomeStatus.check,
      )
      .toList();
  List<RuleOutcome> get passed =>
      outcomes.where((o) => o.status == OutcomeStatus.pass).toList();
}

// --- Citations -------------------------------------------------------------
// Readable in the Reader when sourceId is 'ecfr'/'sample' AND section != null.

const _statuteRef = RegulationRef(
  sourceId: 'statute',
  titleNumber: 49,
  heading: 'Exception for limited recreational operations of unmanned aircraft',
  citationLabel: '49 U.S.C. § 44809',
);
const _registrationRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '48',
  heading: 'Registration and Marking Requirements for Small Unmanned Aircraft',
  citationLabel: '14 CFR Part 48',
);
const _remoteIdRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '89',
  heading: 'Remote Identification of Unmanned Aircraft',
  citationLabel: '14 CFR Part 89',
);
const _certRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '107',
  section: '107.61',
  heading: 'Eligibility (Remote Pilot certificate)',
);
const _vlosRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '107',
  section: '107.31',
  heading: 'Visual line of sight aircraft operation',
);
const _airspace107Ref = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '107',
  section: '107.41',
  heading: 'Operation in certain airspace',
);
const _borderTfrRef = RegulationRef(
  sourceId: 'notam',
  titleNumber: 0,
  heading: 'Southern border drone temporary flight restriction',
  citationLabel: 'FAA NOTAMs ZLA 6/9954, ZAB 6/9978, ZHU 6/9956',
);
const _jo720023eRef = RegulationRef(
  sourceId: 'faa-order',
  titleNumber: 0,
  heading: 'Processing of Unmanned Aircraft Systems Requests',
  citationLabel: 'FAA Order JO 7200.23E, ¶3-5',
);
const _limitsRef = RegulationRef(
  sourceId: 'sample',
  titleNumber: 14,
  part: '107',
  section: '107.51',
  heading: 'Operating limitations for small unmanned aircraft',
);
const _nightRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '107',
  section: '107.29',
  heading: 'Daylight operation',
);
const _overPeopleRef = RegulationRef(
  sourceId: 'ecfr',
  titleNumber: 14,
  part: '107',
  heading: 'Operations over human beings',
  citationLabel: '14 CFR Part 107, Subpart D',
);

/// The determination. Pure function of the answers — fully unit-tested.
FlyCheckResult evaluateFlyCheck(FlyAnswers a) {
  // Government / military flying follows public-aircraft rules, service
  // guidance, and airspace authorities — not the civil rules this checker
  // knows. Say so instead of forcing a verdict.
  if (a.purpose == FlyPurpose.government) {
    return const FlyCheckResult(
      verdict: FlyVerdict.outOfScope,
      outcomes: [
        RuleOutcome(
          title: 'Government and military flights play by different rules',
          status: OutcomeStatus.info,
          plainWhy:
              'Flights as part of government or military duties are usually '
              'public aircraft operations. They follow your service\'s '
              'guidance, your organization\'s authorization, and airspace '
              'approvals — not the recreational or Part 107 rules in this '
              'checker. This checker covers flying on your own time.',
        ),
      ],
    );
  }
  if (a.purpose == null || a.purpose == FlyPurpose.unsure) {
    return const FlyCheckResult(
      verdict: FlyVerdict.undetermined,
      outcomes: [
        RuleOutcome(
          title: 'The reason you fly decides which rulebook applies',
          status: OutcomeStatus.info,
          plainWhy:
              'Flying only for fun = the recreational rules. Flying for '
              'work, a business, a client, or even a monetized channel = '
              'Part 107 — even if nobody pays you. If there is ANY '
              'non-recreational purpose, pick "For work or a purpose '
              'besides fun" and run the checker again.',
          ref: _statuteRef,
        ),
      ],
    );
  }

  final rec = a.purpose == FlyPurpose.recreational;
  final outcomes = <RuleOutcome>[];
  final conditions = <String>[];

  // JO 7200.23E ¶3-5 fast path: a qualifying tower inspection in
  // controlled airspace goes through FAADroneZone, never LAANC — the
  // airspace fixes below must not send such a flight to LAANC.
  final towerFastPath = !rec &&
      a.verticalStructureInspection == true &&
      a.withinStructureLimits == TriState.yes;

  // --- Weight gate ---------------------------------------------------------
  final weightKnown = a.weight != null && a.weight != WeightClass.unknown;
  if (a.weight == WeightClass.over55lb) {
    outcomes.add(
      const RuleOutcome(
        title: 'Too heavy for these rules',
        status: OutcomeStatus.blocked,
        plainWhy:
            'Both the recreational rules and Part 107 only cover drones that '
            'weigh less than 55 pounds at takeoff, including everything on '
            'board. A heavier drone needs special FAA certification and '
            'exemptions — a different, much bigger process.',
        ref: _statuteRef,
      ),
    );
  } else if (!weightKnown) {
    outcomes.add(
      const RuleOutcome(
        title: 'Weigh your drone',
        status: OutcomeStatus.check,
        plainWhy:
            'Weight decides whether you must register and whether you need '
            'Remote ID. A kitchen scale works — weigh it ready to fly, '
            'battery and camera included.',
        fix: 'Weigh the drone ready to fly, then run the checker again.',
      ),
    );
  }

  final heavyEnoughToRegister = a.weight == WeightClass.between250gAnd55lb;

  // --- Registration (14 CFR Part 48) ---------------------------------------
  if (rec && a.weight == WeightClass.under250g) {
    outcomes.add(
      const RuleOutcome(
        title: 'Registration: not required',
        status: OutcomeStatus.pass,
        plainWhy:
            'A recreational drone under 0.55 pounds (250 grams) does not '
            'have to be registered.',
        ref: _registrationRef,
      ),
    );
  } else if (heavyEnoughToRegister || !rec) {
    {
      switch (a.registered) {
        case TriState.yes:
          outcomes.add(
            const RuleOutcome(
              title: 'Registration',
              status: OutcomeStatus.pass,
              plainWhy: 'Your drone is registered. Keep the number on it.',
              ref: _registrationRef,
            ),
          );
        case TriState.no:
          outcomes.add(
            RuleOutcome(
              title: 'Your drone must be registered',
              status: OutcomeStatus.fixable,
              plainWhy: rec
                  ? 'Recreational drones from 0.55 to 55 pounds must be '
                        'registered with the FAA.'
                  : 'Every drone flown under Part 107 must be registered '
                        'with the FAA, whatever it weighs.',
              fix:
                  'Register on FAA DroneZone (\$5). Recreational flyers get '
                  'one number for all their drones; put the number on the '
                  'outside of the drone.',
              ref: _registrationRef,
            ),
          );
        case TriState.unknown:
          outcomes.add(
            const RuleOutcome(
              title: 'Check your registration',
              status: OutcomeStatus.check,
              plainWhy:
                  'Look for a registration number (starts with FA) on the '
                  'drone. No number usually means not registered.',
              ref: _registrationRef,
            ),
          );
      }
    }
  }

  // --- Credential: TRUST (recreational) / Remote Pilot cert (Part 107) ----
  if (rec) {
    switch (a.credential) {
      case TriState.yes:
        outcomes.add(
          const RuleOutcome(
            title: 'TRUST test',
            status: OutcomeStatus.pass,
            plainWhy:
                'You passed TRUST. Carry proof of it when you fly (a '
                'screenshot is fine).',
            ref: _statuteRef,
          ),
        );
      case TriState.no:
        outcomes.add(
          const RuleOutcome(
            title: 'Take the TRUST test before you fly',
            status: OutcomeStatus.fixable,
            plainWhy:
                'Recreational flyers must pass The Recreational UAS Safety '
                'Test (TRUST) and carry proof.',
            fix:
                'TRUST is free, online, and you cannot fail it — you '
                'answer until you get each question right. Takes about 30 '
                'minutes, through an FAA-approved provider.',
            ref: _statuteRef,
          ),
        );
      case TriState.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Have you taken TRUST?',
            status: OutcomeStatus.check,
            plainWhy:
                'If you have never taken The Recreational UAS Safety Test, '
                'you need it before flying for fun. If you took it, keep '
                'proof with you.',
            ref: _statuteRef,
          ),
        );
    }
  } else {
    switch (a.credential) {
      case TriState.yes:
        outcomes.add(
          const RuleOutcome(
            title: 'Remote Pilot certificate',
            status: OutcomeStatus.pass,
            plainWhy:
                'You hold a Part 107 Remote Pilot certificate. Keep it with '
                'you when you fly and stay current (free online recurrent '
                'training every 24 months).',
            ref: _certRef,
          ),
        );
      case TriState.no:
        outcomes.add(
          const RuleOutcome(
            title: 'You need a Remote Pilot certificate',
            status: OutcomeStatus.fixable,
            plainWhy:
                'Flying for work or any non-recreational purpose requires a '
                'Part 107 Remote Pilot certificate. There is no way around '
                'this one — flying commercially without it is the violation '
                'the FAA fines most.',
            fix:
                'You must be 16 or older and pass the FAA Part 107 '
                'knowledge test at a testing center. Many people self-study '
                'for 2–4 weeks.',
            ref: _certRef,
          ),
        );
      case TriState.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Check your certificate status',
            status: OutcomeStatus.check,
            plainWhy:
                'Part 107 flying requires a Remote Pilot certificate. If '
                'you never took the FAA knowledge test, you do not have one '
                'yet.',
            ref: _certRef,
          ),
        );
    }
  }

  // --- Remote ID (14 CFR Part 89) ------------------------------------------
  final remoteIdApplies = !rec || heavyEnoughToRegister;
  if (!remoteIdApplies) {
    outcomes.add(
      const RuleOutcome(
        title: 'Remote ID: not required',
        status: OutcomeStatus.pass,
        plainWhy:
            'Sub-250-gram recreational drones that don\'t need registration '
            'don\'t need Remote ID either.',
        ref: _remoteIdRef,
      ),
    );
  } else {
    switch (a.remoteId) {
      case RemoteIdStatus.builtIn:
      case RemoteIdStatus.module:
        outcomes.add(
          const RuleOutcome(
            title: 'Remote ID',
            status: OutcomeStatus.pass,
            plainWhy:
                'Your drone broadcasts Remote ID. It must be broadcasting '
                'from takeoff to shutdown, every flight.',
            ref: _remoteIdRef,
          ),
        );
      case RemoteIdStatus.friaOnly:
        outcomes.add(
          const RuleOutcome(
            title: 'Remote ID: covered at an FAA-recognized area',
            status: OutcomeStatus.pass,
            plainWhy:
                'Drones without Remote ID may only fly at an FAA-Recognized '
                'Identification Area (FRIA), within sight of the area the '
                'whole flight.',
            fix: 'Stay inside the FRIA for the entire flight.',
            ref: _remoteIdRef,
          ),
        );
      case RemoteIdStatus.none:
        outcomes.add(
          const RuleOutcome(
            title: 'Your drone needs Remote ID',
            status: OutcomeStatus.fixable,
            plainWhy:
                'Drones that must be registered must broadcast Remote ID — '
                'built in, or with a broadcast module attached.',
            fix:
                'Add an FAA-declared Remote ID broadcast module, turn on '
                'built-in Remote ID if your drone has it, or fly only at a '
                'FRIA (an FAA-Recognized Identification Area).',
            ref: _remoteIdRef,
          ),
        );
      case RemoteIdStatus.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Check whether your drone has Remote ID',
            status: OutcomeStatus.check,
            plainWhy:
                'Most drones made since late 2022 have it built in — check '
                'the settings app for a Remote ID / broadcast option, or '
                'look up your model on the FAA\'s declaration list.',
            ref: _remoteIdRef,
          ),
        );
    }
  }

  // --- Airspace --------------------------------------------------------------
  // Grid-checked answers (FAA UAS Facility Maps bundle, checked on-device
  // against the phone's location) take precedence over self-report.
  if (a.airspaceFromGrid) {
    if (a.gridCeilingFt == null) {
      outcomes.add(
        const RuleOutcome(
          title: 'Airspace — outside the LAANC grids',
          status: OutcomeStatus.pass,
          plainWhy:
              'Your location was checked against the FAA facility maps and '
              'no LAANC grid square covers it. That usually means '
              'uncontrolled airspace (Class G), where no airspace '
              'authorization is needed. Two warnings: the grids only map '
              'controlled airspace near airports — they do not show '
              'restricted or prohibited areas — and a spot right at an '
              'airport with no published grid still needs care.',
        ),
      );
      conditions.add(
        'Your spot is outside the published LAANC grids — still check '
        'B4UFLY for TFRs and restricted areas before you fly.',
      );
    } else if (a.gridCeilingFt == 0) {
      outcomes.add(
        RuleOutcome(
          title: 'This spot is a 0-foot grid square',
          status: OutcomeStatus.fixable,
          plainWhy:
              'The FAA facility map for your exact location sets the '
              'pre-authorized ceiling at 0 feet: LAANC cannot approve a '
              'flight here at any altitude. The map is informational — it '
              'does not itself authorize or ban flight — but in practice '
              'this airspace needs manual FAA coordination.',
          fix:
              'Easiest fix: fly somewhere else. Otherwise, apply for a '
              'manual airspace authorization through FAA DroneZone — that '
              'process takes weeks, not minutes.',
          ref: rec ? _statuteRef : _airspace107Ref,
        ),
      );
    } else {
      final ceiling = a.gridCeilingFt!;
      conditions.add(
        'At your spot, the FAA grid caps LAANC approvals at $ceiling '
        'feet — stay at or below the altitude your authorization '
        'actually gives you.',
      );
      switch (a.airspaceAuthorization) {
        case TriState.yes:
          outcomes.add(
            RuleOutcome(
              title: 'Airspace — grid-checked, authorized',
              status: OutcomeStatus.pass,
              plainWhy:
                  'Your location is in a $ceiling-foot LAANC grid square '
                  'and you have authorization. The grid only shows the '
                  'maximum LAANC can approve — your authorization is what '
                  'actually allows the flight.',
              ref: rec ? _statuteRef : _airspace107Ref,
            ),
          );
        case TriState.no:
          outcomes.add(
            RuleOutcome(
              title: towerFastPath
                  ? 'Get FAADroneZone authorization for this inspection'
                  : 'Get LAANC authorization for this spot',
              status: OutcomeStatus.fixable,
              plainWhy:
                  'Your location is in a $ceiling-foot LAANC grid square — '
                  'controlled airspace. The grid tells you the most LAANC '
                  'can approve here; it is not itself an approval.',
              fix: towerFastPath
                  ? 'This inspection flies above the grid ceiling, so '
                        'LAANC cannot approve it. Request a Part 107 '
                        'airspace authorization in FAADroneZone instead — '
                        'see the tower-inspection outcome below. It is a '
                        'manual process: allow weeks, not minutes.'
                  : 'Request authorization in an FAA-approved LAANC app '
                        'before takeoff — approval is usually automatic within '
                        'minutes, up to $ceiling feet at this spot.',
              ref: rec ? _statuteRef : _airspace107Ref,
            ),
          );
        case TriState.unknown:
          outcomes.add(
            RuleOutcome(
              title: towerFastPath
                  ? 'Do you have FAADroneZone authorization for this '
                        'inspection?'
                  : 'Do you have LAANC authorization for this spot?',
              status: OutcomeStatus.check,
              plainWhy: towerFastPath
                  ? 'Your location is in a $ceiling-foot LAANC grid square — '
                        'controlled airspace, so you need authorization before '
                        'takeoff. For this tower inspection the authorization '
                        'comes from FAADroneZone, not LAANC: LAANC cannot '
                        'approve above the grid ceiling.'
                  : 'Your location is in a $ceiling-foot LAANC grid square — '
                        'controlled airspace, so you need authorization before '
                        'takeoff. If you haven\'t requested it in a LAANC app, '
                        'you don\'t have it yet.',
              ref: rec ? _statuteRef : _airspace107Ref,
            ),
          );
      }
    }
  } else {
    switch (a.airspace) {
      case AirspaceClass.uncontrolled:
        outcomes.add(
          const RuleOutcome(
            title: 'Airspace',
            status: OutcomeStatus.pass,
            plainWhy:
                'You\'re outside controlled airspace (Class G). No FAA '
                'airspace authorization needed — but check for temporary '
                'flight restrictions before every flight.',
          ),
        );
      case AirspaceClass.controlled:
        switch (a.airspaceAuthorization) {
          case TriState.yes:
            outcomes.add(
              RuleOutcome(
                title: 'Airspace authorization',
                status: OutcomeStatus.pass,
                plainWhy:
                    'You have authorization for this controlled airspace. '
                    'Stay at or below the altitude it approves.',
                ref: rec ? _statuteRef : _airspace107Ref,
              ),
            );
          case TriState.no:
            outcomes.add(
              RuleOutcome(
                title: 'Get airspace authorization first',
                status: OutcomeStatus.fixable,
                plainWhy:
                    'Flying in controlled airspace (near most airports) '
                    'requires FAA authorization before takeoff.',
                fix: towerFastPath
                    ? 'This inspection needs a Part 107 airspace '
                          'authorization from FAADroneZone — LAANC cannot '
                          'approve above the grid ceiling. See the '
                          'tower-inspection outcome below. (Manual process: '
                          'allow weeks, not minutes.)'
                    : 'Use a LAANC app (FAA-approved providers, e.g. via '
                          'B4UFLY) — approval is usually automatic within minutes, '
                          'up to the altitude shown on the grid for that spot.',
                ref: rec ? _statuteRef : _airspace107Ref,
              ),
            );
          case TriState.unknown:
            outcomes.add(
              RuleOutcome(
                title: 'Do you have airspace authorization?',
                status: OutcomeStatus.check,
                plainWhy: towerFastPath
                    ? 'Controlled airspace requires authorization before '
                          'takeoff. For this tower inspection that '
                          'authorization comes from FAADroneZone, not LAANC.'
                    : 'Controlled airspace requires authorization before '
                          'takeoff. If you haven\'t requested it in a LAANC app, '
                          'you don\'t have it yet.',
                ref: rec ? _statuteRef : _airspace107Ref,
              ),
            );
        }
      case AirspaceClass.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Check your airspace',
            status: OutcomeStatus.check,
            plainWhy:
                'Near an airport usually means controlled airspace, which '
                'needs authorization. Away from airports is usually fine.',
            fix:
                'Check the free FAA B4UFLY app for the exact spot — it '
                'tells you the airspace and the max approved altitude.',
          ),
        );
    }
  }

  // --- Southern border drone TFR (Oct 20, 2026 – Oct 19, 2027) -----------
  // Applies to every drone, recreational and Part 107 alike. Unasked
  // (null) stays silent: the plan step asks the question, and a user
  // who never answers it gets no border outcome.
  if (a.nearSouthernBorder == true) {
    switch (a.cbpApproval) {
      case TriState.yes:
        outcomes.add(
          const RuleOutcome(
            title: 'Border zone flight — CBP approval on file',
            status: OutcomeStatus.pass,
            plainWhy:
                'You have CBP approval for this flight inside the southern '
                'border restriction zone. Stay inside the terms of that '
                'approval — the zone runs from the surface to 400 feet '
                'within 1 nautical mile north of the U.S.-Mexico border, '
                'through October 19, 2027.',
            ref: _borderTfrRef,
          ),
        );
      case TriState.no:
        outcomes.add(
          const RuleOutcome(
            title: 'Southern border restriction — no unauthorized flights',
            status: OutcomeStatus.blocked,
            plainWhy:
                'Unauthorized drone flights are barred from the surface to '
                '400 feet above the ground within 1 nautical mile north of '
                'the U.S.-Mexico border, from the Pacific coast to the Gulf '
                'coast, from October 20, 2026 through October 19, 2027. '
                'This covers every drone, including recreational models.',
            fix:
                'Ask U.S. Customs and Border Protection for approval at '
                'least 48 hours ahead — and know the categories are narrow '
                '(national defense, homeland security, law enforcement, '
                'firefighting, medical evacuation, search and rescue, '
                'disaster response, event operations). Ordinary commercial '
                'or hobby flying inside the zone has no approval route.',
            ref: _borderTfrRef,
          ),
        );
      case TriState.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Do you have CBP approval for the border zone?',
            status: OutcomeStatus.check,
            plainWhy:
                'Flying within 1 nautical mile north of the U.S.-Mexico '
                'border needs CBP approval requested at least 48 hours '
                'ahead. If you haven\'t requested it, you don\'t have it yet.',
            ref: _borderTfrRef,
          ),
        );
    }
  }

  // --- Vertical-structure inspections above the grid (JO 7200.23E ¶3-5) --
  // Part 107 only: the order is the FAA's procedure for processing Part
  // 107 airspace authorizations. It removes the ATC-facility coordination
  // step for qualifying inspections — it does NOT remove the need for an
  // authorization, and it is NOT a LAANC approval. Suppressed outside
  // controlled airspace, where no authorization is needed at all.
  final inControlledAirspace = (a.airspaceFromGrid &&
          a.gridCeilingFt != null) ||
      (!a.airspaceFromGrid && a.airspace == AirspaceClass.controlled);
  if (!rec && inControlledAirspace && a.verticalStructureInspection == true) {
    switch (a.withinStructureLimits) {
      case TriState.yes:
        if (a.airspaceAuthorization == TriState.yes) {
          outcomes.add(
            const RuleOutcome(
              title: 'Tower inspection above the grid — FAADroneZone '
                  'authorization on file',
              status: OutcomeStatus.pass,
              plainWhy:
                  'You hold a FAADroneZone authorization for this inspection '
                  'above the grid ceiling, and the JO 7200.23E ¶3-5 criteria '
                  'are met, so no air traffic facility coordination was '
                  'needed. Stay within the terms of your authorization.',
              ref: _jo720023eRef,
            ),
          );
        } else {
          outcomes.add(
            const RuleOutcome(
              title: 'Tower inspection above the grid — use FAADroneZone, '
                  'not LAANC',
              status: OutcomeStatus.fixable,
              plainWhy:
                  'Your inspection meets the JO 7200.23E ¶3-5 criteria '
                  '(within 100 feet of the structure, no more than 100 feet '
                  'above its top, at least 2 nautical miles from any airport '
                  'or heliport landing surface, in sight, 3 miles visibility, '
                  'clear of clouds), so the FAA processes the authorization '
                  'without coordinating with the air traffic facility. LAANC '
                  'cannot approve above the grid ceiling — this goes through '
                  'FAADroneZone as a manual Part 107 airspace authorization.',
              fix:
                  'Request a Part 107 airspace authorization in FAADroneZone '
                  'for the inspection. It is a manual process — allow weeks, '
                  'not minutes. This provision takes effect October 31, 2026.',
              ref: _jo720023eRef,
            ),
          );
        }
      case TriState.no:
        outcomes.add(
          const RuleOutcome(
            title: 'This inspection does not fit the fast path',
            status: OutcomeStatus.info,
            plainWhy:
                'Outside the JO 7200.23E ¶3-5 limits (100-foot radius, 100 '
                'feet above the top, 2 nautical miles from landing '
                'surfaces, sight, visibility, cloud clearance), the '
                'standard route applies: request the authorization in '
                'FAADroneZone and expect the FAA to coordinate with the '
                'air traffic facility. Bridges and power lines never '
                'qualify — the provision covers vertical structures only.',
            ref: _jo720023eRef,
          ),
        );
      case TriState.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Do you meet the tower-inspection limits?',
            status: OutcomeStatus.check,
            plainWhy:
                'The fast path needs ALL of these: within 100 feet of the '
                'structure, no more than 100 feet above its top, at least 2 '
                'nautical miles from any landing surface, in sight, 3 miles '
                'visibility, and clear of clouds. If any one fails, the '
                'standard authorization route applies instead.',
            ref: _jo720023eRef,
          ),
        );
    }
  }

  // --- The flight plan itself ----------------------------------------------
  if (a.above400 == true) {
    outcomes.add(
      RuleOutcome(
        title: 'Too high',
        status: OutcomeStatus.blocked,
        plainWhy: rec
            ? 'Recreational flying is capped at 400 feet above the ground '
                  '(lower where airspace authorization sets a lower limit).'
            : 'Part 107 caps you at 400 feet above the ground — the one '
                  'exception is flying within 400 feet of a structure, up to '
                  '400 feet above its top.',
        fix: 'Change the plan: stay at or below 400 feet above the ground.',
        ref: rec ? _statuteRef : _limitsRef,
      ),
    );
  }
  if (a.keepInSight == false) {
    outcomes.add(
      RuleOutcome(
        title: 'You must keep the drone in sight',
        status: OutcomeStatus.blocked,
        plainWhy: rec
            ? 'Recreational flying requires you to keep the drone in your '
                  'visual line of sight the whole flight (glasses/contacts are '
                  'fine; binoculars and a camera feed alone are not).'
            : 'Part 107 requires visual line of sight. Flying beyond sight '
                  'using only the camera feed needs an FAA waiver most '
                  'operators don\'t have.',
        fix:
            'Change the plan: keep the drone where you can always see it '
            'with your own eyes.',
        ref: rec ? _statuteRef : _vlosRef,
      ),
    );
  }
  if (a.overPeople == true) {
    if (rec) {
      outcomes.add(
        const RuleOutcome(
          title: 'No flying over people',
          status: OutcomeStatus.blocked,
          plainWhy:
              'Recreational safety rules prohibit flying over people (and '
              'over moving vehicles). One person you\'re filming standing '
              'still counts too, unless they are directly part of the '
              'flight crew and briefed.',
          fix: 'Change the plan: fly where you won\'t pass over people.',
          ref: _statuteRef,
        ),
      );
    } else {
      outcomes.add(
        const RuleOutcome(
          title: 'Flying over people has extra rules',
          status: OutcomeStatus.check,
          plainWhy:
              'Part 107 allows flight over people only for drones that '
              'meet one of the Category 1–4 rules in Subpart D (weight, '
              'injury-limiting design, and an FAA declaration for most '
              'categories) — most drones don\'t qualify out of the box.',
          fix:
              'Check your drone\'s category on the FAA declaration list. '
              'If it isn\'t declared for operations over people, change '
              'the plan to avoid flying over anyone.',
          ref: _overPeopleRef,
        ),
      );
    }
  }
  if (a.atNight == true && !rec) {
    switch (a.nightReady) {
      case TriState.yes:
        outcomes.add(
          const RuleOutcome(
            title: 'Night flying',
            status: OutcomeStatus.pass,
            plainWhy:
                'You have current night training and an anti-collision '
                'light visible for at least 3 miles. Both are required for '
                'Part 107 night flight.',
            ref: _nightRef,
          ),
        );
      case TriState.no:
        outcomes.add(
          const RuleOutcome(
            title: 'Night flying needs two things first',
            status: OutcomeStatus.fixable,
            plainWhy:
                'Part 107 night flight requires (1) updated training or '
                'testing that covers night operations, and (2) an '
                'anti-collision light visible for at least 3 statute miles.',
            fix:
                'Complete the free FAA night-training update (if already '
                'certified) and fit a 3-mile anti-collision light.',
            ref: _nightRef,
          ),
        );
      case TriState.unknown:
        outcomes.add(
          const RuleOutcome(
            title: 'Check your night setup',
            status: OutcomeStatus.check,
            plainWhy:
                'Night flight under Part 107 needs current night training '
                'AND a 3-mile anti-collision light. If you\'re not sure '
                'about either, treat it as a no until you check.',
            ref: _nightRef,
          ),
        );
    }
  }
  if (a.atNight == true && rec) {
    conditions.add(
      'Night, recreational: fly following your community-based '
      'organization\'s safety code, and use lighting so you can always '
      'tell which way the drone is pointing.',
    );
  }

  // --- Conditions that apply even on a yes -----------------------------------
  if (rec) {
    conditions.addAll([
      'Stay at or below 400 feet above the ground.',
      'Always give way to airplanes and helicopters — you are the one who moves.',
      'Never fly near emergency operations (fires, rescues, accidents).',
      'Don\'t fly carelessly or recklessly — that rule covers everything else.',
    ]);
  } else {
    conditions.addAll([
      'Max 100 mph, stay 500 feet below clouds and 2,000 feet away sideways, at least 3 miles visibility (14 CFR 107.51).',
      'Always give way to manned aircraft.',
      'Do a preflight check of the drone, weather, and airspace before every flight (14 CFR 107.49).',
      'You are the remote pilot in command — legally responsible for the whole flight.',
    ]);
  }

  // --- Verdict ---------------------------------------------------------------
  final hasBlocked = outcomes.any((o) => o.status == OutcomeStatus.blocked);
  final hasFixOrCheck = outcomes.any(
    (o) => o.status == OutcomeStatus.fixable || o.status == OutcomeStatus.check,
  );
  final verdict = hasBlocked
      ? FlyVerdict.cannotAsDescribed
      : hasFixOrCheck
      ? FlyVerdict.notYet
      : FlyVerdict.canFly;

  return FlyCheckResult(
    verdict: verdict,
    outcomes: outcomes,
    conditions: conditions,
  );
}
