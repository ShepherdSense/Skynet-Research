import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../userdocs/user_document.dart';

/// On-device store for user-added documents. Same pattern as
/// [BookmarksStore]: no account, no cloud — documents the user adds
/// stay on the user's device (DESIGN.md §13).
class UserDocsStore extends ChangeNotifier {
  static const _key = 'user_docs_v1';

  /// Honest size guard: a single document's text is capped so one paste
  /// can't swallow device storage. Oversize adds are refused with an
  /// explanation, never silently truncated.
  static const int maxTextChars = 1000000;

  final List<UserDocument> _items = [];
  bool _loaded = false;

  List<UserDocument> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  UserDocument? byId(String id) {
    for (final d in _items) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      _items
        ..clear()
        ..addAll(raw.map(
          (s) => UserDocument.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ));
      _items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (_) {
      // Storage unavailable (tests, web sandbox) — docs stay in memory.
    }
    notifyListeners();
  }

  /// Adds a document. Throws [ArgumentError] when the text exceeds
  /// [maxTextChars] — the UI shows that message verbatim.
  Future<void> add(UserDocument doc) async {
    if (doc.text.length > maxTextChars) {
      throw ArgumentError(
        'That document is ${doc.text.length} characters — over the '
        '$maxTextChars-character limit for one added document. Split it '
        'into parts, or add it as a link instead.',
      );
    }
    _items.insert(0, doc);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((d) => d.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        _items.map((d) => jsonEncode(d.toJson())).toList(),
      );
    } catch (_) {
      // In-memory only this session; nothing else to do.
    }
  }
}
