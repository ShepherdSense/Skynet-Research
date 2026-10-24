import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/models.dart';
import '../services/regulation_source.dart';
import '../services/sample_source.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';
import '../widgets/hue_slider.dart';
import 'fly_check_screen.dart';
import 'reader_screen.dart';

class SearchScreen extends StatefulWidget {
  final AppServices services;

  /// Colorway controller — when present, the landing page carries
  /// the site-color slider at the bottom.
  final ThemeHueController? themeHue;
  const SearchScreen({super.key, required this.services, this.themeHue});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  RegulationSource get _source => widget.services.primary;

  List<SearchHit>? _hits;
  bool _loading = false;
  String? _error;
  bool _showSamplesHint = true;

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _showSamplesHint = false;
    });
    // The user's own documents are searched first and shown first —
    // if they added it themselves, it's probably what they want.
    var userHits = <SearchHit>[];
    try {
      final docs = widget.services.sources
          .where((s) => s.id == 'userdocs')
          .firstOrNull;
      if (docs != null) userHits = await docs.search(query);
    } catch (_) {
      // A broken local library must never break regulation search.
    }
    try {
      var hits = await _source.search(query);
      // Offline / no-result fallback: also look in the sample set so a
      // first run with no connection still shows how results work.
      if (hits.isEmpty && userHits.isEmpty) {
        hits = await SampleSource().search(query);
      }
      if (!mounted) return;
      setState(() => _hits = [...userHits, ...hits]);
    } catch (e) {
      try {
        final hits = await SampleSource().search(query);
        if (!mounted) return;
        setState(() {
          _hits = [...userHits, ...hits];
          _error = hits.isEmpty && userHits.isEmpty
              ? 'Search is unavailable right now (no connection?).'
              : null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = 'Search failed. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSample(RegSection s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(services: widget.services, ref: s.ref),
      ),
    );
  }

  void _openHit(SearchHit hit) {
    // Reader fetches through the owning source; sample hits carry their
    // own sourceId, live hits carry 'ecfr'.
    final ref = hit.ref.sourceId == widget.services.primary.id
        ? hit.ref
        : RegulationRef(
            sourceId: hit.ref.sourceId,
            titleNumber: hit.ref.titleNumber,
            part: hit.ref.part,
            section: hit.ref.section,
            heading: hit.ref.heading,
            citationLabel: hit.ref.citationLabel,
          );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(services: widget.services, ref: ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No top title bar — the banner carries the branding now
      // (Draco, 2026-10-23).
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppBanner(),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
              decoration: InputDecoration(
                hintText: 'Try "drone height limit" or "14 CFR 107.51"',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _run(_controller.text),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Searching: ${_source.displayName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(child: _results()),
            if (widget.themeHue != null) ...[
              const Divider(height: 24),
              HueSlider(controller: widget.themeHue!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _results() {
    if (_hits == null) {
      if (!_showSamplesHint) return const SizedBox.shrink();
      // First run: the drone checker up top, then tappable real examples
      // that work fully offline.
      return ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.flight_takeoff, size: 28),
              title: const Text(
                'Can I fly my drone?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Answer a few plain questions — get a yes or no with '
                'the exact rules behind it',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlyCheckScreen(services: widget.services),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start with an example (works offline)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...SampleSource.samples.map(
            (s) => Card(
              child: ListTile(
                title: Text(s.ref.citation),
                subtitle: Text(s.ref.heading),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSample(s),
              ),
            ),
          ),
        ],
      );
    }
    if (_hits!.isEmpty) {
      return const Center(child: Text('No results. Try different words.'));
    }
    return ListView.builder(
      itemCount: _hits!.length,
      itemBuilder: (context, i) {
        final hit = _hits![i];
        return Card(
          child: ListTile(
            title: Text(hit.ref.citation),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.ref.heading,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(hit.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openHit(hit),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
