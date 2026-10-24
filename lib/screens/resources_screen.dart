import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../resources/events.dart';
import '../resources/resources.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';

/// Resources: two sections under one tab (Draco, 2026-10-24).
/// "Sources" is Draco's full scheduled-research-source catalogue —
/// 3,529 deduplicated websites and social accounts recovered from his
/// research tasks, searchable and filterable by platform and topic tag.
/// Tapping an entry opens the source in the browser. The catalogue's
/// own caveat rides along: inclusion describes recovered records, live
/// access was not retested.
/// "Events" is the Military Drone Events Register (74 events,
/// verified 2026-10-09): competitions, exercises, acquisition
/// events and conferences, searchable and filterable by status,
/// with an Upcoming toggle. Each event card opens its primary
/// (and supporting, where present) source.
class ResourcesScreen extends StatefulWidget {
  /// Test hooks: supply catalogs instead of loading bundled assets.
  final ResourceCatalog? catalog;
  final DroneEventsCatalog? events;

  const ResourcesScreen({super.key, this.catalog, this.events});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

enum _ResourcesView { sources, events }

class _ResourcesScreenState extends State<ResourcesScreen> {
  Future<ResourceCatalog>? _future;
  Future<DroneEventsCatalog>? _eventsFuture;
  final _searchCtl = TextEditingController();
  final _eventsSearchCtl = TextEditingController();
  String _query = '';
  String _eventsQuery = '';
  String? _platform;
  String? _tag;
  String? _eventStatus;
  bool _upcomingOnly = false;
  _ResourcesView _view = _ResourcesView.sources;

  @override
  void initState() {
    super.initState();
    if (widget.catalog == null) _future = ResourceCatalog.load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _eventsSearchCtl.dispose();
    super.dispose();
  }

  void _switchView(_ResourcesView view) {
    if (view == _ResourcesView.events &&
        widget.events == null &&
        _eventsFuture == null) {
      _eventsFuture = DroneEventsCatalog.load();
    }
    setState(() => _view = view);
  }

