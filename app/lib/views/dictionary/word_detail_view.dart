import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
import '../../core/speech.dart';
import '../../models/enums.dart';
import '../../models/kanji.dart';
import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../routing/route_navigation.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../viewmodels/word_detail_viewmodel.dart';
import '../feedback/report_item_sheet.dart';
import '../auth/auth_required_sheet.dart';
import '../widgets/study_status_bar.dart';
import '../widgets/neo_pop.dart';
import '../widgets/speech_button.dart';
import '../widgets/status_views.dart';
import '../widgets/tappable_japanese.dart';
import '../widgets/content_language_notice.dart';

class WordDetailView extends StatelessWidget {
  const WordDetailView({super.key, required this.wordId});
  final int wordId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WordDetailViewModel(
          ctx.read<DictionaryRepository>(), ctx.read<StudyRepository>(), wordId,
          loadStudyState: ctx.read<AppState>().canStudy)
        ..load(),
      child: const _WordDetail(embedded: false),
    );
  }
}

class WordDetailPane extends StatelessWidget {
  const WordDetailPane({super.key, required this.wordId});

  final int wordId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        key: ValueKey(wordId),
        create: (ctx) => WordDetailViewModel(
          ctx.read<DictionaryRepository>(),
          ctx.read<StudyRepository>(),
          wordId,
          loadStudyState: ctx.read<AppState>().canStudy,
        )..load(),
        child: const _WordDetail(embedded: true),
      );
}

