import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/kana.dart';
import '../../models/kanji.dart';
import '../../theme/app_theme.dart';
import 'speech_button.dart';

/// The "Origin" block on the kanji detail screen: the glyph-origin story
/// (Wiktionary, CC BY-SA), a formation badge (pictogram / ideogrammic /
/// phono-semantic), and - the learner's-eye detail - a callout naming the
/// phonetic (音符) component: the part that is present for its *sound*, not its
/// meaning. That keisei insight is exactly what makes a busy character legible.
class KanjiOriginSection extends StatelessWidget {
  const KanjiOriginSection({super.key, required this.kanji});
  final KanjiEntry kanji;

  @override
  Widget build(BuildContext context) {
    final k = kanji;
    if (!k.hasOrigin) return const SizedBox.shrink();
    final jc = context.jc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Origin', style: context.text.titleMedium),
            if (k.formation.isNotEmpty) ...[
              const SizedBox(width: 8),
              _FormationBadge(formation: k.formation),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: jc.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k.origin, style: context.text.bodyMedium),
              if (k.phonetic.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PhoneticCallout(phonetic: k.phonetic, self: k.literal),
              ],
              const SizedBox(height: 12),
              Text('Glyph origin from Wiktionary · CC BY-SA',
                  style: TextStyle(color: jc.muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A coloured pill naming how the character was formed, with its Japanese term.
class _FormationBadge extends StatelessWidget {
  const _FormationBadge({required this.formation});
  final String formation;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final (label, jp, color) = switch (formation) {
      'phono-semantic' => ('Phono-semantic', '形声', jc.ratingEasy),
      'ideogrammic' => ('Ideogrammic', '会意', jc.ratingGood),
      'pictogram' => ('Pictogram', '象形', jc.warn),
      'simplified' => ('Simplified', '', jc.muted),
      'variant' => ('Variant', '異体字', jc.muted),
      'abbreviation' => ('Abbreviation', '略字', jc.muted),
      'phonetic-loan' => ('Phonetic loan', '仮借', jc.muted),
      'compound' => ('Compound', '', jc.muted),
      'contraction' => ('Contraction', '', jc.muted),
      _ => ('', '', jc.muted),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        jp.isEmpty ? label : '$label · $jp',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Highlights the 音符 (phonetic) component of a phono-semantic compound - the
/// single most useful thing to know about a busy kanji. Tappable through to that
/// component's own detail page when it isn't the character itself.
class _PhoneticCallout extends StatelessWidget {
  const _PhoneticCallout({required this.phonetic, required this.self});
  final String phonetic;
  final String self;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final tappable = phonetic != self;
    return InkWell(
      onTap: tappable ? () => context.push('/kanji/$phonetic') : null,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: jc.brandSoft,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: jc.surface,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(phonetic,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: jc.ink, height: 1.0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('音符 · sound component',
                      style: TextStyle(color: jc.brand, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text('$phonetic is here to hint the reading - not the meaning.',
                      style: TextStyle(color: jc.body, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            if (tappable) Icon(Icons.chevron_right, color: jc.brand, size: 20),
          ],
        ),
      ),
    );
  }
}

/// The "Origin" block on the kana detail screen: the man'yōgana kanji (or, for
/// dakuten/handakuten, the base kana) this glyph grew out of, shown as a small
/// derivation diagram - source → kana - with the one-line story beneath.
class KanaOriginSection extends StatelessWidget {
  const KanaOriginSection({super.key, required this.kana});
  final KanaEntry kana;

  @override
  Widget build(BuildContext context) {
    if (!kana.hasOrigin) return const SizedBox.shrink();
    final jc = context.jc;
    // Gojūon kana derive from a kanji worth visiting; dakuten from a base kana.
    final onTap = kana.originIsKanji ? () => context.push('/kanji/${kana.origin}') : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Origin', style: context.text.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: jc.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlyphBox(char: kana.origin, onTap: onTap),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.arrow_forward, color: jc.muted, size: 22),
                  ),
                  _GlyphBox(char: kana.char, brand: true),
                ],
              ),
              const SizedBox(height: 14),
              Text(kana.originNote, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "In a sentence" block on the kana detail screen: for the kana that pull
/// double duty as grammar - the particles (は topic, を object, の possessive, か
/// question …) and the special ん - a role badge and a one-line "what it does in a
/// sentence". Purely phonetic kana have no usage and this collapses away.
class KanaGrammarSection extends StatelessWidget {
  const KanaGrammarSection({super.key, required this.kana});
  final KanaEntry kana;

  @override
  Widget build(BuildContext context) {
    if (!kana.hasUsage) return const SizedBox.shrink();
    final jc = context.jc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('In a sentence', style: context.text.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: jc.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kana.usageLabel.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: jc.brand.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Text(kana.usageLabel,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: jc.brand)),
                ),
                const SizedBox(height: 10),
              ],
              Text(kana.usage, style: context.text.bodyMedium),
              for (final e in kana.usageExamples) ...[
                const SizedBox(height: 12),
                _UsageExampleRow(example: e),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One particle example: the Japanese sentence with the particle lit up in
/// brand colour, a speaker to hear it, then romaji and the English underneath.
class _UsageExampleRow extends StatelessWidget {
  const _UsageExampleRow({required this.example});
  final KanaUsageExample example;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: jc.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 16, height: 1.4, color: jc.ink),
                    children: [
                      TextSpan(text: example.before),
                      TextSpan(
                        text: example.particle,
                        style: TextStyle(color: jc.brand, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: example.after),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(example.romaji,
                    style: TextStyle(
                        color: jc.muted, fontSize: 12.5, fontStyle: FontStyle.italic, height: 1.3)),
                const SizedBox(height: 2),
                Text(example.en, style: TextStyle(color: jc.body, fontSize: 13.5, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SpeechButton(text: example.sentence, size: 18),
        ],
      ),
    );
  }
}

class _GlyphBox extends StatelessWidget {
  const _GlyphBox({required this.char, this.brand = false, this.onTap});
  final String char;
  final bool brand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final box = Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand ? jc.brandSoft : jc.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(char,
          style: TextStyle(
              fontSize: 44, fontWeight: FontWeight.w600, height: 1.0, color: brand ? jc.brand : jc.ink)),
    );
    if (onTap == null) return box;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(Radii.md), child: box);
  }
}
