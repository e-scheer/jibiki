import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/enums.dart';
import '../../models/kana.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_viewmodel.dart';
import '../feedback/report_item_sheet.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/mnemonic_panel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/origin_section.dart';
import '../widgets/pressable.dart';
import '../widgets/speech_button.dart';
import '../widgets/study_mark.dart';
import 'kana_cell.dart';

class KanaDetailView extends StatelessWidget {
  const KanaDetailView({super.key, required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    final language = context.read<AppState>().mnemonicLanguage;
    return ChangeNotifierProvider(
      create: (ctx) => MnemonicViewModel(
        ctx.read<MnemonicRepository>(),
        ctx.read<StudyRepository>(),
        character: char,
        kind: 'kana',
        language: language,
      )..load(),
      child: _KanaDetail(char: char),
    );
  }
}

typedef _KanaDetailData = ({
  KanaEntry focused,
  KanaEntry? counterpart,
  List<KanaEntry> nearby,
  Map<String, int> states,
  Set<String> dueChars,
});

class _KanaDetail extends StatefulWidget {
  const _KanaDetail({required this.char});

  final String char;

  @override
  State<_KanaDetail> createState() => _KanaDetailState();
}

class _KanaDetailState extends State<_KanaDetail> {
  late final Future<_KanaDetailData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_KanaDetailData> _load() async {
    final dictionary = context.read<DictionaryRepository>();
    final study = context.read<StudyRepository>();
    final focusedFuture = dictionary.kanaDetail(widget.char);
    final allFuture = dictionary.kana();
    final focused = await focusedFuture;
    final all = await allFuture;

    final otherScript = focused.isHiragana ? 'katakana' : 'hiragana';
    KanaEntry? counterpart;
    for (final kana in all) {
      if (kana.script == otherScript &&
          kana.romaji == focused.romaji &&
          kana.kind == focused.kind) {
        counterpart = kana;
        break;
      }
    }

    final candidates = all
        .where(
          (kana) =>
              kana.script == focused.script &&
              kana.char != focused.char &&
              kana.kind == focused.kind,
        )
        .toList();
    candidates.sort((a, b) {
      int score(KanaEntry kana) {
        var value = (kana.order - focused.order).abs();
        if (kana.row == focused.row) value -= 20;
        if (kana.romaji.endsWith(focused.romaji.characters.last)) value -= 8;
        return value;
      }

      return score(a).compareTo(score(b));
    });

    var states = <String, int>{};
    var dueChars = <String>{};
    try {
      final statesFuture = study.studyStates(type: ItemType.kana);
      final cardsFuture = study.cards(type: ItemType.kana);
      states = await statesFuture;
      final cards = await cardsFuture;
      final now = DateTime.now();
      dueChars = {
        for (final card in cards)
          if (!card.isNew && !card.due.isAfter(now)) card.itemRef,
      };
    } catch (_) {
      // Reference content is useful even when personal study data is offline.
    }

    return (
      focused: focused,
      counterpart: counterpart,
      nearby: candidates.take(3).toList(growable: false),
      states: states,
      dueChars: dueChars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.watch<MnemonicViewModel>();
    return Scaffold(
      bottomNavigationBar: FutureBuilder<_KanaDetailData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();
          return _DetailActions(
            kana: data.focused,
            added: mnemonic.added,
            onAdd: () => _addToStudy(context, mnemonic),
          );
        },
      ),
      body: SafeArea(
        child: BoundedContent(
          maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
          child: FutureBuilder<_KanaDetailData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _DetailError(onRetry: () => context.pop());
              }
              final data = snapshot.data;
              if (data == null) return _DetailSkeleton(char: widget.char);
              return _DetailContent(data: data);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addToStudy(
    BuildContext context,
    MnemonicViewModel mnemonic,
  ) async {
    final added = await mnemonic.addToStudy();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? _copy(
                  context, 'Added to your study deck', 'Ajouté à vos révisions')
              : mnemonic.error ?? _copy(context, 'Failed', 'Échec'),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.data});

  final _KanaDetailData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 760;
        final main = Column(
          children: [
            _KanaHero(data: data),
            const SizedBox(height: 20),
            _WritingGuide(kana: data.focused),
            const SizedBox(height: 18),
            _NearbyKana(data: data),
          ],
        );
        final supporting = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.focused.hasUsage) ...[
              KanaGrammarSection(kana: data.focused),
              const SizedBox(height: 18),
            ],
            if (data.focused.hasOrigin) ...[
              KanaOriginSection(kana: data.focused),
              const SizedBox(height: 18),
            ],
            const _FeaturedMnemonic(),
          ],
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            tablet ? 24 : 16,
            12,
            tablet ? 24 : 16,
            28,
          ),
          children: [
            _DetailTopBar(data: data),
            const SizedBox(height: 12),
            if (tablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 390, child: main),
                  const SizedBox(width: 28),
                  Expanded(child: supporting),
                ],
              )
            else ...[
              main,
              const SizedBox(height: 20),
              supporting,
            ],
          ],
        );
      },
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.data});

  final _KanaDetailData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NeoIconButton(
          icon: Icons.chevron_left_rounded,
          label: _copy(context, 'Back to the chart', 'Retour à la matrice'),
          onTap: () => context.pop(),
        ),
        const Spacer(),
        _Tag(label: data.focused.isHiragana ? 'Hiragana' : 'Katakana'),
        const SizedBox(width: 6),
        ReportItemAction(
          type: ReportItemType.kana,
          itemRef: data.focused.char,
          label: data.focused.char,
        ),
      ],
    );
  }
}

