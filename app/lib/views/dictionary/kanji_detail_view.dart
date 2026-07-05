import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/kanji.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/kanji_detail_viewmodel.dart';
import '../../viewmodels/mnemonic_viewmodel.dart';
import '../study/writing_practice_view.dart';
import '../widgets/add_to_study_bar.dart';
import '../widgets/mnemonic_panel.dart';
import '../widgets/origin_section.dart';
import '../widgets/speech_button.dart';
import '../widgets/status_views.dart';
import '../widgets/stroke_order_view.dart';
import '../widgets/word_tile.dart';

/// The best single Japanese reading to speak for a kanji: the first kun reading
/// (stripped of KANJIDIC's okurigana '.'/'-' markers), else the first on reading,
/// else the character itself.
String _readAloud(KanjiEntry k) {
  String clean(String r) => r.replaceAll(RegExp(r'[.\-‐・～〜]'), '');
  if (k.kunReadings.isNotEmpty) return clean(k.kunReadings.first);
  if (k.onReadings.isNotEmpty) return clean(k.onReadings.first);
  return k.literal;
}

class KanjiDetailView extends StatelessWidget {
  const KanjiDetailView({super.key, required this.literal});
  final String literal;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppState>().mnemonicLanguage;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => KanjiDetailViewModel(
            ctx.read<DictionaryRepository>(),
            ctx.read<StudyRepository>(),
            literal,
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MnemonicViewModel(
            ctx.read<MnemonicRepository>(),
            ctx.read<StudyRepository>(),
            character: literal,
            kind: 'kanji',
            language: lang,
          )..load(),
        ),
      ],
      child: _KanjiDetail(lang: lang),
    );
  }
}

class _KanjiDetail extends StatelessWidget {
  const _KanjiDetail({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KanjiDetailViewModel>();
    final k = vm.kanji;
    return Scaffold(
      appBar: AppBar(title: const Text('Kanji')),
      bottomNavigationBar: k == null
          ? null
          : AddToStudyBar(
              added: vm.added,
              onAdd: () async {
                final ok = await vm.addToStudy();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Added to your study deck' : vm.error ?? 'Failed')),
                  );
                }
              },
            ),
      body: vm.isLoading
          ? const LoadingView()
          : vm.hasError
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : k == null
                  ? const SizedBox.shrink()
                  : _content(context, k),
    );
  }

  Widget _content(BuildContext context, KanjiEntry k) {
    // Parsed once and cached in the ViewModel (not re-parsed on every rebuild).
    final words = context.read<KanjiDetailViewModel>().words;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: k.hasStrokes
              ? StrokeOrderView(paths: k.strokePaths, viewBox: k.strokeViewbox)
              : Text(k.literal, style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w600, height: 1.05)),
        ),
        Center(child: Text(k.meaningsFor(lang).join(', '), style: const TextStyle(fontSize: 18))),
        Center(child: SpeechButton(text: _readAloud(k), tooltip: 'Play reading')),
        if (k.hasStrokes) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WritingPracticeView(
                  character: k.literal,
                  meaning: k.meaningsFor(lang).take(2).join(', '),
                  reading: [...k.kunReadings, ...k.onReadings].take(2).join('  '),
                  strokePaths: k.strokePaths,
                  strokeViewBox: k.strokeViewbox,
                ),
              )),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Practice writing'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: Wrap(spacing: 6, children: [
            TagChip('${k.strokeCount} strokes'),
            if (k.jlpt != null) TagChip('JLPT N${k.jlpt}'),
            if (k.grade != null) TagChip('Grade ${k.grade}'),
            if (k.freqRank != null) TagChip('#${k.freqRank} freq'),
          ]),
        ),
        const SizedBox(height: 20),
        if (k.kunReadings.isNotEmpty) _readings(context, 'Kun', k.kunReadings),
        if (k.onReadings.isNotEmpty) _readings(context, 'On', k.onReadings),
        if (k.componentDetails.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Composition', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: k.componentDetails.map((c) {
              final tappable = c.isKanji && c.literal != k.literal;
              return ActionChip(
                avatar: Text(c.literal, style: const TextStyle(fontSize: 20)),
                label: Text(c.meaning.isEmpty ? c.literal : c.meaning),
                onPressed: tappable ? () => context.push('/kanji/${c.literal}') : null,
              );
            }).toList(),
          ),
        ],
        if (k.hasOrigin) ...[
          const SizedBox(height: 20),
          KanjiOriginSection(kanji: k),
        ],
        const SizedBox(height: 20),
        const MnemonicPanel(),
        if (words.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Words with ${k.literal}', style: context.text.titleMedium),
          const SizedBox(height: 4),
          for (final w in words) ...[
            WordTile(word: w, lang: lang, onTap: () => context.push('/word/${w.id}')),
            if (w != words.last) Divider(height: 1, color: context.jc.hairline),
          ],
        ],
      ],
    );
  }

  Widget _readings(BuildContext context, String label, List<String> readings) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Text(label, style: TextStyle(color: jc.muted, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(readings.join('  ·  '), style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
