import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';

/// Standard TCG card proportions.
const double kCollectionCardAspect = 63 / 88;

Color colorFromHex(String hex) =>
    Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);

/// Placeholder motif icons: a composed silhouette per subject, so layout,
/// contrast and the collection feel can be validated before final
/// illustrations replace them (BOOSTER_COLLECTION_PLAN.md). No text is baked
/// into the art; every label below is composed by the interface.
IconData motifIcon(String motif) => switch (motif) {
      'mountain' => Icons.terrain_rounded,
      'gate' => Icons.temple_buddhist_rounded,
      'bowl' => Icons.ramen_dining_rounded,
      'tea' => Icons.emoji_food_beverage_rounded,
      'cat' => Icons.pets_rounded,
      'train' => Icons.train_rounded,
      'leaf' => Icons.park_rounded,
      'steam' => Icons.hot_tub_rounded,
      'crane' => Icons.interests_rounded,
      'machine' => Icons.kitchen_rounded,
      'pavilion' => Icons.account_balance_rounded,
      'wave' => Icons.waves_rounded,
      'ring' => Icons.sports_martial_arts_rounded,
      'fox' => Icons.cruelty_free_rounded,
      'blossom' => Icons.local_florist_rounded,
      'crossing' => Icons.traffic_rounded,
      'dragon' => Icons.whatshot_rounded,
      'burst' => Icons.celebration_rounded,
      'lantern' => Icons.light_rounded,
      'crane-bird' => Icons.flutter_dash,
      _ => Icons.style_rounded,
    };

extension CardRarityUi on CardRarity {
  String label(BuildContext context) => switch (this) {
        CardRarity.common => context.l10n.rarityCommon,
        CardRarity.rare => context.l10n.rarityRare,
        CardRarity.special => context.l10n.raritySpecial,
        CardRarity.shiny => context.l10n.rarityShiny,
      };

  Color chipColor(BuildContext context) => switch (this) {
        CardRarity.common => context.jc.surfaceAlt,
        CardRarity.rare => context.jc.lavender,
        CardRarity.special => context.jc.acid,
        CardRarity.shiny => context.jc.magenta,
      };
}

String categoryLabel(BuildContext context, String category) =>
    switch (category) {
      'place' => context.l10n.categoryPlace,
      'culture' => context.l10n.categoryCulture,
      'food' => context.l10n.categoryFood,
      'object' => context.l10n.categoryObject,
      'transport' => context.l10n.categoryTransport,
      'nature' => context.l10n.categoryNature,
      'craft' => context.l10n.categoryCraft,
      'person' => context.l10n.categoryPerson,
      'society' => context.l10n.categorySociety,
      'history' => context.l10n.categoryHistory,
      'festival' => context.l10n.categoryFestival,
      _ => category,
    };

/// The visual grammar of a rarity: the metallic frame, the accent, the gem and
/// whether the card carries a glow. Higher rarities read as more precious.
class _RarityStyle {
  const _RarityStyle({
    required this.frame,
    required this.accent,
    required this.gem,
    required this.glow,
    required this.holo,
  });

  final List<Color> frame; // metallic border gradient
  final Color accent; // nameplate rule + number pill
  final List<Color> gem; // rarity gem gradient
  final bool glow;
  final bool holo; // rainbow wash over the art

  static _RarityStyle of(CardRarity rarity, JibikiColors jc) => switch (rarity) {
        CardRarity.common => _RarityStyle(
            frame: [jc.ink, jc.ink],
            accent: jc.muted,
            gem: [jc.surfaceAlt, jc.surfaceAlt],
            glow: false,
            holo: false,
          ),
        CardRarity.rare => const _RarityStyle(
            frame: [Color(0xFFEAEEF6), Color(0xFF9AA2B4), Color(0xFFCED4E0)],
            accent: Color(0xFF8A90A0),
            gem: [Color(0xFFF2F4FA), Color(0xFF9AA2B4)],
            glow: false,
            holo: false,
          ),
        CardRarity.special => const _RarityStyle(
            frame: [Color(0xFFFFE9A8), Color(0xFFC9971F), Color(0xFFFFF3CE)],
            accent: Color(0xFFB8860B),
            gem: [Color(0xFFFFF3CE), Color(0xFFD4A017)],
            glow: true,
            holo: false,
          ),
        CardRarity.shiny => const _RarityStyle(
            frame: [Color(0xFFFF8AD0), Color(0xFF6A4BFF), Color(0xFFFF57A8)],
            accent: Color(0xFFFF57A8),
            gem: [Color(0xFFFFFFFF), Color(0xFFFF57A8)],
            glow: true,
            holo: true,
          ),
      };
}

