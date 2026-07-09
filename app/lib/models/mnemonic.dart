import 'dart:typed_data';

import '../core/api_config.dart';

class Mnemonic {
  Mnemonic({
    required this.id,
    required this.character,
    required this.kind,
    required this.language,
    required this.story,
    required this.imageSrc,
    required this.imageWidth,
    required this.imageHeight,
    required this.authorName,
    required this.isSeed,
    required this.status,
    required this.score,
    required this.myVote,
    required this.saved,
    this.imageBytes,
  });

  final int id;
  final String character;
  final String kind;
  final String language;
  final String story;
  final String imageSrc;
  final int imageWidth;
  final int imageHeight;
  final String authorName;
  final bool isSeed;
  final String status;
  final int score;
  final int myVote; // -1, 0, +1
  final bool saved; // the Instagram 🔖 bookmark

  /// Set when the mnemonic was read from an offline pack (the WebP travels as
  /// a BLOB in the pack instead of a media URL).
  final Uint8List? imageBytes;

  bool get hasImage => imageSrc.isNotEmpty || imageBytes != null;
  bool get liked => myVote > 0;

  /// Only published mnemonics can be liked/saved; a still-"in review" one is
  /// visible to its author but the server rejects votes/saves on it.
  bool get isVisible => status == 'visible';

  /// Absolute image URL (the API returns a relative /media/… path for locally
  /// stored uploads; R2/CDN URLs come back absolute).
  String get imageUrl {
    if (imageSrc.isEmpty) return '';
    if (imageSrc.startsWith('http')) return imageSrc;
    return '${ApiConfig.baseUrl}$imageSrc';
  }

  factory Mnemonic.fromJson(Map<String, dynamic> j) => Mnemonic(
        id: (j['id'] as num).toInt(),
        character: j['character'] as String? ?? '',
        kind: j['kind'] as String? ?? 'kana',
        language: j['language'] as String? ?? 'en',
        story: j['story'] as String? ?? '',
        imageSrc: j['image_src'] as String? ?? '',
        imageWidth: (j['image_width'] as num?)?.toInt() ?? 0,
        imageHeight: (j['image_height'] as num?)?.toInt() ?? 0,
        authorName: j['author_name'] as String? ?? 'jibiki',
        isSeed: j['is_seed'] as bool? ?? false,
        status: j['status'] as String? ?? 'visible',
        score: (j['score'] as num?)?.toInt() ?? 0,
        myVote: (j['my_vote'] as num?)?.toInt() ?? 0,
        saved: j['saved'] as bool? ?? false,
      );

  Mnemonic copyWith({int? score, int? myVote, bool? saved}) => Mnemonic(
        id: id,
        character: character,
        kind: kind,
        language: language,
        story: story,
        imageSrc: imageSrc,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        authorName: authorName,
        isSeed: isSeed,
        status: status,
        score: score ?? this.score,
        myVote: myVote ?? this.myVote,
        saved: saved ?? this.saved,
        imageBytes: imageBytes,
      );
}
