import 'package:flutter/material.dart';

import '../airspace/airspace_service.dart';
import '../app_services.dart';
import '../flycheck/fly_check.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';
import 'reader_screen.dart';

/// The "Can I Fly?" wizard. One plain question per step, big tap targets,
/// then a determination where every item cites its rule and can open the
/// rule in the Reader. See DESIGN.md §8.
class FlyCheckScreen extends StatefulWidget {
  final AppServices services;
  const FlyCheckScreen({super.key, required this.services});

  @override
  State<FlyCheckScreen> createState() => _FlyCheckScreenState();
}

class _FlyCheckScreenState extends State<FlyCheckScreen> {
  final FlyAnswers _a = FlyAnswers();
  int _step = 0;
  bool _showResult = false;

  // LAANC grid check state (airspace step).
  bool _gridBusy = false;
  String? _gridMessage;

  bool get _rec => _a.purpose == FlyPurpose.recreational;
  bool get _work => _a.purpose == FlyPurpose.work;

  /// Steps that apply given the answers so far, in order.
  List<String> get _steps {
    if (_a.purpose == null) return ['purpose'];
    if (_a.purpose == FlyPurpose.government ||
        _a.purpose == FlyPurpose.unsure) {
      return ['purpose']; // result explains the off-ramp
    }
    final steps = ['purpose', 'weight'];
    final lightRec = _rec && _a.weight == WeightClass.under250g;
    if (!lightRec && _a.weight != null) steps.add('registration');
    steps.add('credential');
    if (!lightRec && _a.weight != null) steps.add('remoteId');
    steps.addAll(['airspace', 'plan']);
    return steps;
  }

  String get _current => _steps[_step.clamp(0, _steps.length - 1)];

  bool get _stepAnswered {
    switch (_current) {
      case 'purpose':
        return _a.purpose != null;
      case 'weight':
        return _a.weight != null;
      case 'registration':
      case 'credential':
      case 'remoteId':
      case 'airspace':
        return true; // tri-state / defaulted pickers always have a value
      case 'plan':
        // nightReady may stay "unknown" — that is itself a real answer
        // (the engine turns it into a check outcome, never a silent pass).
        return _a.above400 != null &&
            _a.keepInSight != null &&
            _a.overPeople != null &&
            _a.atNight != null;
      default:
        return true;
    }
  }

  void _next() {
    // Government / unsure short-circuit straight to their result.
    if (_current == 'purpose' &&
        (_a.purpose == FlyPurpose.government ||
            _a.purpose == FlyPurpose.unsure)) {
      setState(() => _showResult = true);
      return;
    }
    if (_step >= _steps.length - 1) {
      setState(() => _showResult = true);
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_showResult) {
      setState(() => _showResult = false);
    } else if (_step > 0) {
      setState(() => _step--);
    }
  }

  void _restart() {
    setState(() {
      _a.purpose = null;
      _a.weight = null;
      _a.registered = TriState.unknown;
      _a.credential = TriState.unknown;
      _a.remoteId = RemoteIdStatus.unknown;
      _a.airspace = AirspaceClass.unknown;
      _a.airspaceAuthorization = TriState.unknown;
      _a.above400 = null;
      _a.keepInSight = null;
      _a.overPeople = null;
      _a.atNight = null;
      _a.nightReady = TriState.unknown;
      _a.airspaceFromGrid = false;
      _a.gridCeilingFt = null;
      _gridMessage = null;
      _step = 0;
      _showResult = false;
    });
  }

  Future<void> _checkMyLocation() async {
    final svc = widget.services.airspace;
    if (svc == null) return;
    setState(() => _gridBusy = true);
    final check = await svc.checkHere();
    if (!mounted) return;
    setState(() {
      _gridBusy = false;
      switch (check) {
        case GridHitCheck c:
          _a.airspaceFromGrid = true;
          _a.gridCeilingFt = c.ceilingFt;
          _gridMessage = c.ceilingFt == 0
              ? 'Your spot is a 0-foot grid square — LAANC cannot '
                    'approve flights here. Details on the result screen.'
              : 'Your spot: LAANC grid ceiling ${c.ceilingFt} feet. '
                    'That is the most LAANC can approve here — the grid '
                    'itself is not an approval.';
        case NoGridCheck _:
          _a.airspaceFromGrid = true;
          _a.gridCeilingFt = null;
          _gridMessage =
              'No LAANC grid covers your spot — that usually means '
              'uncontrolled airspace. The checker will use that, and '
              'still remind you to check B4UFLY.';
        case OutsideCoverageCheck _:
          _a.airspaceFromGrid = false;
          _gridMessage =
              'That location is outside the US grid data. Answer the '
              'questions below instead.';
        case LocationFailedCheck f:
          _a.airspaceFromGrid = false;
          _gridMessage = '${f.reason} Answer the questions below instead.';
      }
    });
  }