  Future<void> _open(ResourceEntry e) async {
    final url = e.url;
    if (url == null) return;
    await _openUrl(url);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catalog != null) return _body(widget.catalog!);
    return FutureBuilder<ResourceCatalog>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) return _body(snap.data!);
        if (snap.hasError) {
          return const Center(child: Text('Could not load the catalogue.'));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _body(ResourceCatalog catalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AppBanner(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<_ResourcesView>(
            segments: const [
              ButtonSegment(
                value: _ResourcesView.sources,
                icon: Icon(Icons.library_books),
                label: Text('Sources'),
              ),
              ButtonSegment(
                value: _ResourcesView.events,
                icon: Icon(Icons.event),
                label: Text('Events'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (sel) => _switchView(sel.first),
          ),
        ),
        Expanded(
          child: _view == _ResourcesView.sources
              ? _sourcesView(catalog)
              : _eventsContent(),
        ),
      ],
    );
  }

  Widget _eventsContent() {
    if (widget.events != null) return _eventsView(widget.events!);
    return FutureBuilder<DroneEventsCatalog>(
      future: _eventsFuture,
      builder: (context, snap) {
        if (snap.hasData) return _eventsView(snap.data!);
        if (snap.hasError) {
          return const Center(child: Text('Could not load the events.'));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _sourcesView(ResourceCatalog catalog) {
    final results = filterResources(
      catalog.entries,
      query: _query,
      platform: _platform,
      tag: _tag,
    );
    final topTags = catalog.tagsByFrequency.take(14).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Search 3,419 sources — name, topic, report code…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('All (${catalog.entries.length})'),
                  selected: _platform == null,
                  onSelected: (_) => setState(() => _platform = null),
                ),
              ),
              for (final (name, count) in catalog.platforms)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$name ($count)'),
                    selected: _platform == name,
                    onSelected: (sel) =>
                        setState(() => _platform = sel ? name : null),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (name, count) in topTags)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text('$name ($count)'),
                    selected: _tag == name,
                    onSelected: (sel) =>
                        setState(() => _tag = sel ? name : null),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            '${results.length} source${results.length == 1 ? '' : 's'}'
            ' · catalogue ${catalog.catalogueDate}'
            ' · ${catalog.note}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('No sources match. Try clearing a filter.'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) =>
                      _ResourceTile(entry: results[i], onTap: _open),
                ),
        ),
      ],
    );
  }

  Widget _eventsView(DroneEventsCatalog catalog) {
    final results = filterEvents(
      catalog.events,
      query: _eventsQuery,
      status: _eventStatus,
      upcomingOnly: _upcomingOnly,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _eventsSearchCtl,
            decoration: InputDecoration(
              hintText:
                  'Search ${catalog.events.length} events — name, place, host, category…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _eventsQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _eventsSearchCtl.clear();
                        setState(() => _eventsQuery = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _eventsQuery = v),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilterChip(
            label: const Text('Upcoming only'),
            selected: _upcomingOnly,
            onSelected: (sel) => setState(() => _upcomingOnly = sel),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('All (${catalog.events.length})'),
                  selected: _eventStatus == null,
                  onSelected: (_) => setState(() => _eventStatus = null),
                ),
              ),
              for (final (name, count) in catalog.statuses)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$name ($count)'),
                    selected: _eventStatus == name,
                    onSelected: (sel) =>
                        setState(() => _eventStatus = sel ? name : null),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            '${results.length} event${results.length == 1 ? '' : 's'}'
            ' · verified ${catalog.verifiedAsOf}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            catalog.note,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('No events match. Try clearing a filter.'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) =>
                      _EventTile(event: results[i], onOpen: _openUrl),
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final DroneEvent event;
  final Future<void> Function(String) onOpen;

  const _EventTile({required this.event, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(event.name),
      subtitle: Text(
        [event.window, event.location].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _badge(event.status, theme),
                  _badge(event.category, theme, soft: true),
                  _badge(event.id, theme, soft: true),
                ],
              ),
              const SizedBox(height: 8),
              Text('Host: ${event.host}'),
              if (event.publisher != null)
                Text('Publisher: ${event.publisher}'),
              Text(
                event.exactStart != null
                    ? 'Exact: ${event.exactStart}'
                        '${event.exactEnd != null ? ' → ${event.exactEnd}' : ''}'
                    : 'Exact dates not verified',
              ),
              const SizedBox(height: 6),
              Text(event.focus),
              if (event.participation != null) ...[
                const SizedBox(height: 4),
                Text('Participation: ${event.participation}'),
              ],
              const SizedBox(height: 4),
              Text(event.notes, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => onOpen(event.primaryUrl),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Primary source'),
                  ),
                  if (event.supportingUrl != null)
                    TextButton.icon(
                      onPressed: () => onOpen(event.supportingUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Supporting source'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, ThemeData theme, {bool soft = false}) {
    final color = soft ? Colors.grey : PlainRegsTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style:
              theme.textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ResourceEntry entry;
  final Future<void> Function(ResourceEntry) onTap;

  const _ResourceTile({required this.entry, required this.onTap});

  Color _kindColor() => switch (entry.kind) {
        'Current task source' => PlainRegsTheme.accent,
        'Directory / registered source' => Colors.lightBlueAccent,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(entry.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              entry.platform,
              if (entry.collection != null) entry.collection!,
              entry.id,
            ].join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: PlainRegsTheme.accent),
          ),
          if (entry.description.isNotEmpty)
            Text(entry.description,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (entry.kind != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kindColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(entry.kind!,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: _kindColor())),
                ),
              for (final t in entry.tags.take(5))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: PlainRegsTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t, style: theme.textTheme.labelSmall),
                ),
              if (entry.reports.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(entry.reports.join(' · '),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey)),
                ),
            ],
          ),
        ],
      ),
      trailing: entry.url == null
          ? null
          : const Icon(Icons.open_in_new, size: 18),
      onTap: entry.url == null ? null : () => onTap(entry),
    );
  }
}
