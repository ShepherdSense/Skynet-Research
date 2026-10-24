import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One source from Draco's scheduled-research-source catalogue
/// (All_Scheduled_Research_Sources_2026-10-23.pdf): a website or social
/// account, deduplicated, with the topic tags and report codes that use
/// it. Inclusion describes recovered records — live access was not
/// retested by the catalogue.
class ResourceEntry {
  final String id;
  final String name;
  final String? url;
  final String platform;
  final String? collection;
  final List<String> tags;
  final List<String> reports;
  final String? kind;
  final String description;
  final String? note;

  const ResourceEntry({
    required this.id,
    required this.name,
    this.url,
    required this.platform,
    this.collection,
    this.tags = const [],
    this.reports = const [],
    this.kind,
    this.description = '',
    this.note,
  });

  factory ResourceEntry.fromJson(Map<String, dynamic> j) => ResourceEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String?,
        platform: j['platform'] as String,
        collection: j['collection'] as String?,
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        reports: ((j['reports'] as List?) ?? []).cast<String>(),
        kind: j['kind'] as String?,
        description: (j['description'] as String?) ?? '',
        note: j['note'] as String?,
      );

  /// Lowercased haystack for free-text search.
  String get searchText => (
        [name, platform, collection ?? '', description, ...tags, ...reports]
            .join(' ')
            .toLowerCase());
}

/// The bundled catalogue: 3,529 entries parsed from the updated PDF by
/// tool/build_resources_bundle.py (which reconciles every count against
/// the catalogue's own summary table before writing the asset);
/// 3,419 ship after the Telegram entries are excluded.
class ResourceCatalog {
  final String catalogueDate;
  final String note;
  final List<ResourceEntry> entries;

  const ResourceCatalog({
    required this.catalogueDate,
    required this.note,
    required this.entries,
  });

  static ResourceCatalog? _cache;

  static Future<ResourceCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/resources.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = ResourceCatalog(
      catalogueDate: j['catalogueDate'] as String,
      note: j['note'] as String,
      entries: ((j['entries'] as List).cast<Map<String, dynamic>>())
          .map(ResourceEntry.fromJson)
          .toList(growable: false),
    );
    _cache = catalog;
    return catalog;
  }

  /// Platforms in catalogue order with entry counts.
  List<(String, int)> get platforms {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.platform] = (counts[e.platform] ?? 0) + 1;
    }
    const order = [
      'Website', 'LinkedIn', 'YouTube', 'X', 'Telegram',
      'Reddit', 'Facebook', 'Instagram', 'Substack', 'Bluesky',
      'GitHub', 'Threads',
    ];
    return [
      for (final p in order)
        if (counts.containsKey(p)) (p, counts[p]!),
    ];
  }

  /// Tags sorted by how many entries carry them, most first.
  List<(String, int)> get tagsByFrequency {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }
}

/// Pure filter used by the Resources screen (and its tests).
List<ResourceEntry> filterResources(
  List<ResourceEntry> entries, {
  String query = '',
  String? platform,
  String? tag,
  String? report,
}) {
  final q = query.trim().toLowerCase();
  return entries.where((e) {
    if (platform != null && e.platform != platform) return false;
    if (tag != null && !e.tags.contains(tag)) return false;
    if (report != null && !e.reports.contains(report)) return false;
    if (q.isNotEmpty && !e.searchText.contains(q)) return false;
    return true;
  }).toList(growable: false);
}
