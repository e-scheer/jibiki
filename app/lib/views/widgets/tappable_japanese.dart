import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/dictionary_repository.dart';
import '../../theme/app_theme.dart';

/// One kana/kanji found inside a string that we can open a detail page for.
typedef Lookupable = ({String char, bool isKanji});

// Small (sutegana) kana and marks are never standalone learnable units, so we
// don't linkify them — tapping ゃ or っ shouldn't try to open a detail page.
const Set<int> _smallKana = {
  0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087, 0x308E, 0x3095, 0x3096,
  0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x30F5, 0x30F6,
};

bool _isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) || // CJK Unified
    (c >= 0x3400 && c <= 0x4DBF) || // Extension A
    (c >= 0xF900 && c <= 0xFAFF) || // Compatibility ideographs
    (c >= 0x20000 && c <= 0x2A6DF); // Extension B

// Full-width hiragana (あ‥ん) / katakana (ア‥ン), excluding the small kana above.
// The narrow ranges leave out ー・゛゜ and the archaic ゐゑ neighbours' marks.
bool _isKana(int c) =>
    !_smallKana.contains(c) &&
    ((c >= 0x3042 && c <= 0x3093) || (c >= 0x30A2 && c <= 0x30F3));

/// The kana/kanji inside [text] worth a detail page, in first-seen order, deduped.
List<Lookupable> lookupableChars(String text) {
  final seen = <String>{};
  final out = <Lookupable>[];
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    if (!seen.add(ch)) continue;
    if (_isKanji(r)) {
      out.add((char: ch, isKanji: true));
    } else if (_isKana(r)) {
      out.add((char: ch, isKanji: false));
    }
  }
  return out;
}

/// Renders a Japanese string as a single "look it up" target — the elegant way
/// back down to the basics from anywhere text appears. Tapping it drills in: a
/// lone kana/kanji jumps straight to its detail page; a longer word or sentence
/// opens a breakdown sheet where each kana/kanji is itself tappable through to
/// its detail. Runs with no Japanese in them just render as plain, inert text.
class TappableJapanese extends StatelessWidget {
  const TappableJapanese(this.text, {super.key, this.style, this.affordance = true});
  final String text;
  final TextStyle? style;

  /// A subtle dotted underline hinting "tap to look up". Off for hero glyphs that
  /// read as tappable on their own.
  final bool affordance;

  @override
  Widget build(BuildContext context) {
    final chars = lookupableChars(text);
    if (chars.isEmpty) return Text(text, style: style);
    final jc = context.jc;
    final styled = affordance
        ? (style ?? const TextStyle()).copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: jc.muted.withValues(alpha: 0.45),
            decorationThickness: 1.5,
          )
        : style;
    return GestureDetector(
      onTap: () {
        Haptics.tick();
        if (chars.length == 1) {
          _open(context, chars.first);
        } else {
          _showBreakdown(context, chars);
        }
      },
      child: Text(text, style: styled),
    );
  }

  void _open(BuildContext context, Lookupable c) =>
      context.push(c.isKanji ? '/kanji/${c.char}' : '/kana/${c.char}');

  void _showBreakdown(BuildContext context, List<Lookupable> chars) {
    // The kana chart is memoized by the repository, so this is effectively free
    // and lets each kana tile show its romaji reading. Guarded so the widget
    // still works (sans romaji) if ever used outside the app's provider scope.
    Future<Map<String, String>>? romajiByChar;
    try {
      romajiByChar = context
          .read<DictionaryRepository>()
          .kana()
          .then((list) => {for (final k in list) k.char: k.romaji});
    } catch (_) {
      romajiByChar = null;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        final jc = sheetCtx.jc;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: FutureBuilder<Map<String, String>>(
              future: romajiByChar,
              builder: (ctx, snap) {
                final romaji = snap.data ?? const <String, String>{};
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: sheetCtx.text.headlineSmall),
                    const SizedBox(height: 2),
                    Text('Tap a character to look it up',
                        style: TextStyle(color: jc.muted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in chars)
                          _CharTile(
                            lookup: c,
                            romaji: c.isKanji ? null : romaji[c.char],
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _open(context, c);
                            },
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CharTile extends StatelessWidget {
  const _CharTile({required this.lookup, required this.onTap, this.romaji});
  final Lookupable lookup;
  final String? romaji; // the kana's reading; null for kanji (contextual readings)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // Kana carry their romaji reading (in the accent colour, since it's the
    // useful bit); kanji just say "Kanji" — their readings live on the detail.
    final isRomaji = !lookup.isKanji && (romaji?.isNotEmpty ?? false);
    final sub = lookup.isKanji ? 'Kanji' : (romaji ?? 'Kana');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: jc.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lookup.char,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.0)),
            const SizedBox(height: 6),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isRomaji ? jc.brand : jc.muted)),
          ],
        ),
      ),
    );
  }
}