class _KanaHero extends StatelessWidget {
  const _KanaHero({required this.data});

  final _KanaDetailData data;

  @override
  Widget build(BuildContext context) {
    final kana = data.focused;
    return NeoCard(
      tone: NeoTone.lime,
      shadow: 6,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          Text(
            kana.char,
            style: const TextStyle(
              fontFamily: 'NotoSansJP',
              fontSize: 104,
              height: 1.02,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: context.jc.surface,
              border: Border.all(color: context.jc.ink, width: 2.5),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: context.jc.ink,
                  blurRadius: 0,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpeechButton(text: kana.char, size: 18, color: context.jc.ink),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    kana.romaji,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 7,
            children: [
              _Tag(label: _kindLabel(context, kana.kind, kana.row)),
              _Tag(
                label: _copy(
                  context,
                  '${kana.row.toUpperCase()} row',
                  'Rangée ${kana.row.toUpperCase()}',
                ),
              ),
              if (data.counterpart != null) _TwinTag(kana: data.counterpart!),
            ],
          ),
        ],
      ),
    );
  }
}

class _WritingGuide extends StatelessWidget {
  const _WritingGuide({required this.kana});

  final KanaEntry kana;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _copy(context, 'Writing gesture', 'Geste d’écriture'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                color: context.jc.surface,
                border: Border.all(color: context.jc.ink, width: 3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WritingGridPainter(color: context.jc.muted),
                    ),
                  ),
                  Center(
                    child: Text(
                      kana.char,
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 105,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: context.jc.ink,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: context.jc.magenta,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.jc.ink, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Tag(
                    label: _copy(context, 'Trace it', 'À tracer'),
                    color: context.jc.magenta,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _copy(
                      context,
                      'Keep the shape centred and use the guide as your frame.',
                      'Gardez la forme centrée et utilisez le quadrillage comme repère.',
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _copy(
                      context,
                      'Practise slowly first, then write from memory.',
                      'Tracez lentement, puis recommencez de mémoire.',
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WritingGridPainter extends CustomPainter {
  const _WritingGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    _dashedLine(
      canvas,
      Offset(size.width / 2, 8),
      Offset(size.width / 2, size.height - 8),
      paint,
    );
    _dashedLine(
      canvas,
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      paint,
    );
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vertical = start.dx == end.dx;
    final length = vertical ? end.dy - start.dy : end.dx - start.dx;
    for (var offset = 0.0; offset < length; offset += 12) {
      final dashEnd = (offset + 6).clamp(0, length);
      canvas.drawLine(
        vertical
            ? Offset(start.dx, start.dy + offset)
            : Offset(start.dx + offset, start.dy),
        vertical
            ? Offset(start.dx, start.dy + dashEnd)
            : Offset(start.dx + dashEnd, start.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WritingGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FeaturedMnemonic extends StatelessWidget {
  const _FeaturedMnemonic();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MnemonicViewModel>();
    final mnemonic = vm.items.isEmpty ? null : vm.items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _copy(context, 'Community mnemonic', 'Mnémo de la communauté'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        NeoCard(
          tone: NeoTone.blue,
          shadow: 4,
          radius: 12,
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
          child: vm.isLoading && mnemonic == null
              ? const SizedBox(
                  height: 68,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : mnemonic == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _copy(
                            context,
                            'No mnemonic yet. Yours can be the first.',
                            'Pas encore de mnémo. Le vôtre peut être le premier.',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AllMnemonicsButton(
                          label: _copy(context, 'Create one', 'En créer un'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '« ${mnemonic.story} »',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _copy(
                                  context,
                                  'by ${mnemonic.authorName}',
                                  'par ${mnemonic.authorName}',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Pressable(
                              label: _copy(context, 'Vote', 'Voter'),
                              selected: mnemonic.liked,
                              onTap: mnemonic.isVisible
                                  ? () => vm.vote(mnemonic, 1)
                                  : null,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: context.jc.acid,
                                  border: Border.all(
                                    color: context.jc.ink,
                                    width: 2.5,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.jc.ink,
                                      blurRadius: 0,
                                      offset: const Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mnemonic.liked
                                          ? Icons.favorite_rounded
                                          : Icons.arrow_drop_up_rounded,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${mnemonic.score}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
        ),
        if (mnemonic != null) ...[
          const SizedBox(height: 12),
          _AllMnemonicsButton(
            label: _copy(context, 'See all mnemonics', 'Voir tous les mnémos'),
          ),
        ],
      ],
    );
  }
}

class _AllMnemonicsButton extends StatelessWidget {
  const _AllMnemonicsButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => _showAllMnemonics(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllMnemonics(BuildContext context) {
    final vm = context.read<MnemonicViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.jc.canvas,
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: vm,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: const MnemonicPanel(),
          ),
        ),
      ),
    );
  }
}

class _NearbyKana extends StatelessWidget {
  const _NearbyKana({required this.data});

  final _KanaDetailData data;

  @override
  Widget build(BuildContext context) {
    if (data.nearby.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _copy(context, 'Nearby kana', 'Kana proches'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var i = 0; i < data.nearby.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: KanaCell(
                  entries: [data.nearby[i]],
                  selected: false,
                  mark: studyMarkFor(data.states[data.nearby[i].char]),
                  due: data.dueChars.contains(data.nearby[i].char),
                  onTap: () => context.push('/kana/${data.nearby[i].char}'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TwinTag extends StatelessWidget {
  const _TwinTag({required this.kana});

  final KanaEntry kana;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: '${kana.char} ${kana.isHiragana ? 'Hiragana' : 'Katakana'}',
      onTap: () => context.push('/kana/${kana.char}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kana.char,
              style: const TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              kana.isHiragana ? 'Hiragana' : 'Katakana',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 31),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? context.jc.surface,
        border: Border.all(color: context.jc.ink, width: 2.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 12, height: 1, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.kana,
    required this.added,
    required this.onAdd,
  });

  final KanaEntry kana;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.jc.surface,
        border: Border(top: BorderSide(color: context.jc.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: NeoPrimaryButton(
                  label:
                      _copy(context, 'Practise writing', 'Pratiquer le tracé'),
                  icon: Icons.gesture_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _KanaWritingPracticePage(kana: kana),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NeoIconButton(
                icon: added ? Icons.check_rounded : Icons.add_rounded,
                label: added
                    ? _copy(context, 'In your deck', 'Dans vos révisions')
                    : _copy(context, 'Add to study', 'Ajouter aux révisions'),
                onTap: added ? () {} : onAdd,
                tone: added ? NeoTone.lime : NeoTone.paper,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanaWritingPracticePage extends StatefulWidget {
  const _KanaWritingPracticePage({required this.kana});

  final KanaEntry kana;

  @override
  State<_KanaWritingPracticePage> createState() =>
      _KanaWritingPracticePageState();
}

class _KanaWritingPracticePageState extends State<_KanaWritingPracticePage> {
  final DrawingController _controller = DrawingController();
  bool _showGuide = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kana = widget.kana;
    return Scaffold(
      backgroundColor: context.jc.lavender,
      body: SafeArea(
        child: BoundedContent(
          maxWidth: context.isExpanded ? 760 : Breakpoints.maxContent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _copy(context, 'Writing', 'Tracé'),
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _copy(
                              context,
                              'Trace slowly, then hide the guide.',
                              'Tracez lentement, puis masquez le guide.',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    NeoIconButton(
                      icon: Icons.close_rounded,
                      label: _copy(context, 'Close', 'Fermer'),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NeoCard(
                  tone: NeoTone.acid,
                  shadow: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kana.isHiragana ? 'Hiragana' : 'Katakana',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              kana.romaji,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        kana.char,
                        style: const TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: 48,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: NeoCard(
                          shadow: 8,
                          radius: 16,
                          padding: EdgeInsets.zero,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DrawingCanvas(controller: _controller),
                              ),
                              if (_showGuide)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Text(
                                        kana.char,
                                        style: TextStyle(
                                          fontFamily: 'NotoSansJP',
                                          fontSize: 190,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          color: context.jc.ink.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PracticeTool(
                        icon: Icons.undo_rounded,
                        label: _copy(context, 'Undo', 'Annuler'),
                        onTap: _controller.undo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PracticeTool(
                        icon: Icons.layers_clear_outlined,
                        label: _copy(context, 'Clear', 'Effacer'),
                        onTap: _controller.clear,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PracticeTool(
                        icon: _showGuide
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        label: _copy(context, 'Guide', 'Guide'),
                        selected: _showGuide,
                        onTap: () => setState(() => _showGuide = !_showGuide),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NeoPrimaryButton(
                  label: _copy(context, 'Done', 'Terminé'),
                  icon: Icons.check_rounded,
                  tone: NeoTone.ink,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeTool extends StatelessWidget {
  const _PracticeTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      selected: selected,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? context.jc.acid : context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            NeoIconButton(
              icon: Icons.chevron_left_rounded,
              label: _copy(context, 'Back', 'Retour'),
              onTap: () => context.pop(),
            ),
            const Spacer(),
            const _Tag(label: 'Kana'),
          ],
        ),
        const SizedBox(height: 12),
        NeoCard(
          tone: NeoTone.lime,
          shadow: 6,
          child: SizedBox(
            height: 190,
            child: Center(
              child: Text(
                char,
                style: TextStyle(
                  fontFamily: 'NotoSansJP',
                  fontSize: 104,
                  fontWeight: FontWeight.w900,
                  color: context.jc.ink.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeoCard(
          tone: NeoTone.coral,
          shadow: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 34),
              const SizedBox(height: 10),
              Text(
                _copy(
                  context,
                  'This kana could not be loaded.',
                  'Ce kana n’a pas pu être chargé.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              NeoPrimaryButton(
                label: _copy(context, 'Go back', 'Revenir'),
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _kindLabel(BuildContext context, String kind, String row) {
  if (kind == 'dakuten') return 'Dakuten';
  if (kind == 'handakuten') return 'Handakuten';
  if (kind == 'yoon') return 'Yōon';
  if (row == 'a') return _copy(context, 'Vowel', 'Voyelle');
  return _copy(context, 'Basic kana', 'Kana de base');
}

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
