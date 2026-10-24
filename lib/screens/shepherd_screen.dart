import 'package:flutter/material.dart';

import '../airspace/airspace_service.dart';
import '../app_services.dart';
import '../shepherd/shepherd.dart';
import '../states/states_matrix.dart';
import '../theme.dart';

/// Shepherd mode: the fused check. Asks, in order:
/// 1. What group drone will be used?
/// 2. Will live munitions be used?
/// 3. Location — current fix, a place name (city/state/address), or
///    coordinates entered manually for pre-planning.
/// Then fuses every layer we actually have into one summary, with each
/// layer labelled REAL DATA / FRAMEWORK / RESEARCHING. See DESIGN.md §10.
class ShepherdScreen extends StatefulWidget {
  final AppServices services;
  const ShepherdScreen({super.key, required this.services});

  @override
  State<ShepherdScreen> createState() => _ShepherdScreenState();
}

class _ShepherdScreenState extends State<ShepherdScreen> {
  int _step = 0; // 0 group, 1 munitions, 2 location, 3 summary
  UasGroup? _group;
  bool? _munitions;
  bool _busy = false;
  String? _locationError;
  String _locationLabel = '';
  AirspaceCheck? _check;
  List<StateMatrixEntry>? _stateMatrix;

  @override
  void initState() {
    super.initState();
    loadStateMatrix().then((m) {
      if (mounted) setState(() => _stateMatrix = m);
    }).catchError((_) {});
  }

  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _placeController = TextEditingController();

