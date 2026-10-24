import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Minimal on-device bookmarks. No account, no cloud (DESIGN.md §2).
class BookmarksStore extends ChangeNotifier {
  static const _key = 'bookmarks_v1';
  final List<Bookmark> _items = [];
  bool _loaded = false;

  List<Bookmark> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  bool isBookmarked(RegulationRef ref) =>
      _items.any((b) => b.ref.key == ref.key);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      _items
        ..clear()
        ..addAll(
          raw.map(
            (s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>),
          ),
        );
      _items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      // Storage unavailable (tests, web sandbox) — bookmarks stay in memory.
    }
    notifyListeners();
  }

  Future<void> toggle(RegulationRef ref) async {
    if (isBookmarked(ref)) {
      _items.removeWhere((b) => b.ref.key == ref.key);
    } else {
      _items.insert(0, Bookmark(ref: ref, savedAt: DateTime.now()));
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        _items.map((b) => jsonEncode(b.toJson())).toList(),
      );
    } catch (_) {
      // In-memory copy already updated; persistence is best-effort here.
    }
  }
}
