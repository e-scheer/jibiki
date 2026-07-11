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
    final lang = context.read<AppState>().mnemonicLanguage;
    final word = vm.word;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trText('Word')),
        actions: word == null
            ? null
            : [
                IconButton(
                  tooltip: context.trText('Capture source'),
                  icon: const Icon(Icons.content_copy_outlined),
                  onPressed: () => _capture(context, word),
                ),
                ReportItemAction(
                    type: ReportItemType.word,
                    itemRef: '${word.id}',
                    label: word.headword),
              ],
      ),
      bottomNavigationBar: word == null
          ? null
          : StudyStatusBar(status: vm.status, onSetStatus: vm.setStatus),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TappableJapanese(word.headword,
                  affordance: false,
                  style: const TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w600, height: 1.1)),
            ),
            SpeechButton(
              text: word.primaryReading.isNotEmpty
                  ? word.primaryReading
                  : word.headword,
              size: 28,
            ),
          ],
        ),
        if (word.primaryReading.isNotEmpty &&
            word.primaryReading != word.headword)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TappableJapanese(word.primaryReading,
                    style: TextStyle(fontSize: 20, color: jc.muted)),
                if (_pitchOf(word).isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: jc.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text(context.trText('pitch ${_pitchOf(word)}'),
                        style: TextStyle(
                            fontSize: 11.5,
                            color: jc.body,
                            fontWeight: FontWeight.w600)),
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
        Text(context.trText('Meanings'), style: context.text.titleMedium),
        const SizedBox(height: 8),
        ...word.senses
            .asMap()
            .entries
            .map((e) => _sense(context, e.key + 1, e.value, lang)),
        if (word.kanjiBreakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.trText('Kanji in this word'),
              style: context.text.titleMedium),
          const SizedBox(height: 8),
          ...word.kanjiBreakdown.map((k) => _KanjiRow(
                literal: k.literal,
                meaning: k.meaningsFor(lang).take(3).join(', '),
                readings:
                    [...k.kunReadings, ...k.onReadings].take(4).join('  '),
                onTap: () => context.push('/kanji/${k.literal}'),
              )),
        ],
        if (word.examples.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.trText('Examples'), style: context.text.titleMedium),
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
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.trText('Capture reading context')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: context.trText('Source title'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.trText('Source URL'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.trText('Cancel')),
          ),
          FilledButton(
            onPressed: _sentence.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _CaptureResult(
                        _sentence.text.trim(),
                        _url.text.trim(),
                        _title.text.trim(),
                      ),
                    ),
            child: Text(context.trText('Capture')),
          ),
        ],
      );
}

/// A flat, hairline-separated kanji row (IG-style list item, no Material Card).
class _KanjiRow extends StatelessWidget {
  const _KanjiRow(
      {required this.literal,
      required this.meaning,
      required this.readings,
      required this.onTap});
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