  void _useManualAirspace() {
    setState(() {
      _a.airspaceFromGrid = false;
      _a.gridCeilingFt = null;
      _gridMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No top title (Draco, 2026-10-23) — the bar exists only to
      // carry the wizard's back button once you're past step one.
      appBar: (_step > 0 || _showResult)
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
            )
          : null,
      body: _showResult
          ? FlyResultView(
              services: widget.services,
              result: evaluateFlyCheck(_a),
              onRestart: _restart,
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: AppBanner(),
                ),
                LinearProgressIndicator(
                  value: (_step + 1) / _steps.length,
                  color: PlainRegsTheme.accent,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_current),
                        child: _stepBody(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _stepAnswered ? _next : null,
                      child: Text(
                        _step >= _steps.length - 1 &&
                                _a.purpose != null &&
                                _a.purpose != FlyPurpose.government &&
                                _a.purpose != FlyPurpose.unsure
                            ? 'See my answer'
                            : 'Next',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Titles only — no per-option descriptions (Draco, 2026-10-23).
  Widget _option<T>({
    required String title,
    required T value,
    required T? selected,
    required ValueChanged<T> onPick,
  }) {
    final isSel = value == selected;
    return Card(
      color: isSel ? PlainRegsTheme.surfaceHigh : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSel ? PlainRegsTheme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: isSel
            ? Icon(Icons.check_circle, color: PlainRegsTheme.accent)
            : const Icon(Icons.circle_outlined),
        onTap: () => setState(() => onPick(value)),
      ),
    );
  }

  Widget _question(String text, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _stepBody() {
    switch (_current) {
      case 'purpose':
        return _question('Why are you flying?', [
          _option(
            title: 'For Fun',
            value: FlyPurpose.recreational,
            selected: _a.purpose,
            onPick: (v) => _a.purpose = v,
          ),
          _option(
            title: 'Commercial',
            value: FlyPurpose.work,
            selected: _a.purpose,
            onPick: (v) => _a.purpose = v,
          ),
          _option(
            title: 'Mil/Gov',
            value: FlyPurpose.government,
            selected: _a.purpose,
            onPick: (v) => _a.purpose = v,
          ),
          _option(
            title: 'Not Sure',
            value: FlyPurpose.unsure,
            selected: _a.purpose,
            onPick: (v) => _a.purpose = v,
          ),
        ]);
      case 'weight':
        return _question('How much does your drone weigh, ready to fly?', [
          _option(
            title: 'Under 0.55 pounds (250 grams)',
            value: WeightClass.under250g,
            selected: _a.weight,
            onPick: (v) => _a.weight = v,
          ),
          _option(
            title: '0.55 to 55 pounds',
            value: WeightClass.between250gAnd55lb,
            selected: _a.weight,
            onPick: (v) => _a.weight = v,
          ),
          _option(
            title: 'Over 55 pounds',
            value: WeightClass.over55lb,
            selected: _a.weight,
            onPick: (v) => _a.weight = v,
          ),
          _option(
            title: 'Don\'t know',
            value: WeightClass.unknown,
            selected: _a.weight,
            onPick: (v) => _a.weight = v,
          ),
        ]);
      case 'registration':
        return _question('Is your drone registered with the FAA?', [
          _triOptions(
            value: _a.registered,
            onPick: (v) => _a.registered = v,
            yesLabel: 'Yes, it has a registration number',
            noLabel: 'No',
            unknownLabel: 'Don\'t know — no number on it that I can find',
          ),
        ]);
      case 'credential':
        return _question(
          _rec
              ? 'Have you passed the TRUST safety test?'
              : 'Do you have an FAA Remote Pilot certificate (Part 107)?',
          [
            _triOptions(
              value: _a.credential,
              onPick: (v) => _a.credential = v,
              yesLabel: _rec ? 'Yes — and I can show proof' : 'Yes',
              noLabel: 'No',
              unknownLabel: 'Never heard of it',
            ),
            if (_rec)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'TRUST is the free online safety test recreational '
                  'flyers must pass. "Never heard of it" counts as no.',
                ),
              ),
          ],
        );
      case 'remoteId':
        return _question('Does your drone broadcast Remote ID?', [
          _option(
            title: 'Yes — built into the drone',
            value: RemoteIdStatus.builtIn,
            selected: _a.remoteId,
            onPick: (v) => _a.remoteId = v,
          ),
          _option(
            title: 'Yes — with a broadcast module I attach',
            value: RemoteIdStatus.module,
            selected: _a.remoteId,
            onPick: (v) => _a.remoteId = v,
          ),
          _option(
            title: 'No — but I only fly at an FAA-recognized area (FRIA)',
            value: RemoteIdStatus.friaOnly,
            selected: _a.remoteId,
            onPick: (v) => _a.remoteId = v,
          ),
          _option(
            title: 'No',
            value: RemoteIdStatus.none,
            selected: _a.remoteId,
            onPick: (v) => _a.remoteId = v,
          ),
          _option(
            title: 'Don\'t know',
            value: RemoteIdStatus.unknown,
            selected: _a.remoteId,
            onPick: (v) => _a.remoteId = v,
          ),
        ]);
      case 'airspace':
        final showAuthQuestion =
            (!_a.airspaceFromGrid && _a.airspace == AirspaceClass.controlled) ||
            (_a.airspaceFromGrid &&
                _a.gridCeilingFt != null &&
                _a.gridCeilingFt! > 0);
        return _question('Where will you fly?', [
          if (widget.services.airspace != null) _gridCard(),
          if (widget.services.airspace != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Or answer it yourself:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          _option(
            title: 'Away from airports — open country, parks, fields',
            value: AirspaceClass.uncontrolled,
            selected: _a.airspaceFromGrid ? null : _a.airspace,
            onPick: (v) {
              _useManualAirspace();
              _a.airspace = v;
            },
          ),
          _option(
            title: 'Near an airport or in a city',
            value: AirspaceClass.controlled,
            selected: _a.airspaceFromGrid ? null : _a.airspace,
            onPick: (v) {
              _useManualAirspace();
              _a.airspace = v;
            },
          ),
          _option(
            title: 'Don\'t know',
            value: AirspaceClass.unknown,
            selected: _a.airspaceFromGrid ? null : _a.airspace,
            onPick: (v) {
              _useManualAirspace();
              _a.airspace = v;
            },
          ),
          if (showAuthQuestion) ...[
            const SizedBox(height: 16),
            Text(
              'Do you have FAA authorization (LAANC) for that spot?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _triOptions(
              value: _a.airspaceAuthorization,
              onPick: (v) => _a.airspaceAuthorization = v,
              yesLabel: 'Yes',
              noLabel: 'No',
              unknownLabel: 'Don\'t know what that is',
            ),
          ],
        ]);
      case 'plan':
        return _question('About this flight:', [
          _yesNo(
            label: 'Will you fly higher than 400 feet above the ground?',
            value: _a.above400,
            onPick: (v) => _a.above400 = v,
          ),
          _yesNo(
            label:
                'Can you keep the drone in sight with your own eyes '
                'the whole flight?',
            value: _a.keepInSight,
            onPick: (v) => _a.keepInSight = v,
          ),
          _yesNo(
            label: 'Will you fly over people or moving vehicles?',
            value: _a.overPeople,
            onPick: (v) => _a.overPeople = v,
          ),
          _yesNo(
            label: 'Will any of the flight be at night?',
            value: _a.atNight,
            onPick: (v) => _a.atNight = v,
          ),
          if (_work && _a.atNight == true) ...[
            const SizedBox(height: 16),
            Text(
              'Night flight under Part 107 needs current night '
              'training AND a 3-mile anti-collision light. Got both?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _triOptions(
              value: _a.nightReady,
              onPick: (v) => _a.nightReady = v,
              yesLabel: 'Yes, both',
              noLabel: 'No',
              unknownLabel: 'Not sure',
            ),
          ],
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _gridCard() {
    final svc = widget.services.airspace!;
    return Card(
      color: PlainRegsTheme.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.my_location, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check the FAA grid for my exact spot',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Uses your location once, on this phone only, against the '
              'FAA LAANC grid stored in the app (fully offline). The grid '
              'shows the most LAANC can approve here — it is not an '
              'approval, and it doesn\'t show TFRs or restricted areas.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (_gridBusy)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Checking…'),
                ],
              )
            else if (_gridMessage == null)
              FilledButton.icon(
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Use my location'),
                onPressed: _checkMyLocation,
              )
            else ...[
              Text(
                _gridMessage!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              FutureBuilder(
                future: svc.info(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Grid data: ${snap.data!.stamp}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
              if (_a.airspaceFromGrid)
                TextButton(
                  onPressed: _useManualAirspace,
                  child: const Text('Clear — I\'ll answer it myself'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _triOptions({
    required TriState value,
    required ValueChanged<TriState> onPick,
    required String yesLabel,
    required String noLabel,
    required String unknownLabel,
  }) {
    return Column(
      children: [
        _option(
          title: yesLabel,
          value: TriState.yes,
          selected: value,
          onPick: onPick,
        ),
        _option(
          title: noLabel,
          value: TriState.no,
          selected: value,
          onPick: onPick,
        ),
        _option(
          title: unknownLabel,
          value: TriState.unknown,
          selected: value,
          onPick: onPick,
        ),
      ],
    );
  }

  Widget _yesNo({
    required String label,
    required bool? value,
    required ValueChanged<bool> onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _option(
                  title: 'Yes',
                  value: true,
                  selected: value,
                  onPick: onPick,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _option(
                  title: 'No',
                  value: false,
                  selected: value,
                  onPick: onPick,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The determination. Public so tests (and future deep links) can render a
/// result directly.
class FlyResultView extends StatelessWidget {
  final AppServices services;
  final FlyCheckResult result;
  final VoidCallback onRestart;

  const FlyResultView({
    super.key,
    required this.services,
    required this.result,
    required this.onRestart,
  });

  (Color, IconData, String, String) get _banner {
    switch (result.verdict) {
      case FlyVerdict.canFly:
        return (
          Colors.green,
          Icons.check_circle,
          'Yes — you can fly this drone',
          'Based on your answers, you meet the requirements. Follow the '
              'limits below on every flight.',
        );
      case FlyVerdict.notYet:
        return (
          Colors.amber,
          Icons.pending,
          'Not yet — fix these first',
          'You\'re close. Nothing here is a dead end: each item says '
              'exactly what to do, then you can fly.',
        );
      case FlyVerdict.cannotAsDescribed:
        return (
          Colors.red,
          Icons.block,
          'No — not the way you described it',
          'The flight as planned breaks a rule below. Change the plan '
              '(the fix is on each item) and the answer can become yes.',
        );
      case FlyVerdict.undetermined:
        return (
          Colors.blueGrey,
          Icons.help,
          'We can\'t tell yet',
          'The answer depends on why you\'re flying. Read this, then '
              'run the checker with the closest match.',
        );
      case FlyVerdict.outOfScope:
        return (
          Colors.blueGrey,
          Icons.account_balance,
          'Different rulebook',
          'This checker covers recreational and Part 107 civil flying.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = _banner;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (result.blocked.isNotEmpty) ...[
          _sectionTitle(context, 'What blocks this flight'),
          ...result.blocked.map((o) => _outcomeCard(context, o)),
        ],
        if (result.toFix.isNotEmpty) ...[
          _sectionTitle(context, 'Fix or check before you fly'),
          ...result.toFix.map((o) => _outcomeCard(context, o)),
        ],
        if (result.passed.isNotEmpty) ...[
          _sectionTitle(context, 'You\'re good on these'),
          ...result.passed.map((o) => _outcomeCard(context, o)),
        ],
        ...result.outcomes
            .where((o) => o.status == OutcomeStatus.info)
            .map((o) => _outcomeCard(context, o)),
        if (result.conditions.isNotEmpty) ...[
          _sectionTitle(context, 'Limits that always apply'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.conditions
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(c)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PlainRegsTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'This is guidance based on your answers and the rules cited — '
            'not legal advice, and not an FAA authorization. Local rules, '
            'park rules, property-owner permission, and temporary flight '
            'restrictions can still apply. Check B4UFLY before every '
            'flight.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Start over'),
          onPressed: onRestart,
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _outcomeCard(BuildContext context, RuleOutcome o) {
    final (icon, color) = switch (o.status) {
      OutcomeStatus.pass => (Icons.check_circle, Colors.green),
      OutcomeStatus.fixable => (Icons.build_circle, Colors.amber),
      OutcomeStatus.blocked => (Icons.block, Colors.red),
      OutcomeStatus.check => (Icons.help, Colors.orange),
      OutcomeStatus.info => (Icons.info, Colors.blueGrey),
    };
    final readable =
        o.ref != null &&
        (o.ref!.sourceId == 'ecfr' || o.ref!.sourceId == 'sample') &&
        o.ref!.section != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    o.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(o.plainWhy),
            if (o.fix != null) ...[
              const SizedBox(height: 6),
              Text(
                'Fix: ${o.fix}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (o.ref != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.gavel, size: 16),
                    label: Text(o.ref!.citation),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (readable)
                    TextButton.icon(
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: const Text('Read the rule'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReaderScreen(services: services, ref: o.ref!),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
