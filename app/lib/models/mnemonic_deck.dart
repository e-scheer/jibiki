import '../core/api_config.dart';
import 'mnemonic.dart';

/// A user-authored, community-shared pack of visual mnemonics, the "propose as a
/// deck" side of the drawing ecosystem. On list views it carries a cover + counts;
/// the detail view also carries its ordered [items].
class MnemonicDeck {
  MnemonicDeck({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.kind,
    required this.authorName,
    required this.isSeed,
    required this.status,
    required this.score,
    required this.itemCount,
    required this.coverSrc,
    required this.myVote,
    this.items = const [],
  });

  final int id;
  final String title;
  final String description;
  final String language;
  final String kind; // 'kana' | 'kanji'
  final String authorName;
  final bool isSeed;
  final String status; // draft | pending | visible | hidden | removed
  final int score;
  final int itemCount;
  final String coverSrc;
  final int myVote; // 0 | 1 (like)
  final List<Mnemonic> items;

  bool get isPublic => status == 'visible';
  bool get isDraft => status == 'draft';
  bool get isPending => status == 'pending';
  bool get liked => myVote > 0;
  bool get hasCover => coverSrc.isNotEmpty;

  /// Absolute cover URL (relative /media/… paths get the API base prefixed).
  String get coverUrl {
    return ApiConfig.absoluteUrl(coverSrc);
  }

  factory MnemonicDeck.fromJson(Map<String, dynamic> j) => MnemonicDeck(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        language: j['language'] as String? ?? 'en',
        kind: j['kind'] as String? ?? 'kana',
        authorName: j['author_name'] as String? ?? 'jibiki',
        isSeed: j['is_seed'] as bool? ?? false,
        status: j['status'] as String? ?? 'visible',
        score: (j['score'] as num?)?.toInt() ?? 0,
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
        coverSrc: j['cover_src'] as String? ?? '',
        myVote: (j['my_vote'] as num?)?.toInt() ?? 0,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => Mnemonic.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  MnemonicDeck copyWith({int? score, int? myVote, String? status}) =>
      MnemonicDeck(
        id: id,
        title: title,
        description: description,
        language: language,
        kind: kind,
        authorName: authorName,
        isSeed: isSeed,
        status: status ?? this.status,
        score: score ?? this.score,
        itemCount: itemCount,
        coverSrc: coverSrc,
        myVote: myVote ?? this.myVote,
        items: items,
      );
}
