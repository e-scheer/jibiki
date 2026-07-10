import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/kana.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_viewmodel.dart';
import '../feedback/report_item_sheet.dart';
import '../widgets/add_to_study_bar.dart';
import '../widgets/mnemonic_panel.dart';
import '../widgets/origin_section.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';

/// A single kana, shown alongside its counterpart in the other script (あ ↔ ア):
/// both glyphs at the top, then the focused one's writing origin and its community
/// mnemonics in the chosen language, plus "add to study". Tap the counterpart to
/// jump to its own page.
class KanaDetailView extends StatelessWidget {
  const KanaDetailView({super.key, required this.char});
  final String char;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppState>().mnemonicLanguage;
    return ChangeNotifierProvider(
      create: (ctx) => MnemonicViewModel(
        ctx.read<MnemonicRepository>(),
        ctx.read<StudyRepository>(),
        character: char,
        kind: 'kana',
        language: lang,
      )..load(),
      child: _KanaDetail(char: char),
    );
  }
}

/// The focused kana plus its cross-script pair (null if it has no counterpart).
typedef _KanaPair = ({KanaEntry focused, KanaEntry? counterpart});

class _KanaDetail extends StatefulWidget {
  const _KanaDetail({required this.char});
  final String char;

  @override
  State<_KanaDetail> createState() => _KanaDetailState();
}

class _KanaDetailState extends State<_KanaDetail> {
  late final Future<_KanaPair> _pair;

  @override
  void initState() {
    super.initState();
    _pair = _load();
  }

  /// The reference row + its cross-script twin (same sound + kind, other script),
  /// both drawn from the repository's memoized chart, so this is a one-time fetch.
  Future<_KanaPair> _load() async {
    final repo = context.read<DictionaryRepository>();
    final focused = await repo.kanaDetail(widget.char);
    final all = await repo.kana();
    final otherScript = focused.isHiragana ? 'katakana' : 'hiragana';
    KanaEntry? twin;
    for (final k in all) {
      if (k.script == otherScript && k.romaji == focused.romaji && k.kind == focused.kind) {
        twin = k;
        break;
      }
    }
    return (focused: focused, counterpart: twin);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MnemonicViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Kana · ${widget.char}'),
        actions: [
          FutureBuilder<_KanaPair>(
            future: _pair,
            builder: (context, snap) {
              final twin = snap.data?.counterpart;
              if (twin == null) return const SizedBox.shrink();
              return _EquivalentAction(twin: twin);
            },
          ),
          ReportItemAction(
              type: ReportItemType.kana, itemRef: widget.char, label: widget.char),
        ],
      ),
      bottomNavigationBar: AddToStudyBar(
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          FutureBuilder<_KanaPair>(
            future: _pair,
            builder: (context, snap) {
              final data = snap.data;
              // Until the pair resolves, show the focused glyph on its own so the
              // page never flashes empty.
              if (data == null) {
                return _SoloGlyph(char: widget.char);
              }
              return _PairHeader(pair: data);
            },
          ),
          const SizedBox(height: 22),
          const MnemonicPanel(),
        ],
      ),
    );
  }
}

/// The focused glyph alone (loading fallback, or a kana with no counterpart).
class _SoloGlyph extends StatelessWidget {
  const _SoloGlyph({required this.char});
  final String char;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(char, style: const TextStyle(fontSize: 116, fontWeight: FontWeight.w600, height: 1.1)),
    );
  }
}

/// One elegant glyph, its romaji, and a small pill to jump to the other script's
/// equivalent (あ ↔ ア) - the counterpart is a quiet link, never a second big
/// glyph. The side-by-side pair lives in the chart's "Both" view.
class _PairHeader extends StatelessWidget {
  const _PairHeader({required this.pair});
  final _KanaPair pair;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final focused = pair.focused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(focused.char,
              style: const TextStyle(
                  fontFamily: 'NotoSansJP', fontSize: 116, fontWeight: FontWeight.w600, height: 1.1)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(focused.romaji,
                  style: TextStyle(fontSize: 18, color: jc.muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              SpeechButton(text: focused.char),
            ],
          ),
        ),
        if (focused.hasUsage) ...[
          const SizedBox(height: 22),
          KanaGrammarSection(kana: focused),
        ],
        if (focused.hasOrigin) ...[
          const SizedBox(height: 22),
          KanaOriginSection(kana: focused),
        ],
      ],
    );
  }
}

String _scriptLabel(KanaEntry k) => k.isHiragana ? 'Hiragana' : 'Katakana';

/// A compact app-bar action linking to the cross-script twin: its small glyph +
/// the short script name (あ Hiragana / ア Katakana). Tap navigates to that kana.
class _EquivalentAction extends StatelessWidget {
  const _EquivalentAction({required this.twin});
  final KanaEntry twin;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        label: 'See ${_scriptLabel(twin)} ${twin.char}',
        onTap: () => context.push('/kana/${twin.char}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(twin.char,
                  style: TextStyle(fontFamily: 'NotoSansJP', fontSize: 16, fontWeight: FontWeight.w700, color: jc.ink)),
              const SizedBox(width: 5),
              Text(_scriptLabel(twin),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: jc.body)),
            ],
          ),
        ),
      ),
    );
  }
}