/// The front face of a collection card: a framed illustration window over a
/// name plate, styled by rarity. [owned] false renders it as a dim silhouette
/// (the album's "missing" look) without hiding what the card is.
class CollectionCardFace extends StatelessWidget {
  const CollectionCardFace({
    super.key,
    required this.card,
    this.owned = true,
    this.copies = 0,
    this.dense = false,
  });

  final CollectionCardDef card;
  final bool owned;

  /// Copies owned; a value above 1 shows the duplicate badge.
  final int copies;

  /// Dense mode trims secondary labels for small grid tiles.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final style = _RarityStyle.of(card.rarity, jc);
    final frameW = dense ? 3.0 : 4.0;
    final gap = dense ? 2.5 : 3.5;
    const radius = Radii.md;
    final lit = owned;

    return AspectRatio(
      aspectRatio: kCollectionCardAspect,
      child: Container(
        decoration: BoxDecoration(
          gradient: lit
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: style.frame,
                )
              : null,
          color: lit ? null : jc.surfaceAlt,
          borderRadius: BorderRadius.circular(radius),
          border: lit && card.rarity == CardRarity.common
              ? null
              : Border.all(color: jc.ink.withValues(alpha: lit ? .35 : .5)),
          boxShadow: [
            if (lit && style.glow)
              BoxShadow(
                color: style.accent.withValues(alpha: .5),
                blurRadius: dense ? 12 : 22,
                spreadRadius: dense ? 0 : 2,
              ),
            BoxShadow(
              color: jc.ink.withValues(alpha: lit ? .9 : .3),
              blurRadius: 0,
              offset: Offset(gap, gap),
            ),
          ],
        ),
        padding: EdgeInsets.all(frameW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ArtWindow(
                card: card,
                style: style,
                owned: owned,
                dense: dense,
                radius: radius - frameW,
              ),
            ),
            SizedBox(height: gap),
            _NamePlate(
              card: card,
              style: style,
              owned: owned,
              copies: copies,
              dense: dense,
              radius: radius - frameW,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtWindow extends StatelessWidget {
  const _ArtWindow({
    required this.card,
    required this.style,
    required this.owned,
    required this.dense,
    required this.radius,
  });

  final CollectionCardDef card;
  final _RarityStyle style;
  final bool owned;
  final bool dense;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final top = colorFromHex(card.art.colors.first);
    final bottom = colorFromHex(
        card.art.colors.length > 1 ? card.art.colors[1] : card.art.colors[0]);
    final icon = motifIcon(card.art.motif);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final focal = h * .42;
          final onDark = owned &&
              (card.rarity == CardRarity.shiny ||
                  ThemeData.estimateBrightnessForColor(bottom) ==
                      Brightness.dark);
          final motifColor = owned
              ? (onDark
                  ? Colors.white.withValues(alpha: .92)
                  : jc.ink.withValues(alpha: .7))
              : jc.muted.withValues(alpha: .45);

          // The bundled photo, when this card has one. Missing cards keep
          // the muted silhouette: the album teases the subject, not the shot.
          final asset = owned ? card.art.asset : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Base illustration gradient (or a flat muted panel if missing).
              // Always painted: it is the placeholder under a loading photo
              // and the whole art when no photo exists.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: owned
                        ? [top, Color.lerp(top, bottom, .5)!, bottom]
                        : [jc.surfaceAlt, jc.surface, jc.surfaceAlt],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
              // Depth: a big watermark motif bleeding off the bottom-right.
              Positioned(
                right: -w * .18,
                bottom: -h * .12,
                child: Icon(
                  icon,
                  size: h * .95,
                  color: (owned ? Colors.white : jc.muted)
                      .withValues(alpha: owned ? .1 : .06),
                ),
              ),
              if (asset != null)
                Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  // A broken asset falls back to the composed placeholder.
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              // Top-left sheen for a lit, glossy surface.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-.7, -.8),
                      radius: 1.1,
                      colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
                      stops: [0, .6],
                    ),
                  ),
                ),
              ),
              // Focal motif, only while the card has no photo of its own.
              if (asset == null)
                Center(
                  child: Icon(
                    icon,
                    size: focal,
                    color: motifColor,
                    shadows: owned
                        ? [
                            Shadow(
                              color: Colors.black.withValues(alpha: .25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
              // Rainbow holo wash for shiny (static; the reveal adds a live one).
              if (style.holo && owned)
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      backgroundBlendMode: BlendMode.plus,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x2200E5FF),
                          Color(0x22FF00E5),
                          Color(0x22FFE500),
                          Color(0x2200FF95),
                        ],
                      ),
                    ),
                  ),
                ),
              // Bottom vignette so the name plate seam reads cleanly.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x30000000)],
                    ),
                  ),
                ),
              ),
              // Rarity gem, top-left, for rare and above.
              if (owned && card.rarity != CardRarity.common)
                Positioned(
                  top: dense ? 5 : 7,
                  left: dense ? 5 : 7,
                  child: _RarityGem(style: style, dense: dense),
                ),
              // Shiny sparkle marker, top-right.
              if (style.holo && owned)
                Positioned(
                  top: dense ? 4 : 6,
                  right: dense ? 4 : 6,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: dense ? 13 : 18, color: Colors.white),
                ),
              // Missing: a lock over the silhouette.
              if (!owned)
                Center(
                  child: Icon(Icons.lock_outline_rounded,
                      size: dense ? 20 : 28,
                      color: jc.muted.withValues(alpha: .7)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RarityGem extends StatelessWidget {
  const _RarityGem({required this.style, required this.dense});
  final _RarityStyle style;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = dense ? 12.0 : 16.0;
    return Transform.rotate(
      angle: 0.785398, // 45°, a diamond
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: style.gem),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white.withValues(alpha: .8)),
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: .6),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.card,
    required this.style,
    required this.owned,
    required this.copies,
    required this.dense,
    required this.radius,
  });

  final CollectionCardDef card;
  final _RarityStyle style;
  final bool owned;
  final int copies;
  final bool dense;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final language = Localizations.localeOf(context).languageCode;

    return Container(
      padding: EdgeInsets.fromLTRB(
          dense ? 7 : 10, dense ? 5 : 7, dense ? 6 : 8, dense ? 6 : 8),
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border(
          top: BorderSide(color: style.accent.withValues(alpha: .5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  card.nameJa,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: dense ? 12.5 : 17,
                    fontWeight: FontWeight.w800,
                    color: owned ? jc.ink : jc.muted,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '#${card.number.toString().padLeft(3, '0')}',
                style: TextStyle(
                  fontSize: dense ? 9 : 10.5,
                  fontWeight: FontWeight.w800,
                  color: style.accent,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
          Text(
            owned ? card.name.resolve(language) : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 10 : 12.5,
              fontWeight: FontWeight.w600,
              color: owned ? jc.body : jc.muted,
              height: 1.2,
            ),
          ),
          if (!dense) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                _RarityDot(rarity: card.rarity, owned: owned),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    card.rarity.label(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: jc.muted,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                if (copies > 1)
                  Text(
                    '×$copies',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: jc.lime,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RarityDot extends StatelessWidget {
  const _RarityDot({required this.rarity, required this.owned});

  final CardRarity rarity;
  final bool owned;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: owned ? rarity.chipColor(context) : context.jc.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: context.jc.ink, width: 1.5),
        ),
      );
}
