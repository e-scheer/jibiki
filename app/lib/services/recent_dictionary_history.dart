import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight, local trail of dictionary words the learner actually opened.
///
/// Only identifiers and timestamps are persisted. The current dictionary pack
/// remains the source of truth for the word content shown on the home screen.
class RecentDictionaryHistory {
  static const _key = 'recent_dictionary_words_v1';
  static const _maxEntries = 12;

  Future<List<RecentWordVisit>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final visits = <RecentWordVisit>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final visit = RecentWordVisit.tryParse(value.cast<String, dynamic>());
        if (visit != null) visits.add(visit);
      }
      visits.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      return visits;
    } catch (_) {
      return const [];
    }
  }

  Future<void> remember(int wordId, {DateTime? at}) async {
    final visits = (await read()).toList();
    visits.removeWhere((visit) => visit.wordId == wordId);
    visits.insert(
      0,
      RecentWordVisit(wordId: wordId, viewedAt: at ?? DateTime.now()),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([
        for (final visit in visits.take(_maxEntries)) visit.toJson(),
      ]),
    );
  }
}

class RecentWordVisit {
  const RecentWordVisit({required this.wordId, required this.viewedAt});

  final int wordId;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
        'word_id': wordId,
        'viewed_at': viewedAt.toIso8601String(),
      };

  static RecentWordVisit? tryParse(Map<String, dynamic> json) {
    final id = (json['word_id'] as num?)?.toInt();
    final viewedAt = DateTime.tryParse(json['viewed_at']?.toString() ?? '');
    if (id == null || viewedAt == null) return null;
    return RecentWordVisit(wordId: id, viewedAt: viewedAt);
  }
}