class _WordDetail extends StatelessWidget {
  const _WordDetail({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WordDetailViewModel>();
    final lang = context.watch<AppState>().mnemonicLanguage;
    final signedIn = context.read<AppState>().canStudy;
    final word = vm.word;
    final content = vm.isLoading
        ? const LoadingView()
        : vm.hasError
            ? ErrorRetry(message: vm.error!, onRetry: vm.load)
            : word == null
                ? const SizedBox.shrink()
                : _content(context, word, lang, vm);
    if (embedded) {
      return content;
    }
    return Scaffold(
      bottomNavigationBar: word == null
          ? null
          : StudyStatusBar(status: vm.status, onSetStatus: vm.setStatus),
      body: SafeArea(
        child: Column(
          children: [
            BoundedContent(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.arrow_back_rounded,
                      label: context.trText('Back'),
                      onTap: () => popOrGo(context),
                    ),
                    const Spacer(),
                    if (word != null) ...[
                      NeoIconButton(
                        icon: Icons.content_copy_outlined,
                        label: context.trText('Capture source'),
                        onTap: signedIn
                            ? () => _capture(context, word)
                            : () => showAuthRequiredSheet(
                                  context,
                                  title: context.trText('Capture a context'),
                                ),
                      ),
                      const SizedBox(width: 8),
                      ReportItemAction(
                        type: ReportItemType.word,
                        itemRef: '${word.id}',
                        label: word.headword,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: BoundedContent(
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capture(BuildContext context, WordEntry word) async {
    final captured = await showDialog<_CaptureResult>(
      context: context,
      builder: (_) => const _CaptureDialog(),
    );
    if (captured == null || !context.mounted) return;
    try {
      await context.read<StudyRepository>().addCard(
            ItemType.word,
            '${word.id}',
            sourceSentence: captured.sentence,
            sourceUrl: captured.url,
            sourceTitle: captured.title,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trText('Source captured'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Widget _content(
    BuildContext context,
    WordEntry word,
    String lang,
    WordDetailViewModel vm,
  ) {
    if (embedded) return _embeddedContent(context, word, lang, vm);
    final glossLanguage = word.glossLanguageFor(lang);
    final senses = word.sensesFor(lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (const {'upstream_not_in_snapshot', 'legacy_merged_entry'}
            .contains(word.provenance['source_status']))
          const _HistoricalWordNotice(),
        NeoCard(
          tone: NeoTone.magenta,
          shadow: 6,
          padding: const EdgeInsets.all(18),
          child: embedded
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _WordHeroGlyph(word: word),
                    const SizedBox(width: 26),
                    Flexible(
                      child: _WordHeroInfo(
                        word: word,
                        pitch: _pitchOf(word),
                        alignStart: true,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _WordHeroGlyph(word: word),
                    const SizedBox(height: 8),
                    _WordHeroInfo(
                      word: word,
                      pitch: _pitchOf(word),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        NeoSectionTitle(context.trText('Meanings')),
        if (glossLanguage != lang) _LanguageLabel(language: glossLanguage),
        NeoCard(
          child: Column(
            children: [
              for (final entry in senses.asMap().entries)
                _SenseRow(
                    number: entry.key + 1,
                    sense: entry.value,
                    language: glossLanguage),
            ],
          ),
        ),
        if (word.kanjiBreakdown.isNotEmpty) ...[
          const SizedBox(height: 22),
          NeoSectionTitle(context.trText('Kanji in this word')),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < word.kanjiBreakdown.length; i++)
                SizedBox(
                  width: context.isWide ? 210 : double.infinity,
                  child: _KanjiRow(
                    literal: word.kanjiBreakdown[i].literal,
                    meaning: word.kanjiBreakdown[i]
                        .meaningsFor(lang)
                        .take(3)
                        .join(', '),
                    readings: [
                      ...word.kanjiBreakdown[i].kunReadings,
                      ...word.kanjiBreakdown[i].onReadings
                    ].take(4).join('  '),
                    tone: [NeoTone.lime, NeoTone.acid, NeoTone.lavender][i % 3],
                    onTap: () => context
                        .push('/kanji/${word.kanjiBreakdown[i].literal}'),
                  ),
                ),
            ],
          ),
        ],
        if (word.examples.isNotEmpty) ...[
          const SizedBox(height: 22),
          NeoSectionTitle(context.trText('Examples')),
          for (final example in word.examples) ...[
            _ExampleRow(example: example, language: lang),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _embeddedContent(
    BuildContext context,
    WordEntry word,
    String lang,
    WordDetailViewModel vm,
  ) {
    final senses = word.sensesFor(lang);
    final signedIn = context.read<AppState>().canStudy;
    final primaryKanji =
        word.kanjiBreakdown.isEmpty ? null : word.kanjiBreakdown.first;
    final related = _relatedWords(
      primaryKanji?.words ?? const [],
      currentWordId: word.id,
    );
    return ListView(
      key: PageStorageKey('tablet-word-${word.id}'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      children: [
        if (const {'upstream_not_in_snapshot', 'legacy_merged_entry'}
            .contains(word.provenance['source_status']))
          const _HistoricalWordNotice(),
        NeoCard(
          tone: NeoTone.magenta,
          shadow: 6,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: _WordHeroGlyph(word: word),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: _TabletWordHeroInfo(word: word),
              ),
              const SizedBox(width: 12),
              NeoIconButton(
                icon: vm.status == 'learning'
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: _copy(
                  context,
                  vm.status == 'learning' ? 'Remove from deck' : 'Save word',
                  vm.status == 'learning'
                      ? 'Retirer du paquet'
                      : 'Enregistrer le mot',
                ),
                onTap: signedIn
                    ? () => vm.setStatus(
                          vm.status == 'learning' ? 'none' : 'learning',
                        )
                    : () => showAuthRequiredSheet(
                          context,
                          title: context.trText('Save this word'),
                        ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (word.glossLanguageFor(lang) != lang)
          _LanguageLabel(language: word.glossLanguageFor(lang)),
        _TabletSenses(senses: senses, language: word.glossLanguageFor(lang)),
        if (primaryKanji != null) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CompositionCard(
                  kanji: primaryKanji,
                  language: lang,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MemoryCard(kanji: primaryKanji, language: lang),
              ),
            ],
          ),
        ],
        if (word.examples.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final example in word.examples) ...[
            _ExampleRow(example: example, language: lang),
            const SizedBox(height: 10),
          ],
        ],
        if (related.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            _copy(context, 'SEE ALSO', 'VOIR AUSSI'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final relatedWord in related.take(4))
                _RelatedWordButton(
                  word: relatedWord,
                  onTap: () =>
                      context.read<SearchViewModel>().selectWord(relatedWord),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        NeoPrimaryButton(
          label: _copy(
            context,
            vm.status == 'none' ? 'Add to my deck' : 'Remove from my deck',
            vm.status == 'none' ? 'Ajouter au paquet' : 'Retirer du paquet',
          ),
          icon: vm.status == 'none' ? Icons.add_rounded : Icons.remove_rounded,
          onTap: signedIn
              ? () => vm.setStatus(
                    vm.status == 'none' ? 'learning' : 'none',
                  )
              : () => showAuthRequiredSheet(
                    context,
                    title: context.trText('Save this word'),
                  ),
        ),
      ],
    );
  }

  List<WordEntry> _relatedWords(
    List<dynamic> raw, {
    required int currentWordId,
  }) {
    final words = <WordEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final word = WordEntry.fromJson(item.cast<String, dynamic>());
        if (word.id != currentWordId && word.headword.isNotEmpty) {
          words.add(word);
        }
      } catch (_) {
        // Related rows are optional enrichment. A partial local pack must not
        // prevent the main dictionary entry from rendering.
      }
    }
    return words;
  }

  /// Only attach a pitch pattern to the reading it describes.
  String _pitchOf(WordEntry word) {
    for (final r in word.readings) {
      if (r.text == word.primaryReading && r.pitch.isNotEmpty) return r.pitch;
    }
    return '';
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
            context.trText('Content language: {language}').replaceAll(
                '{language}',
                switch (language) {
                  'en' => context.trText('English'),
                  'fr' => context.trText('French'),
                  _ => mnemonicLanguageName(language),
                }),
            style: TextStyle(color: context.jc.muted, fontSize: 12)),
      );
}

class _HistoricalWordNotice extends StatelessWidget {
  const _HistoricalWordNotice();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
            context.trText(
                'This historical entry is absent from the current source snapshot. It remains available for your saved cards.'),
            style: TextStyle(color: context.jc.muted, fontSize: 13)),
      );
}

class _SenseRow extends StatelessWidget {
  const _SenseRow(
      {required this.number, required this.sense, required this.language});
  final int number;
  final Sense sense;
  final String language;

  @override
  Widget build(BuildContext context) {
    final notes =
        sense.notes.where((note) => note.language == language).toList();
    final displayedNotes = notes.isNotEmpty
        ? notes
        : sense.notes.where((note) => note.language == 'en').toList();
    final restrictions = <(String, List<String>)>[
      ('Usage', sense.misc),
      ('Field', sense.field),
      for (final (key, label) in const [
        ('restricted_kanji', 'Used with these spellings'),
        ('restricted_readings', 'Used with these readings'),
        ('dialects', 'Dialect'),
        ('references', 'Related entries'),
      ])
        (
          label,
          (sense.metadata[key] as List? ?? const [])
              .whereType<String>()
              .toList()
        ),
    ];
    return Padding(
      key: ValueKey('word-sense-$number'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$number.',
            style: TextStyle(
                color: context.jc.muted, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (sense.pos.isNotEmpty)
            Text(sense.pos.join(', '),
                style: TextStyle(fontSize: 12, color: context.jc.muted)),
          Text(sense.exactGlossesFor(language).join('; '),
              style: const TextStyle(fontSize: 16)),
          for (final (label, values) in restrictions)
            if (values.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    context
                        .trText('{label}: {values}')
                        .replaceAll('{label}', context.trText(label))
                        .replaceAll('{values}', values.join(', ')),
                    style: TextStyle(fontSize: 12, color: context.jc.muted)),
              ),
          for (final note in displayedNotes) ...[
            const SizedBox(height: 5),
            if (note.language != language)
              _LanguageLabel(language: note.language),
            Text(note.text,
                style: TextStyle(fontSize: 13, color: context.jc.body)),
          ],
        ])),
      ]),
    );
  }
}

class _WordHeroGlyph extends StatelessWidget {
  const _WordHeroGlyph({required this.word});

  final WordEntry word;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (word.primaryReading.isNotEmpty &&
              word.primaryReading != word.headword)
            TappableJapanese(
              word.primaryReading,
              style: TextStyle(
                fontSize: 16,
                color: context.jc.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TappableJapanese(
                word.headword,
                affordance: false,
                style: const TextStyle(
                  fontSize: 86,
                  fontWeight: FontWeight.w900,
                  height: 1.04,
                ),
              ),
            ),
          ),
        ],
      );
}

class _WordHeroInfo extends StatelessWidget {
  const _WordHeroInfo({
    required this.word,
    required this.pitch,
    this.alignStart = false,
  });

  final WordEntry word;
  final String pitch;
  final bool alignStart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SpeechButton(
            text: word.primaryReading.isNotEmpty
                ? word.primaryReading
                : word.headword,
            size: 25,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: alignStart ? WrapAlignment.start : WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (word.isCommon)
                NeoBadge(context.trText('common'), tone: NeoTone.lime),
              if (word.jlpt != null)
                NeoBadge('JLPT N${word.jlpt}', tone: NeoTone.acid),
              if (pitch.isNotEmpty) NeoBadge(context.trText('pitch $pitch')),
            ],
          ),
        ],
      );
}

class _TabletWordHeroInfo extends StatelessWidget {
  const _TabletWordHeroInfo({required this.word});

  final WordEntry word;

  @override
  Widget build(BuildContext context) {
    final partsOfSpeech = word.senses
        .expand((sense) => sense.pos)
        .where((part) => part.trim().isNotEmpty)
        .toSet()
        .take(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: NeoCard(
            tone: NeoTone.acid,
            shadow: 3,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            semanticLabel: _copy(context, 'Play audio', 'Écouter'),
            onTap: () {
              Haptics.tick();
              Speech.instance.say(
                word.primaryReading.isEmpty
                    ? word.headword
                    : word.primaryReading,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up_rounded, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    word.primaryReading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final part in partsOfSpeech) _FlatWordTag(part),
            if (word.jlpt != null) _FlatWordTag('JLPT N${word.jlpt}'),
            if (word.isCommon)
              _FlatWordTag(_copy(context, 'Frequent', 'Fréquent')),
          ],
        ),
      ],
    );
  }
}

class _FlatWordTag extends StatelessWidget {
  const _FlatWordTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.jc.surface.withValues(alpha: 0.78),
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TabletSenses extends StatelessWidget {
  const _TabletSenses({required this.senses, required this.language});

  final List<Sense> senses;
  final String language;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TabletLabel(_copy(context, 'MEANINGS', 'SENS')),
            const SizedBox(height: 7),
            for (final entry in senses.asMap().entries)
              _SenseRow(
                  number: entry.key + 1,
                  sense: entry.value,
                  language: language),
          ],
        ),
      );
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({required this.kanji, required this.language});

  final KanjiEntry kanji;
  final String language;

  @override
  Widget build(BuildContext context) {
    final detailed = kanji.componentDetails.take(3).toList();
    final literals = detailed.isEmpty
        ? kanji.components.take(3).toList()
        : detailed.map((component) => component.literal).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.jc.surface,
        border: Border.all(color: context.jc.ink, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabletLabel(
            _copy(context, 'INSIDE THE KANJI', 'DANS LE KANJI'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (literals.isEmpty)
                _ComponentPart(
                  glyph: kanji.literal,
                  label: kanji.meaningsFor(language).take(1).join(),
                  tone: NeoTone.lime,
                )
              else
                for (var index = 0; index < literals.length; index++) ...[
                  if (index > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Flexible(
                    child: _ComponentPart(
                      glyph: literals[index],
                      label: detailed.isEmpty ? '' : detailed[index].meaning,
                      tone: [
                        NeoTone.lime,
                        NeoTone.acid,
                        NeoTone.lavender,
                      ][index % 3],
                    ),
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ComponentPart extends StatelessWidget {
  const _ComponentPart({
    required this.glyph,
    required this.label,
    required this.tone,
  });

  final String glyph;
  final String label;
  final NeoTone tone;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: tone.color(context),
              border: Border.all(color: context.jc.ink, width: 2.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                glyph,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.jc.body,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.kanji, required this.language});

  final KanjiEntry kanji;
  final String language;

  @override
  Widget build(BuildContext context) {
    final hasOrigin = kanji.origin.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      decoration: BoxDecoration(
        color: context.jc.surface,
        border: Border.all(color: context.jc.ink, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabletLabel(
            context.trText(hasOrigin ? 'Origin' : 'Suggested study strategy'),
          ),
          const SizedBox(height: 8),
          if (hasOrigin) ContentLanguageNotice(language: kanji.originLanguage),
          Text(
            hasOrigin
                ? kanji.origin.trim()
                : context.trText(
                    'Look at the character and choose an image that helps you recall its meaning.'),
            style: TextStyle(
              color: context.jc.body,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedWordButton extends StatelessWidget {
  const _RelatedWordButton({required this.word, required this.onTap});

  final WordEntry word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: NeoCard(
          shadow: 0,
          radius: 9,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          semanticLabel: word.headword,
          onTap: onTap,
          child: Center(
            child: Text(
              word.headword,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
}

class _TabletLabel extends StatelessWidget {
  const _TabletLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: context.jc.ink,
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      );
}

class _CaptureResult {
  const _CaptureResult(this.sentence, this.url, this.title);
  final String sentence;
  final String url;
  final String title;
}

class _CaptureDialog extends StatefulWidget {
  const _CaptureDialog();

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  final _sentence = TextEditingController();
  final _url = TextEditingController();
  final _title = TextEditingController();

  @override
  void dispose() {
    _sentence.dispose();
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.trim().isNotEmpty == true) {
      _sentence.text = data!.text!.trim();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCapture = _sentence.text.trim().isNotEmpty;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: NeoCard(
          shadow: 6,
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.trText('Capture reading context'),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    NeoIconButton(
                      icon: Icons.close_rounded,
                      label: context.trText('Close'),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sentence,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.trText('Source sentence'),
                    hintText:
                        context.trText('Paste the sentence from your reader'),
                    suffixIcon: IconButton(
                      tooltip: context.trText('Paste'),
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: context.trText('Source title'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.trText('Source URL'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CaptureDialogButton(
                        label: context.trText('Cancel'),
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CaptureDialogButton(
                        label: context.trText('Capture'),
                        tone: NeoTone.blue,
                        enabled: canCapture,
                        onTap: () => Navigator.pop(
                          context,
                          _CaptureResult(
                            _sentence.text.trim(),
                            _url.text.trim(),
                            _title.text.trim(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureDialogButton extends StatelessWidget {
  const _CaptureDialogButton({
    required this.label,
    required this.onTap,
    this.tone = NeoTone.paper,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final NeoTone tone;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          height: 50,
          child: NeoCard(
            tone: tone,
            shadow: enabled ? 3 : 0,
            radius: 10,
            padding: EdgeInsets.zero,
            onTap: enabled ? onTap : null,
            semanticLabel: label,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
}

/// A flat, hairline-separated kanji row (IG-style list item, no Material Card).
class _KanjiRow extends StatelessWidget {
  const _KanjiRow(
      {required this.literal,
      required this.meaning,
      required this.readings,
      required this.tone,
      required this.onTap});
  final String literal;
  final String meaning;
  final String readings;
  final NeoTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return NeoCard(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(literal,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (readings.isNotEmpty)
                  Text(readings,
                      style: TextStyle(color: jc.muted, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: jc.muted),
        ],
      ),
    );
  }
}

/// A Tanaka-corpus example: Japanese sentence over its English translation.
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example, required this.language});
  final ExampleItem example;
  final String language;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final translation = example.translationFor(language);
    final actualLanguage = example.translations.isEmpty
        ? example.language
        : example.translations.any((item) => item.language == language)
            ? language
            : 'en';
    return NeoCard(
      tone: NeoTone.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TappableJapanese(example.japanese,
              style: const TextStyle(fontSize: 16, height: 1.4)),
          if (translation.isNotEmpty && actualLanguage != language)
            _LanguageLabel(language: actualLanguage),
          if (translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(translation,
                  style:
                      TextStyle(color: jc.muted, fontSize: 13.5, height: 1.35)),
            ),
        ],
      ),
    );
  }
}

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
