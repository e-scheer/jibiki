/// A smart study set (a whole syllabary, all kanji, favorites, …). System decks
/// are defined server-side; the app just picks one and studies it.
class Deck {
  Deck({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
    required this.total,
    required this.enrolled,
    required this.studied,
    required this.due,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon; // a representative glyph/emoji
  final String kind; // 'content' | 'filter'
  final int total;
  final int enrolled;
  final int studied;
  final int due;

  bool get isFilter => kind == 'filter';
  bool get isEmpty => total == 0;
  double get progress => total == 0 ? 0 : (studied / total).clamp(0, 1);

  factory Deck.fromJson(Map<String, dynamic> j) => Deck(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        icon: j['icon'] as String? ?? '',
        kind: j['kind'] as String? ?? 'content',
        total: (j['total'] as num?)?.toInt() ?? 0,
        enrolled: (j['enrolled'] as num?)?.toInt() ?? 0,
        studied: (j['studied'] as num?)?.toInt() ?? 0,
        due: (j['due'] as num?)?.toInt() ?? 0,
      );
}
