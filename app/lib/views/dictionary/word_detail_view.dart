import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/enums.dart';
import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/word_detail_viewmodel.dart';
import '../feedback/report_item_sheet.dart';
import '../widgets/study_status_bar.dart';
import '../widgets/neo_pop.dart';
import '../widgets/speech_button.dart';
import '../widgets/status_views.dart';
import '../widgets/tappable_japanese.dart';

class WordDetailView extends StatelessWidget {
  const WordDetailView({super.key, required this.wordId});
  final int wordId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WordDetailViewModel(
          ctx.read<DictionaryRepository>(), ctx.read<StudyRepository>(), wordId)
        ..load(),
      child: const _WordDetail(),
    );
  }
}

class _WordDetail extends StatelessWidget {
  const _WordDetail();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WordDetailViewModel>();
    final lang = context.watch<AppState>().mnemonicLanguage;
    final word = vm.word;
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
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (word != null) ...[
                      NeoIconButton(
                        icon: Icons.content_copy_outlined,
                        label: context.trText('Capture source'),
                        onTap: () => _capture(context, word),
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
                child: vm.isLoading
                    ? const LoadingView()
                    : vm.hasError
                        ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                        : word == null
                            ? const SizedBox.shrink()
                            : _content(context, word, lang),
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

  Widget _content(BuildContext context, WordEntry word, String lang) {
    final jc = context.jc;
    final glossLanguage = word.glossLanguageFor(lang);
    final senses = word.sensesFor(lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        NeoCard(
          tone: NeoTone.magenta,
          shadow: 6,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              if (word.primaryReading.isNotEmpty &&
                  word.primaryReading != word.headword)
                TappableJapanese(word.primaryReading,
                    style: TextStyle(
                        fontSize: 16,
                        color: jc.ink,
                        fontWeight: FontWeight.w800)),
              TappableJapanese(word.headword,
                  affordance: false,
                  style: const TextStyle(
                      fontSize: 76, fontWeight: FontWeight.w900, height: 1.08)),
              const SizedBox(height: 4),
              SpeechButton(
                text: word.primaryReading.isNotEmpty
                    ? word.primaryReading
                    : word.headword,
                size: 25,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (word.isCommon)
                    NeoBadge(context.trText('common'), tone: NeoTone.lime),
                  if (word.jlpt != null)
                    NeoBadge('JLPT N${word.jlpt}', tone: NeoTone.acid),
                  if (_pitchOf(word).isNotEmpty)
                    NeoBadge(context.trText('pitch ${_pitchOf(word)}')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NeoSectionTitle(context.trText('Meanings')),
        NeoCard(
          child: Column(
            children: [
              for (final entry in senses.asMap().entries)
                _sense(context, entry.key + 1, entry.value, glossLanguage),
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
            _ExampleRow(example: example),
            const SizedBox(height: 10),
          ],
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
          Text(context.trText('$n.'),
              style: TextStyle(color: jc.muted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sense.pos.isNotEmpty)
                  Text(sense.pos.join(', '),
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: jc.muted)),
                Text(sense.glossesFor(lang).join('; '),
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  const _ExampleRow({required this.example});
  final ExampleItem example;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return NeoCard(
      tone: NeoTone.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TappableJapanese(example.japanese,
              style: const TextStyle(fontSize: 16, height: 1.4)),
          if (example.translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(example.translation,
                  style:
                      TextStyle(color: jc.muted, fontSize: 13.5, height: 1.35)),
            ),
        ],
      ),
    );
  }
}
