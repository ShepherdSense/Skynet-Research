import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Verification state of one state's matrix entry. Mirrors the
/// research discipline in the source notes (DESIGN.md §15):
/// - verified: read on the official host (or full official text).
/// - partial: verified core with flagged gaps; the caveat ships with
///   the data and is shown.
/// - unverified: research exists but could not be verified on the
///   official host — published as RESEARCHING with NO values. A
///   verified absence (a state scored as having no drone-specific
///   provision) is real data and is NOT this.
enum StateMatrixStatus { verified, partial, unverified }

class StateCategoryScore {
  final int n;
  final String name;
  final String headline;
  final String detail;
  final String basis;

  const StateCategoryScore({
    required this.n,
    required this.name,
    required this.headline,
    required this.detail,
    required this.basis,
  });

  factory StateCategoryScore.fromJson(Map<String, dynamic> j) =>
      StateCategoryScore(
        n: j['n'] as int,
        name: j['name'] as String,
        headline: j['headline'] as String,
        detail: (j['detail'] as String?) ?? '',
        basis: (j['basis'] as String?) ?? '',
      );
}

class StateMatrixEntry {
  final String name;
  final String code;
  final StateMatrixStatus status;
  final String verifiedDate;
  final String caveat;
  final bool noDroneLawFound;
  final List<StateCategoryScore> categories;

  const StateMatrixEntry({
    required this.name,
    required this.code,
    required this.status,
    required this.verifiedDate,
    required this.caveat,
    required this.noDroneLawFound,
    required this.categories,
  });

  bool get hasData => status != StateMatrixStatus.unverified;

  /// The categories worth surfacing in a compact summary (Shepherd):
  /// the ones with substantive law, in matrix order.
  List<StateCategoryScore> get substantive => categories
      .where((c) => !_isAbsence(c.headline))
      .toList(growable: false);

  static bool _isAbsence(String headline) {
    final h = headline.toLowerCase().trim();
    return h.startsWith('none') ||
        h.startsWith('silent') ||
        h.startsWith('no ') ||
        h == '—' ||
        h == '–';
  }

  factory StateMatrixEntry.fromJson(Map<String, dynamic> j) =>
      StateMatrixEntry(
        name: j['name'] as String,
        code: j['code'] as String,
        status: StateMatrixStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => StateMatrixStatus.unverified,
        ),
        verifiedDate: (j['verifiedDate'] as String?) ?? '',
        caveat: (j['caveat'] as String?) ?? '',
        noDroneLawFound: (j['noDroneLawFound'] as bool?) ?? false,
        categories: ((j['categories'] as List?) ?? [])
            .map((e) =>
                StateCategoryScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Loads the bundled 50-state matrix (built by
/// tool/build_states_matrix.py from the verified research notes).
Future<List<StateMatrixEntry>> loadStateMatrix() async {
  final raw = await rootBundle.loadString('assets/states_matrix.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  return ((doc['states'] as List?) ?? [])
      .map((e) => StateMatrixEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Finds a state named anywhere in [text] (a geocoder display name
/// like "Fayetteville, North Carolina, United States"). Longest names
/// win, so "Virginia" inside "West Virginia" never false-matches —
/// the same trap the converter had to avoid.
StateMatrixEntry? matchStateInText(
  String text,
  List<StateMatrixEntry> states,
) {
  final t = text.toLowerCase();
  final byLength = [...states]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final s in byLength) {
    final pattern = RegExp(
      r'(^|[^a-z])' + RegExp.escape(s.name.toLowerCase()) + r'([^a-z]|$)',
    );
    if (pattern.hasMatch(t)) return s;
  }
  return null;
}