  Future<void> _useMyLocation() async {
    final svc = widget.services.airspace;
    if (svc == null) return;
    setState(() {
      _busy = true;
      _locationError = null;
    });
    final check = await svc.checkHere();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _check = check;
      _locationLabel = 'your current location';
      _step = 3;
    });
  }

  Future<void> _useManualLocation() async {
    final svc = widget.services.airspace;
    if (svc == null) return;
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null ||
        lon == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      setState(
        () => _locationError =
            'Enter valid coordinates: latitude -90 to 90, longitude '
            '-180 to 180 (example: 35.0526, -78.8789).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _locationError = null;
    });
    final check = await svc.checkAt(lat, lon);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _check = check;
      _locationLabel = 'entered location ($lat, $lon)';
      _step = 3;
    });
  }

  /// Pre-plan by place name — a city/state or address, resolved to
  /// coordinates and then checked against the same on-device grid.
  /// A place that can't be found is an honest error, never a guess.
  Future<void> _usePlace() async {
    final svc = widget.services.airspace;
    final geo = widget.services.geocoder;
    if (svc == null || geo == null) return;
    final q = _placeController.text.trim();
    if (q.isEmpty) {
      setState(() => _locationError = 'Type a city, state, or address.');
      return;
    }
    setState(() {
      _busy = true;
      _locationError = null;
    });
    final place = await geo.lookup(q);
    if (!mounted) return;
    if (place == null) {
      setState(() {
        _busy = false;
        _locationError =
            'Couldn\'t find "$q". Check the spelling, or enter '
            'coordinates instead.';
      });
      return;
    }
    final check = await svc.checkAt(place.lat, place.lon);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _check = check;
      _locationLabel = place.displayName;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shepherd — Fused Check'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: AnimatedSwitcher(
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
          key: ValueKey(_step),
          child: switch (_step) {
            0 => _groupStep(),
            1 => _munitionsStep(),
            2 => _locationStep(),
            _ => _summaryStep(),
          },
        ),
      ),
    );
  }

  Widget _shell(
    String title,
    String? sub,
    List<Widget> children, {
    Widget? footer,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (sub != null) ...[const SizedBox(height: 6), Text(sub)],
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(padding: const EdgeInsets.all(16), child: footer),
      ],
    );
  }

  Widget _pickCard({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      color: selected ? PlainRegsTheme.surfaceHigh : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? PlainRegsTheme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: selected
            ? Icon(Icons.check_circle, color: PlainRegsTheme.accent)
            : const Icon(Icons.circle_outlined),
        onTap: onTap,
      ),
    );
  }

  Widget _nextButton(String label, bool enabled, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        child: Text(label),
      ),
    );
  }

  Widget _groupStep() {
    return _shell(
      'What group drone will be used?',
      'The DoD joint groups. If any one attribute (weight, altitude, '
          'speed) reaches a higher group, the aircraft is that group.',
      [
        ...UasGroup.values.map((g) {
          final info = uasGroups[g]!;
          return _pickCard(
            title: '${info.label} — ${info.weightBand}',
            subtitle:
                '${info.altitudeBand} · ${info.speedBand}\n${info.examples}',
            selected: _group == g,
            onTap: () => setState(() => _group = g),
          );
        }),
      ],
      footer: _nextButton(
        'Next',
        _group != null,
        () => setState(() => _step = 1),
      ),
    );
  }

  Widget _munitionsStep() {
    return _shell(
      'Will live munitions be used?',
      'Armed aircraft — including one-way attack / loitering munitions — '
          'follow the Department of War framework, never civil drone '
          'rules.',
      [
        _pickCard(
          title: 'Yes — live munitions',
          subtitle: 'Armed, or a one-way attack munition employed as a weapon',
          selected: _munitions == true,
          onTap: () => setState(() => _munitions = true),
        ),
        _pickCard(
          title: 'No — unarmed',
          subtitle: 'Surveillance, training, cargo, or civil flight',
          selected: _munitions == false,
          onTap: () => setState(() => _munitions = false),
        ),
      ],
      footer: _nextButton(
        'Next',
        _munitions != null,
        () => setState(() => _step = 2),
      ),
    );
  }

  Widget _locationStep() {
    final hasSvc = widget.services.airspace != null;
    return _shell(
      'Where?',
      'Shepherd fuses the rules for this exact location. Use where you '
          'are — or enter a place or coordinates to pre-plan a '
          'different spot.',
      [
        if (hasSvc)
          Card(
            color: PlainRegsTheme.surfaceHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current location',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Checked on this phone against the FAA grid stored '
                    'in the app. Your location never leaves the device.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Use my location'),
                    onPressed: _busy ? null : _useMyLocation,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Pre-plan a location',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.services.geocoder != null) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'City, state, or address',
                    hintText: 'Fayetteville, NC',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _usePlace(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : _usePlace,
                child: const Text('Look up'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Place lookup needs a connection and sends only the place '
            'name to OpenStreetMap. The grid check itself stays on this '
            'device.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Text(
            '…or coordinates:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '35.0526',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lonController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-78.8789',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _locationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        if (_busy)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Checking the grid…'),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.pin_drop, size: 18),
              label: const Text('Check this location'),
              onPressed: hasSvc ? _useManualLocation : null,
            ),
          ),
      ],
    );
  }

  Widget _summaryStep() {
    final sections = buildShepherdSummary(
      group: _group!,
      liveMunitions: _munitions!,
      check: _check,
      locationLabel: _locationLabel,
      stateMatrix: _stateMatrix,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fused summary — ${uasGroups[_group!]!.label}'
          '${_munitions! ? ', live munitions' : ', unarmed'}'
          ' · $_locationLabel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (widget.services.airspace != null)
          FutureBuilder(
            future: widget.services.airspace!.info(),
            builder: (context, snap) => snap.hasData
                ? Text(
                    'Grid data: ${snap.data!.stamp}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : const SizedBox.shrink(),
          ),
        ...sections.map(_sectionCard),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PlainRegsTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Shepherd fuses what this app actually has. It is guidance, '
            'not an authorization, not legal advice, and — for armed '
            'operations — not a clearance of any kind. Authorizations '
            'still come from the FAA (LAANC/COA) or your military '
            'chain, as applicable.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Start over'),
          onPressed: () => setState(() {
            _step = 0;
            _group = null;
            _munitions = null;
            _check = null;
            _locationError = null;
          }),
        ),
      ],
    );
  }

  Widget _sectionCard(ShepherdSection s) {
    final (icon, color) = switch (s.tone) {
      ShepherdTone.ok => (Icons.check_circle, Colors.green),
      ShepherdTone.info => (Icons.info, Colors.blueGrey),
      ShepherdTone.warn => (Icons.warning, Colors.amber),
      ShepherdTone.block => (Icons.block, Colors.red),
    };
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
                    s.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(
                    s.layerKind,
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...s.lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _placeController.dispose();
    super.dispose();
  }
}
