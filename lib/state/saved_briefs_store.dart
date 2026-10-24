import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../research/research.dart';

/// A brief the user chose to keep, with when they saved it.
class SavedBrief {
  final ResearchBrief brief;
  final DateTime savedAt;

  const SavedBrief({required this.brief, required this.savedAt});

  Map<String, dynamic> toJson() => {
        'brief': brief.toJson(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedBrief.fromJson(Map<String, dynamic> j) => SavedBrief(
        brief: ResearchBrief.fromJson(j['brief'] as Map<String, dynamic>),
        savedAt:
            DateTime.tryParse((j['savedAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}

/// Saved research briefs — the Bookmarks idea, extended to briefs
/// rather than forked into a second system (DESIGN.md §14).
class SavedBriefsStore extends ChangeNotifier {
  static const _key = 'research_briefs_v1';
  final List<SavedBrief> _items = [];
  bool _loaded = false;

  List<SavedBrief> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  bool isSaved(String question) => _items.any(
        (b) => b.brief.question.toLowerCase() == question.toLowerCase(),
      );

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      _items
        ..clear()
        ..addAll(raw.map(
          (s) => SavedBrief.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ));
      _items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      // Storage unavailable — briefs stay in memory this session.
    }
    notifyListeners();
  }

  Future<void> save(ResearchBrief brief) async {
    if (isSaved(brief.question)) return;
    _items.insert(0, SavedBrief(brief: brief, savedAt: DateTime.now()));
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String question) async {
    _items.removeWhere(
      (b) => b.brief.question.toLowerCase() == question.toLowerCase(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        _items.map((b) => jsonEncode(b.toJson())).toList(),
      );
    } catch (_) {
      // In-memory only this session.
    }
  }
}
