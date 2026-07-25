/// Japan card collection: card and set definitions loaded from the bundled
/// catalog asset, plus reward-side value types (grants, openings, burn state).
/// Rules live in docs/REWARDS.md.
library;

/// Text authored per language. Seed copy is never language-neutral: a lookup
/// tells the caller whether the string is authored in the requested language
/// or is an identified fallback, so the UI can label fallbacks honestly.
class LocalizedText {
  const LocalizedText(this._values);

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText({
        for (final entry in json.entries) entry.key: entry.value as String,
      });

  final Map<String, String> _values;

  static const String _fallbackLanguage = 'en';

  bool authoredIn(String language) => _values.containsKey(language);

  /// The string for [language], or the declared fallback. Check
  /// [authoredIn] when the UI must mark fallback content as such.
  String resolve(String language) =>
      _values[language] ?? _values[_fallbackLanguage] ?? _values.values.first;
}

enum CardRarity {
  common,
  rare,
  special,
  shiny;

  static CardRarity fromWire(String value) =>
      CardRarity.values.firstWhere((rarity) => rarity.name == value);
}

/// A cosmetic permanently unlocked when the card joins the collection.
/// Today the only type is `palette` (a theme palette id).
class CardUnlock {
  const CardUnlock({required this.type, required this.value, required this.label});

  factory CardUnlock.fromJson(Map<String, dynamic> json) => CardUnlock(
        type: json['type'] as String,
        value: json['value'] as String,
        label: LocalizedText.fromJson(
            (json['label'] as Map).cast<String, dynamic>()),
      );

  final String type;
  final String value;
  final LocalizedText label;

  bool get isPalette => type == 'palette';
}

class CardVocab {
  const CardVocab({required this.ja, required this.reading, required this.gloss});

  factory CardVocab.fromJson(Map<String, dynamic> json) => CardVocab(
        ja: json['ja'] as String,
        reading: json['reading'] as String,
        gloss: LocalizedText.fromJson(
            (json['gloss'] as Map).cast<String, dynamic>()),
      );

  final String ja;
  final String reading;
  final LocalizedText gloss;
}

/// Card art spec. When [asset] is set the card shows that bundled photo
/// (with [credit] naming author and license, shown in the card detail);
/// [motif] and [colors] always remain as the composed placeholder used
/// while the photo loads, if it fails, or when no photo exists yet. No text
/// is ever baked into images.
class CardArt {
  const CardArt({
    required this.motif,
    required this.colors,
    this.asset,
    this.credit,
  });

  factory CardArt.fromJson(Map<String, dynamic> json) => CardArt(
        motif: json['motif'] as String,
        colors: (json['colors'] as List).cast<String>(),
        asset: json['asset'] as String?,
        credit: json['credit'] as String?,
      );

  final String motif;
  final List<String> colors;
  final String? asset;
  final String? credit;
}

class CollectionCardDef {
  const CollectionCardDef({
    required this.id,
    required this.number,
    required this.category,
    required this.rarity,
    required this.nameJa,
    required this.reading,
    required this.name,
    required this.body,
    required this.context,
    required this.vocab,
    required this.art,
    this.unlock,
  });

  factory CollectionCardDef.fromJson(Map<String, dynamic> json) =>
      CollectionCardDef(
        id: json['id'] as String,
        number: (json['number'] as num).toInt(),
        category: json['category'] as String,
        rarity: CardRarity.fromWire(json['rarity'] as String),
        nameJa: json['nameJa'] as String,
        reading: json['reading'] as String,
        name: LocalizedText.fromJson(
            (json['name'] as Map).cast<String, dynamic>()),
        body: LocalizedText.fromJson(
            (json['body'] as Map).cast<String, dynamic>()),
        context: LocalizedText.fromJson(
            (json['context'] as Map).cast<String, dynamic>()),
        vocab: [
          for (final item in (json['vocab'] as List? ?? const []))
            CardVocab.fromJson((item as Map).cast<String, dynamic>()),
        ],
        art: CardArt.fromJson((json['art'] as Map).cast<String, dynamic>()),
        unlock: json['unlock'] == null
            ? null
            : CardUnlock.fromJson(
                (json['unlock'] as Map).cast<String, dynamic>()),
      );

  final String id;
  final int number;
  final String category;
  final CardRarity rarity;
  final String nameJa;
  final String reading;
  final LocalizedText name;
  final LocalizedText body;
  final LocalizedText context;
  final List<CardVocab> vocab;
  final CardArt art;
  final CardUnlock? unlock;
}

class CollectionSetDef {
  const CollectionSetDef({
    required this.id,
    required this.number,
    required this.name,
    required this.cards,
  });

  factory CollectionSetDef.fromJson(Map<String, dynamic> json) =>
      CollectionSetDef(
        id: json['id'] as String,
        number: (json['number'] as num).toInt(),
        name: LocalizedText.fromJson(
            (json['name'] as Map).cast<String, dynamic>()),
        cards: [
          for (final card in json['cards'] as List)
            CollectionCardDef.fromJson((card as Map).cast<String, dynamic>()),
        ],
      );

