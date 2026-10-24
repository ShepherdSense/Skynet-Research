import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One event from Draco's Military Drone Events Register
/// (Military_Drone_Events_Register_2026-10-09.xlsx, verified
/// 2026-10-09): a U.S. military, allied or defense-industry drone
/// event — competition, exercise, acquisition event, conference or
/// cadet event. Built by tool/build_events_bundle.py, which fails
/// loudly unless all 74 register rows parse and reconcile.
class DroneEvent {
  final String id;
  final String name;
  final String window;
  final String status;
  final String location;
  final String host;
  final String category;
  final String focus;
  final String? participation;
  final String notes;
  final String? exactStart;
  final String? exactEnd;
  final String? publisher;
  final String primaryUrl;
  final String? supportingUrl;
  final String verifiedAsOf;

  const DroneEvent({
    required this.id,
    required this.name,
    required this.window,
    required this.status,
    required this.location,
    required this.host,
    required this.category,
    required this.focus,
    this.participation,
    required this.notes,
    this.exactStart,
    this.exactEnd,
    this.publisher,
    required this.primaryUrl,
    this.supportingUrl,
    required this.verifiedAsOf,
  });

  factory DroneEvent.fromJson(Map<String, dynamic> j) => DroneEvent(
        id: j['id'] as String,
        name: j['name'] as String,
        window: j['window'] as String,
        status: j['status'] as String,
        location: j['location'] as String,
        host: j['host'] as String,
        category: j['category'] as String,
        focus: j['focus'] as String,
        participation: j['participation'] as String?,
        notes: j['notes'] as String,
        exactStart: j['exactStart'] as String?,
        exactEnd: j['exactEnd'] as String?,
        publisher: j['publisher'] as String?,
        primaryUrl: j['primaryUrl'] as String,
        supportingUrl: j['supportingUrl'] as String?,
        verifiedAsOf: j['verifiedAsOf'] as String,
      );

  /// Lowercased haystack for free-text search.
  String get searchText => (
        [name, window, status, location, host, category, focus, notes,
         publisher ?? '', id]
            .join(' ')
            .toLowerCase());

  /// Exact start as a DateTime, or null when the register leaves
  /// the full date unverified.
  DateTime? get startDate =>
      exactStart == null ? null : DateTime.tryParse(exactStart!);

  /// True when the exact start date is today or in the future.
  bool get isUpcoming {
    final s = startDate;
    if (s == null) return false;
    final now = DateTime.now();
    return !s.isBefore(DateTime(now.year, now.month, now.day));
  }
}

/// The bundled events register: 74 events, verified 2026-10-09.
class DroneEventsCatalog {
  final String verifiedAsOf;
  final String note;
  final List<DroneEvent> events;

  const DroneEventsCatalog({
    required this.verifiedAsOf,
    required this.note,
    required this.events,
  });

  static DroneEventsCatalog? _cache;

  static Future<DroneEventsCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/events.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = DroneEventsCatalog(
      verifiedAsOf: j['verifiedAsOf'] as String,
      note: j['note'] as String,
      events: ((j['events'] as List).cast<Map<String, dynamic>>())
          .map(DroneEvent.fromJson)
          .toList(growable: false),
    );
    _cache = catalog;
    return catalog;
  }

  /// Statuses in register order with entry counts.
  List<(String, int)> get statuses {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.status] = (counts[e.status] ?? 0) + 1;
    }
    return [
      for (final s in counts.keys) (s, counts[s]!),
    ];
  }
}

/// Filter + sort for the Events view. Sorted newest first by exact
/// start; events with no verified exact start sort last, by id.
/// `upcomingOnly` keeps only events whose exact start is today or
/// later.
List<DroneEvent> filterEvents(
  List<DroneEvent> events, {
  String query = '',
  String? status,
  bool upcomingOnly = false,
}) {
  final q = query.trim().toLowerCase();
  final filtered = events.where((e) {
    if (status != null && e.status != status) return false;
    if (upcomingOnly && !e.isUpcoming) return false;
    if (q.isNotEmpty && !e.searchText.contains(q)) return false;
    return true;
  }).toList();
  filtered.sort((a, b) {
    final sa = a.startDate;
    final sb = b.startDate;
    if (sa == null && sb == null) return a.id.compareTo(b.id);
    if (sa == null) return 1;
    if (sb == null) return -1;
    final cmp = sb.compareTo(sa);
    return cmp != 0 ? cmp : a.id.compareTo(b.id);
  });
  return filtered;
}
