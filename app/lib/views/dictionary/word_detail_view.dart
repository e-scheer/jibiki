import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/word_detail_viewmodel.dart';
import '../widgets/study_status_bar.dart';
import '../widgets/speech_button.dart';
import '../widgets/status_views.dart';
import '../widgets/tappable_japanese.dart';

class WordDetailView extends StatelessWidget {
  const WordDetailView({super.key, required this.wordId});
  final int wordId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          WordDetailViewModel(ctx.read<DictionaryRepository>(), ctx.read<StudyRepository>(), wordId)..load(),
      child: const _WordDetail(),
    );
  }
}

class _WordDetail extends StatelessWidget {
  const _WordDetail();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WordDetailViewModel>();
    final lang = context.read<AppState>().mnemonicLanguage;
    final word = vm.word;
    return Scaffold(
      appBar: AppBar(title: const Text('Word')),
      bottomNavigationBar:
          word == null ? null : StudyStatusBar(status: vm.status, onSetStatus: vm.setStatus),
      body: BoundedContent(
        child: vm.isLoading
            ? const LoadingView()
            : vm.hasError
                ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                : word == null
                    ? const SizedBox.shrink()
                    : _content(context, word, lang),
      ),
    );
  }

  Widget _content(BuildContext context, WordEntry word, String lang) {
    final jc = context.jc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TappableJapanese(word.headword,
                  affordance: false,
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w600, height: 1.1)),
            ),
            SpeechButton(
              text: word.primaryReading.isNotEmpty ? word.primaryReading : word.headword,
              size: 28,
            ),
          ],
        ),
        if (word.primaryReading.isNotEmpty && word.primaryReading != word.headword)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TappableJapanese(word.primaryReading, style: TextStyle(fontSize: 20, color: jc.muted)),
                if (_pitchOf(word).isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text('pitch ${_pitchOf(word)}',
                        style: TextStyle(fontSize: 11.5, color: jc.body, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          if (word.isCommon) TagChip('common', color: jc.success),
          if (word.jlpt != null) TagChip('JLPT N${word.jlpt}'),
        ]),
        const SizedBox(height: 20),
        Text('Meanings', style: context.text.titleMedium),
        const SizedBox(height: 8),
        ...word.senses.asMap().entries.map((e) => _sense(context, e.key + 1, e.value, lang)),
        if (word.kanjiBreakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Kanji in this word', style: context.text.titleMedium),
          const SizedBox(height: 8),
          ...word.kanjiBreakdown.map((k) => _KanjiRow(
                literal: k.literal,
                meaning: k.meaningsFor(lang).take(3).join(', '),
                readings: [...k.kunReadings, ...k.onReadings].take(4).join('  '),
                onTap: () => context.push('/kanji/${k.literal}'),
              )),
        ],
        if (word.examples.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Examples', style: context.text.titleMedium),
          const SizedBox(height: 8),
          ...word.examples.map((e) => _ExampleRow(example: e)),
        ],
      ],
    );
  }

  /// The pitch pattern of the primary reading (or the first reading that has one).
  String _pitchOf(WordEntry word) {
    for (final r in word.readings) {
      if (r.text == word.primaryReading && r.pitch.isNotEmpty) return r.pitch;
    }
    for (final r in word.readings) {
      if (r.pitch.isNotEmpty) return r.pitch;
    }
    return '';
  }

  Widget _sense(BuildContext context, int n, Sense sense, String lang) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n.', style: TextStyle(color: jc.muted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sense.pos.isNotEmpty)
                  Text(sense.pos.join(', '),
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: jc.muted)),
                Text(sense.glossesFor(lang).join('; '), style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat, hairline-separated kanji row (IG-style list item, no Material Card).
class _KanjiRow extends StatelessWidget {
  const _KanjiRow({required this.literal, required this.meaning, required this.readings, required this.onTap});
  final String literal;
  final String meaning;
  final String readings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(literal, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meaning, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (readings.isNotEmpty)
                    Text(readings, style: TextStyle(color: jc.muted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: jc.muted),
          ],
        ),
      ),
    );
  }
}

/// A Tanaka-corpus example: Japanese sentence over its English translation.
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example});
  final ExampleItem example;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TappableJapanese(example.japanese, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (example.english.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(example.english, style: TextStyle(color: jc.muted, fontSize: 13.5, height: 1.35)),
            ),
        ],
      ),
    );
  }
}