  final String id;
  final int number;
  final LocalizedText name;
  final List<CollectionCardDef> cards;

  Iterable<CollectionCardDef> byRarity(CardRarity rarity) =>
      cards.where((card) => card.rarity == rarity);
}

class CollectionCatalog {
  CollectionCatalog({required this.sets})
      : cardsById = {
          for (final set in sets)
            for (final card in set.cards) card.id: card,
        };

  factory CollectionCatalog.fromJson(Map<String, dynamic> json) =>
      CollectionCatalog(
        sets: [
          for (final set in json['sets'] as List)
            CollectionSetDef.fromJson((set as Map).cast<String, dynamic>()),
        ],
      );

  final List<CollectionSetDef> sets;
  final Map<String, CollectionCardDef> cardsById;

  /// The set boosters currently draw from. One permanent set today; seasonal
  /// selections would change this pointer, never the collection itself.
  CollectionSetDef get activeSet => sets.first;
}

/// One owned card (possibly several copies).
class CollectionEntry {
  const CollectionEntry({
    required this.cardId,
    required this.count,
    required this.firstObtainedAt,
  });

  final String cardId;
  final int count;
  final DateTime firstObtainedAt;

  int get duplicates => count - 1;
}

enum BoosterStatus {
  unopened,
  opened,

  /// Milestone honored while 3 boosters were already stored: recorded so the
  /// milestone never re-grants, but no booster was created.
  skippedFull;

  static BoosterStatus fromWire(String value) => switch (value) {
        'unopened' => BoosterStatus.unopened,
        'opened' => BoosterStatus.opened,
        'skipped_full' => BoosterStatus.skippedFull,
        _ => throw StateError('unknown booster status $value'),
      };

  String get wire => switch (this) {
        BoosterStatus.unopened => 'unopened',
        BoosterStatus.opened => 'opened',
        BoosterStatus.skippedFull => 'skipped_full',
      };
}

class BoosterGrant {
  const BoosterGrant({
    required this.id,
    required this.milestone,
    required this.status,
    required this.grantedAt,
    this.openedAt,
  });

  final String id;
  final int milestone;
  final BoosterStatus status;
  final DateTime grantedAt;
  final DateTime? openedAt;
}

/// One card slot of an opening, in reveal order (the shiny is last).
class DrawnCard {
  const DrawnCard({
    required this.cardId,
    required this.isNew,
    required this.countAfter,
  });

  factory DrawnCard.fromJson(Map<String, dynamic> json) => DrawnCard(
        cardId: json['card_id'] as String,
        isNew: json['is_new'] as bool,
        countAfter: (json['count_after'] as num).toInt(),
      );

  final String cardId;

  /// First copy ever obtained (vs a duplicate).
  final bool isNew;

  /// Copies owned once this draw is applied ("Doublon x2" shows countAfter).
  final int countAfter;

  Map<String, dynamic> toJson() => {
        'card_id': cardId,
        'is_new': isNew,
        'count_after': countAfter,
      };
}

class BoosterOpening {
  const BoosterOpening({required this.grantId, required this.cards});

  final String grantId;
  final List<DrawnCard> cards;

  Iterable<DrawnCard> get newCards => cards.where((card) => card.isNew);
  Iterable<DrawnCard> get duplicateCards => cards.where((card) => !card.isNew);
}

/// Positive framing only: the burn invites the user back, it never threatens.
class BurnState {
  const BurnState({
    required this.current,
    required this.best,
    required this.qualifiedToday,
    required this.recentDays,
    required this.nextMilestone,
  });

  static const empty = BurnState(
    current: 0,
    best: 0,
    qualifiedToday: false,
    recentDays: [],
    nextMilestone: 3,
  );

  /// Consecutive qualified days ending today or yesterday. A qualified day has
  /// at least one real review submitted; opening the app never counts.
  final int current;

  /// Never reset by a missed day.
  final int best;

  final bool qualifiedToday;

  /// The last 7 days, oldest first, true = qualified. For the short chain view.
  final List<bool> recentDays;

  /// The next burn length that grants a booster.
  final int nextMilestone;

  int get daysToNextMilestone => nextMilestone - current;
}

/// Burn milestones that grant a booster: 3, 7, 14, 21, 30, then every 7 days.
List<int> milestonesUpTo(int streak) {
  const fixed = [3, 7, 14, 21, 30];
  final reached = [
    for (final milestone in fixed)
      if (milestone <= streak) milestone,
  ];
  for (var milestone = 37; milestone <= streak; milestone += 7) {
    reached.add(milestone);
  }
  return reached;
}

int nextMilestoneAfter(int streak) {
  const fixed = [3, 7, 14, 21, 30];
  for (final milestone in fixed) {
    if (milestone > streak) return milestone;
  }
  var milestone = 37;
  while (milestone <= streak) {
    milestone += 7;
  }
  return milestone;
}
