import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../resources/resources.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';

/// Resources: Draco's full scheduled-research-source catalogue —
/// 3,529 deduplicated websites and social accounts recovered from his
/// research tasks, searchable and filterable by platform and topic tag.
/// Tapping an entry opens the source in the browser. The catalogue's
/// own caveat rides along: inclusion describes recovered records, live
/// access was not retested.
class ResourcesScreen extends StatefulWidget {
  /// Test hook: supply a catalog instead of loading the bundled asset.
  final ResourceCatalog? catalog;

  const ResourcesScreen({super.key, this.catalog});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  Future<ResourceCatalog>? _future;
  final _searchCtl = TextEditingController();
  String _query = '';
  String? _platform;
  String? _tag;

  @override
  void initState() {
    super.initState();
    if (widget.catalog == null) _future = ResourceCatalog.load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _open(ResourceEntry e) async {
    final url = e.url;
    if (url == null) return;
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AppBanner(),
        ),
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
