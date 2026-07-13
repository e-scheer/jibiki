import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/api_exception.dart';
import '../../core/speech.dart';
import '../../data/kana_strokes.dart';
import '../../models/enums.dart';
import '../../models/kana.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/mnemonic_viewmodel.dart';
import '../auth/auth_required_sheet.dart';
import '../feedback/report_item_sheet.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/mnemonic_panel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/origin_section.dart';
import '../widgets/pressable.dart';
import '../widgets/study_mark.dart';
import '../widgets/stroke_order_view.dart';
import 'kana_cell.dart';

class KanaDetailView extends StatelessWidget {
  const KanaDetailView({
    super.key,
    required this.char,
    this.showBoth = false,
  });

  final String char;
  final bool showBoth;

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
      child: _KanaDetail(char: char, showBoth: showBoth),
    );
  }
}

/// Detail surface used by the NeoPop 16 tablet matrix. It deliberately has no
/// Scaffold or route chrome so the matrix remains visible while focus changes.
class KanaDetailPane extends StatelessWidget {
  const KanaDetailPane({
    super.key,
    required this.char,
    this.showBoth = false,
    this.onSelectKana,
  });

  final String char;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

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
      child: _KanaDetail(
        char: char,
        embedded: true,
        showBoth: showBoth,
        onSelectKana: onSelectKana,
      ),
    );
  }
}

typedef _KanaDetailData = ({
  KanaEntry focused,
  KanaEntry? counterpart,
  KanaStrokeData? stroke,
  KanaStrokeData? counterpartStroke,
  List<KanaEntry> nearby,
  Map<String, int> states,
  Set<String> dueChars,
});

/// A character and the stroke data that belongs to that exact script form.
/// Keeping them atomic prevents a Hiragana glyph from ever receiving the
/// Katakana trace (or the reverse) as Both-mode UI is composed.
@immutable
class KanaWritingTarget {
  const KanaWritingTarget({required this.kana, required this.stroke});

  final KanaEntry kana;
  final KanaStrokeData? stroke;
}

List<KanaWritingTarget> _writingTargets(
  _KanaDetailData data, {
  required bool includeBoth,
}) {
  final targets = <KanaWritingTarget>[
    KanaWritingTarget(kana: data.focused, stroke: data.stroke),
    if (includeBoth && data.counterpart != null)
      KanaWritingTarget(
        kana: data.counterpart!,
        stroke: data.counterpartStroke,
      ),
  ];
  targets.sort(
    (a, b) => (a.kana.isHiragana ? 0 : 1).compareTo(
      b.kana.isHiragana ? 0 : 1,
    ),
  );
  return targets;
}

KanaEntry? _grammarKana(
  _KanaDetailData data, {
  required bool includeCounterpart,
}) {
  if (data.focused.hasUsage) return data.focused;
  if (includeCounterpart && (data.counterpart?.hasUsage ?? false)) {
    return data.counterpart;
  }
  return null;
}

class _KanaDetail extends StatefulWidget {
  const _KanaDetail({
    required this.char,
    this.embedded = false,
    this.showBoth = false,
    this.onSelectKana,
  });

  final String char;
  final bool embedded;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

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
    final stroke = await KanaStrokeCatalog.load(widget.char);

    final otherScript = focused.isHiragana ? 'katakana' : 'hiragana';
    KanaEntry? counterpart;
    for (final kana in all) {
      if (kana.script == otherScript &&
          kana.romaji == focused.romaji &&
          kana.kind == focused.kind &&
          kana.row == focused.row) {
        counterpart = kana;
        break;
      }
    }
    final counterpartStroke = counterpart == null
        ? null
        : await KanaStrokeCatalog.load(counterpart.char);

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
      stroke: stroke,
      counterpartStroke: counterpartStroke,
      nearby: candidates.take(3).toList(growable: false),
      states: states,
      dueChars: dueChars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.watch<MnemonicViewModel>();
    if (widget.embedded) {
      return FutureBuilder<_KanaDetailData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _EmbeddedDetailError();
          final data = snapshot.data;
          if (data == null) {
            return _EmbeddedDetailSkeleton(char: widget.char);
          }
          return _EmbeddedKanaDetailContent(
            data: data,
            added: mnemonic.added,
            onAdd: () => _addToStudy(
              context,
              mnemonic,
              data: data,
              addBoth: widget.showBoth,
            ),
            showBoth: widget.showBoth,
            onSelectKana: widget.onSelectKana,
          );
        },
      );
    }
    return Scaffold(
      bottomNavigationBar: FutureBuilder<_KanaDetailData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();
          return _DetailActions(
            targets: _writingTargets(
              data,
              includeBoth: widget.showBoth,
            ),
            added: mnemonic.added,
            onAdd: () => _addToStudy(
              context,
              mnemonic,
              data: data,
              addBoth: widget.showBoth,
            ),
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
              return _DetailContent(
                data: data,
                showBoth: widget.showBoth,
                onSelectKana: widget.onSelectKana,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addToStudy(
    BuildContext context,
    MnemonicViewModel mnemonic, {
    required _KanaDetailData data,
    required bool addBoth,
  }) async {
    final appState = context.read<AppState>();
    final canStudyLocally = appState.localOnly && !kIsWeb;
    if (!appState.isAuthenticated && !canStudyLocally) {
      await _showStudyAuthRequired(
        context,
        addBoth: addBoth && data.counterpart != null,
      );
      return;
    }

    final study = context.read<StudyRepository>();
    var added = await mnemonic.addToStudy();
    if (!context.mounted) return;
    if (!added && mnemonic.error == authRequiredErrorMessage) {
      mnemonic.clearError();
      await _showStudyAuthRequired(
        context,
        addBoth: addBoth && data.counterpart != null,
      );
      return;
    }

    if (added && addBoth && data.counterpart != null) {
      try {
        await study.addCard(
          ItemType.kana,
          data.counterpart!.char,
        );
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          if (context.mounted) {
            await _showStudyAuthRequired(context, addBoth: true);
          }
          return;
        }
        added = false;
      } catch (_) {
        added = false;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? addBoth && data.counterpart != null
                  ? _copy(
                      context,
                      'Both forms added to your study deck',
                      'Les deux formes ont été ajoutées à vos révisions',
                    )
                  : _copy(
                      context,
                      'Added to your study deck',
                      'Ajouté à vos révisions',
                    )
              : mnemonic.error ?? _copy(context, 'Failed', 'Échec'),
        ),
      ),
    );
  }

  Future<void> _showStudyAuthRequired(
    BuildContext context, {
    required bool addBoth,
  }) =>
      showAuthRequiredSheet(
        context,
        title: _copy(
          context,
          addBoth ? 'Save both kana forms' : 'Save this kana',
          addBoth
              ? 'Enregistrer les deux formes du kana'
              : 'Enregistrer ce kana',
        ),
        description: _copy(
          context,
          addBoth
              ? 'Sign in to add both forms to your study deck and sync your progress.'
              : 'Sign in to add this kana to your study deck and sync your progress.',
          addBoth
              ? 'Connectez-vous pour ajouter les deux formes à vos révisions et synchroniser votre progression.'
              : 'Connectez-vous pour ajouter ce kana à vos révisions et synchroniser votre progression.',
        ),
      );
}

class _EmbeddedKanaDetailContent extends StatelessWidget {
  const _EmbeddedKanaDetailContent({
    required this.data,
    required this.added,
    required this.onAdd,
    required this.showBoth,
    required this.onSelectKana,
  });

  final _KanaDetailData data;
  final bool added;
  final VoidCallback onAdd;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

  @override
  Widget build(BuildContext context) {
    final targets = _writingTargets(data, includeBoth: showBoth);
    final hasPair = targets.length == 2;
    final grammarKana = _grammarKana(
      data,
      includeCounterpart: showBoth,
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: PageStorageKey('kana-detail-${data.focused.char}'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            children: [
              _TabletKanaHero(
                data: data,
                showBoth: showBoth,
                onSelectKana: onSelectKana,
              ),
              if (grammarKana != null) ...[
                const SizedBox(height: 16),
                KanaGrammarSection(kana: grammarKana),
              ],
              const SizedBox(height: 14),
              KanaWritingReference(targets: targets),
              const SizedBox(height: 16),
              _FeaturedMnemonic(
                scriptContext: hasPair ? data.focused : null,
              ),
              const SizedBox(height: 16),
              _NearbyKana(
                data: data,
                showBoth: showBoth,
                onSelectKana: onSelectKana,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: NeoPrimaryButton(
                  label: hasPair
                      ? _copy(
                          context,
                          'Practice both forms',
                          'Pratiquer les deux formes',
                        )
                      : _copy(context, 'Free practice', 'Pratique libre'),
                  icon: Icons.gesture_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KanaWritingPracticePage(
                        targets: targets,
                        mode: KanaWritingMode.free,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NeoIconButton(
                icon: added ? Icons.check_rounded : Icons.add_rounded,
                label: added
                    ? hasPair
                        ? _copy(
                            context,
                            'Both forms in your deck',
                            'Les deux formes dans vos révisions',
                          )
                        : _copy(context, 'In your deck', 'Dans vos révisions')
                    : hasPair
                        ? _copy(
                            context,
                            'Add both forms',
                            'Ajouter les deux formes',
                          )
                        : _copy(
                            context,
                            'Add to study',
                            'Ajouter aux révisions',
                          ),
                tone: added ? NeoTone.lime : NeoTone.paper,
                onTap: added ? () {} : onAdd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabletKanaHero extends StatelessWidget {
  const _TabletKanaHero({
    required this.data,
    required this.showBoth,
    this.onSelectKana,
  });

  final _KanaDetailData data;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

  @override
  Widget build(BuildContext context) {
    final kana = data.focused;
    final pair = <KanaEntry>[
      kana,
      if (showBoth && data.counterpart != null) data.counterpart!,
    ]..sort(
        (a, b) => (a.isHiragana ? 0 : 1).compareTo(
          b.isHiragana ? 0 : 1,
        ),
      );
    final hasPair = pair.length == 2;
    return NeoCard(
      tone: NeoTone.lime,
      shadow: 2,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          for (var index = 0; index < pair.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            Pressable(
              label: _copy(
                context,
                'Play ${pair[index].script} ${pair[index].romaji}',
                'Écouter ${pair[index].script} ${pair[index].romaji}',
              ),
              onTap: () => Speech.instance.say(pair[index].char),
              child: Container(
                width: pair.length == 2 ? 68 : 82,
                height: 86,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  border: Border.all(color: context.jc.ink, width: 2.5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pair[index].char,
                      style: TextStyle(
                        fontFamily: 'ZenKakuGothicNew',
                        fontSize: pair[index].char.characters.length > 1
                            ? pair.length == 2
                                ? 29
                                : 38
                            : pair.length == 2
                                ? 45
                                : 56,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    Text(
                      pair[index].isHiragana ? 'HIRA' : 'KATA',
                      style: const TextStyle(
                        fontSize: 8.5,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  label: _copy(
                    context,
                    'Play ${kana.romaji}',
                    'Écouter ${kana.romaji}',
                  ),
                  onTap: () => Speech.instance.say(kana.char),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.jc.ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          size: 17,
                          color: context.jc.surface,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          kana.romaji,
                          style: TextStyle(
                            color: context.jc.surface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Tag(
                      label: hasPair
                          ? _copy(
                              context,
                              'Hiragana + Katakana',
                              'Hiragana + Katakana',
                            )
                          : kana.isHiragana
                              ? 'Hiragana'
                              : 'Katakana',
                    ),
                    if (hasPair)
                      _Tag(
                        label: _copy(
                          context,
                          '2 forms · same sound',
                          '2 formes · même son',
                        ),
                      ),
                    _Tag(label: _kindLabel(context, kana.kind, kana.row)),
                    _Tag(
                      label: _copy(
                        context,
                        '${kana.row.toUpperCase()} row',
                        'Rangée ${kana.row.toUpperCase()}',
                      ),
                    ),
                  ],
                ),
                if (!showBoth && data.counterpart != null) ...[
                  const SizedBox(height: 10),
                  _KanaScriptSwitcher(
                    data: data,
                    onSelectKana: onSelectKana,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedDetailSkeleton extends StatelessWidget {
  const _EmbeddedDetailSkeleton({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 124,
            decoration: BoxDecoration(
              color: context.jc.lime,
              border: Border.all(color: context.jc.ink, width: 3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: context.jc.ink,
                  blurRadius: 0,
                  offset: const Offset(6, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                char,
                style: TextStyle(
                  fontFamily: 'ZenKakuGothicNew',
                  fontSize: 88,
                  fontWeight: FontWeight.w900,
                  color: context.jc.ink.withValues(alpha: .2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 172,
            decoration: BoxDecoration(
              color: context.jc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.jc.ink, width: 3),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 112,
            decoration: BoxDecoration(
              color: context.jc.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.jc.ink, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedDetailError extends StatelessWidget {
  const _EmbeddedDetailError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _copy(
            context,
            'This kana could not be loaded.',
            'Ce kana n’a pas pu être chargé.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.data,
    required this.showBoth,
    this.onSelectKana,
  });

  final _KanaDetailData data;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 760;
        final targets = _writingTargets(data, includeBoth: showBoth);
        final hasPair = targets.length == 2;
        final grammarKana = _grammarKana(
          data,
          includeCounterpart: showBoth,
        );
        final main = Column(
          children: [
            if (hasPair)
              _TabletKanaHero(data: data, showBoth: true)
            else
              _KanaHero(data: data),
            const SizedBox(height: 20),
            KanaWritingReference(targets: targets),
            const SizedBox(height: 18),
            _NearbyKana(data: data, showBoth: showBoth),
          ],
        );
        final supporting = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (grammarKana != null) ...[
              KanaGrammarSection(kana: grammarKana),
              const SizedBox(height: 18),
            ],
            if (data.focused.hasOrigin) ...[
              KanaOriginSection(kana: data.focused),
              const SizedBox(height: 18),
            ],
            _FeaturedMnemonic(
              scriptContext: hasPair ? data.focused : null,
            ),
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
            _DetailTopBar(
              data: data,
              showBoth: showBoth,
              onSelectKana: onSelectKana,
            ),
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
  const _DetailTopBar({
    required this.data,
    required this.showBoth,
    this.onSelectKana,
  });

  final _KanaDetailData data;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

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
        if (showBoth)
          const NeoBadge('BOTH', tone: NeoTone.acid)
        else if (data.counterpart != null)
          _KanaScriptSwitcher(
            data: data,
            onSelectKana: onSelectKana,
          ),
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

class _KanaScriptSwitcher extends StatelessWidget {
  const _KanaScriptSwitcher({required this.data, this.onSelectKana});

  final _KanaDetailData data;
  final ValueChanged<String>? onSelectKana;

  @override
  Widget build(BuildContext context) {
    final selected = data.focused.isHiragana ? 'hiragana' : 'katakana';
    return SizedBox(
      width: 190,
      height: 42,
      child: NeoSegmentedControl<String>(
        height: 42,
        selected: selected,
        segments: const [
          NeoSegment('hiragana', 'Hiragana'),
          NeoSegment('katakana', 'Katakana'),
        ],
        onChanged: (target) {
          if (target == selected || data.counterpart == null) return;
          final next = data.counterpart!;
          if (onSelectKana != null) {
            onSelectKana!(next.char);
          } else {
            context.push('/kana/${next.char}');
          }
        },
      ),
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
      shadow: 2,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.jc.surface,
              border: Border.all(color: context.jc.ink, width: 2.5),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              kana.char,
              style: const TextStyle(
                fontFamily: 'ZenKakuGothicNew',
                fontSize: 58,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  label: _copy(
                    context,
                    'Play ${kana.romaji}',
                    'Écouter ${kana.romaji}',
                  ),
                  onTap: () => Speech.instance.say(kana.char),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: context.jc.ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: context.jc.surface,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          kana.romaji,
                          style: TextStyle(
                            color: context.jc.surface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Tag(label: _kindLabel(context, kana.kind, kana.row)),
                    if (data.counterpart != null)
                      _TwinTag(kana: data.counterpart!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingGuide extends StatelessWidget {
  const _WritingGuide({super.key, required this.target, this.title});

  final KanaWritingTarget target;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final kana = target.kana;
    final stroke = target.stroke;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? _copy(context, 'Writing gesture', 'Geste d’écriture'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 172,
              height: 172,
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
              child: stroke == null || stroke.paths.isEmpty
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter:
                                _WritingGridPainter(color: context.jc.muted),
                          ),
                        ),
                        Center(
                          child: Text(
                            kana.char,
                            style: TextStyle(
                              fontFamily: 'ZenKakuGothicNew',
                              fontSize: 105,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: context.jc.ink,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(5),
                      child: StrokeOrderView(
                        paths: stroke.paths,
                        viewBox: stroke.viewBox,
                        size: 154,
                        showControls: false,
                        numberColor: kana.isHiragana
                            ? context.jc.magenta
                            : context.jc.brand,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeoCard(
                    tone: NeoTone.magenta,
                    shadow: 3,
                    radius: 9,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KanaWritingPracticePage(
                          targets: [target],
                          mode: KanaWritingMode.guided,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gesture_rounded, size: 17),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _copy(
                              context,
                              'Guided tracing',
                              'Tracé guidé',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: NeoCard(
                      tone: NeoTone.paper,
                      shadow: 2,
                      radius: 9,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KanaWritingPracticePage(
                            targets: [target],
                            mode: KanaWritingMode.free,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_rounded, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _copy(
                                context,
                                'Free practice',
                                'Pratique libre',
                              ),
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
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _copy(
                      context,
                      'Guided tracing overlays the model and replays stroke order.',
                      'Le tracé guidé superpose le modèle et rejoue l’ordre des traits.',
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
                      'Free practice starts blank; reveal the guide only when needed.',
                      'La pratique libre commence à blanc ; affichez le guide si besoin.',
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

class KanaWritingReference extends StatelessWidget {
  const KanaWritingReference({super.key, required this.targets})
      : assert(targets.length > 0);

  final List<KanaWritingTarget> targets;

  @override
  Widget build(BuildContext context) => targets.length == 1
      ? _WritingGuide(target: targets.first)
      : _BothWritingGuide(targets: targets);
}

class _BothWritingGuide extends StatelessWidget {
  const _BothWritingGuide({required this.targets});

  final List<KanaWritingTarget> targets;

  @override
  Widget build(BuildContext context) {
    Widget guide(KanaWritingTarget target) => _WritingGuide(
          key: ValueKey('kana-writing-${target.kana.script}'),
          target: target,
          title: target.kana.isHiragana
              ? _copy(
                  context,
                  'Hiragana gesture · ${target.kana.char}',
                  'Tracé hiragana · ${target.kana.char}',
                )
              : _copy(
                  context,
                  'Katakana gesture · ${target.kana.char}',
                  'Tracé katakana · ${target.kana.char}',
                ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var index = 0; index < targets.length; index++) ...[
                if (index > 0) const SizedBox(height: 20),
                guide(targets[index]),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < targets.length; index++) ...[
              if (index > 0) const SizedBox(width: 18),
              Expanded(child: guide(targets[index])),
            ],
          ],
        );
      },
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
  const _FeaturedMnemonic({this.scriptContext});

  final KanaEntry? scriptContext;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MnemonicViewModel>();
    final mnemonic = vm.items.isEmpty ? null : vm.items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scriptContext == null
              ? _copy(context, 'Community mnemonic', 'Mnémo de la communauté')
              : scriptContext!.isHiragana
                  ? _copy(
                      context,
                      'Hiragana mnemonic · ${scriptContext!.char}',
                      'Mnémo hiragana · ${scriptContext!.char}',
                    )
                  : _copy(
                      context,
                      'Katakana mnemonic · ${scriptContext!.char}',
                      'Mnémo katakana · ${scriptContext!.char}',
                    ),
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
                  child: Center(child: NeoChaseLoader()),
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
  const _NearbyKana({
    required this.data,
    this.showBoth = false,
    this.onSelectKana,
  });

  final _KanaDetailData data;
  final bool showBoth;
  final ValueChanged<String>? onSelectKana;

  @override
  Widget build(BuildContext context) {
    if (data.nearby.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showBoth
              ? data.focused.isHiragana
                  ? _copy(
                      context,
                      'Nearby pairs · Hiragana anchors',
                      'Paires proches · repères hiragana',
                    )
                  : _copy(
                      context,
                      'Nearby pairs · Katakana anchors',
                      'Paires proches · repères katakana',
                    )
              : _copy(context, 'Nearby kana', 'Kana proches'),
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
                  onTap: onSelectKana == null
                      ? () => context.push(
                            '/kana/${data.nearby[i].char}${showBoth ? '?mode=both' : ''}',
                          )
                      : () => onSelectKana!(data.nearby[i].char),
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
                fontFamily: 'ZenKakuGothicNew',
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
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 31),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.jc.surface,
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
    required this.targets,
    required this.added,
    required this.onAdd,
  });

  final List<KanaWritingTarget> targets;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final hasPair = targets.length == 2;
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
                  label: hasPair
                      ? _copy(
                          context,
                          'Practice both forms',
                          'Pratiquer les deux formes',
                        )
                      : _copy(context, 'Free practice', 'Pratique libre'),
                  icon: Icons.gesture_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KanaWritingPracticePage(
                        targets: targets,
                        mode: KanaWritingMode.free,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NeoIconButton(
                icon: added ? Icons.check_rounded : Icons.add_rounded,
                label: added
                    ? hasPair
                        ? _copy(
                            context,
                            'Both forms in your deck',
                            'Les deux formes dans vos révisions',
                          )
                        : _copy(context, 'In your deck', 'Dans vos révisions')
                    : hasPair
                        ? _copy(
                            context,
                            'Add both forms',
                            'Ajouter les deux formes',
                          )
                        : _copy(
                            context,
                            'Add to study',
                            'Ajouter aux révisions',
                          ),
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

enum KanaWritingMode { guided, free }

class KanaWritingPracticePage extends StatefulWidget {
  const KanaWritingPracticePage({
    super.key,
    required this.targets,
    required this.mode,
  }) : assert(targets.length > 0);

  final List<KanaWritingTarget> targets;
  final KanaWritingMode mode;

  @override
  State<KanaWritingPracticePage> createState() =>
      _KanaWritingPracticePageState();
}

class _KanaWritingPracticePageState extends State<KanaWritingPracticePage> {
  late final List<DrawingController> _controllers = [
    for (final _ in widget.targets) DrawingController(),
  ];
  late final List<bool> _showGuides = [
    for (final _ in widget.targets) widget.mode == KanaWritingMode.guided,
  ];
  int _step = 0;

  KanaWritingTarget get _target => widget.targets[_step];
  DrawingController get _controller => _controllers[_step];
  bool get _showGuide => _showGuides[_step];

  void _setStep(int step) {
    if (step == _step || step < 0 || step >= widget.targets.length) return;
    Haptics.tick();
    setState(() => _step = step);
  }

  void _toggleGuide() {
    Haptics.tick();
    setState(() => _showGuides[_step] = !_showGuides[_step]);
  }

  void _advanceOrFinish() {
    if (_step < widget.targets.length - 1) {
      _setStep(_step + 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final kana = target.kana;
    final stroke = target.stroke;
    final guided = widget.mode == KanaWritingMode.guided;
    final hasStrokeOrder = stroke != null && stroke.paths.isNotEmpty;
    final hasPair = widget.targets.length == 2;
    final next = _step < widget.targets.length - 1
        ? widget.targets[_step + 1].kana
        : null;
    final numberColor = kana.isHiragana ? context.jc.magenta : context.jc.brand;
    final showReferencePanel = guided &&
        hasStrokeOrder &&
        (!hasPair || MediaQuery.sizeOf(context).height >= 700);
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
                            hasPair
                                ? guided
                                    ? _copy(
                                        context,
                                        'Trace both forms',
                                        'Tracer les deux formes',
                                      )
                                    : _copy(
                                        context,
                                        'Practice both forms',
                                        'Pratiquer les deux formes',
                                      )
                                : guided
                                    ? _copy(
                                        context,
                                        'Guided tracing',
                                        'Tracé guidé',
                                      )
                                    : _copy(
                                        context,
                                        'Free practice',
                                        'Pratique libre',
                                      ),
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPair
                                ? _copy(
                                    context,
                                    'Complete both scripts. Each form keeps its own canvas.',
                                    'Complétez les deux écritures. Chaque forme garde son propre canvas.',
                                  )
                                : guided
                                    ? _copy(
                                        context,
                                        'Follow the model and stroke order, then try once without it.',
                                        'Suivez le modèle et l’ordre des traits, puis essayez sans aide.',
                                      )
                                    : _copy(
                                        context,
                                        'Write from memory on a blank canvas. Reveal the stroke order if you get stuck.',
                                        'Écrivez de mémoire sur une toile blanche. Affichez l’ordre des traits en cas de doute.',
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
                if (hasPair) ...[
                  SizedBox(
                    height: 44,
                    child: NeoSegmentedControl<int>(
                      selected: _step,
                      height: 44,
                      segments: [
                        for (var index = 0;
                            index < widget.targets.length;
                            index++)
                          NeoSegment(
                            index,
                            '${index + 1} · ${widget.targets[index].kana.isHiragana ? 'Hiragana' : 'Katakana'} ${widget.targets[index].kana.char}',
                          ),
                      ],
                      onChanged: _setStep,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AnimatedSwitcher(
                  duration: Motion.timed(context, Motion.fast),
                  switchInCurve: Motion.outStrong,
                  switchOutCurve: Motion.out,
                  child: NeoCard(
                    key: ValueKey('practice-target-${kana.char}'),
                    tone: guided
                        ? NeoTone.magenta
                        : kana.isHiragana
                            ? NeoTone.acid
                            : NeoTone.lime,
                    shadow: 3,
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
                        if (hasPair)
                          NeoBadge(
                            '${_step + 1} / ${widget.targets.length}',
                            tone: NeoTone.paper,
                          ),
                        if (hasPair) const SizedBox(width: 12),
                        Text(
                          kana.char,
                          style: const TextStyle(
                            fontFamily: 'ZenKakuGothicNew',
                            fontSize: 48,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (showReferencePanel) ...[
                  SizedBox(
                    height: hasPair ? 168 : 190,
                    child: NeoCard(
                      tone: NeoTone.paper,
                      shadow: 4,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: StrokeOrderView(
                        paths: stroke.paths,
                        viewBox: stroke.viewBox,
                        size: hasPair ? 124 : 140,
                        numberColor: numberColor,
                        showControls: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                                child: DrawingCanvas(
                                  controller: _controller,
                                  guidePaths:
                                      hasStrokeOrder ? stroke.paths : const [],
                                  guideViewBox: hasStrokeOrder
                                      ? stroke.viewBox
                                      : '0 0 109 109',
                                  showGuide: _showGuide,
                                  showStrokeNumbers:
                                      _showGuide && hasStrokeOrder,
                                  strokeNumberColor: numberColor,
                                ),
                              ),
                              if (_showGuide && !hasStrokeOrder)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Text(
                                        kana.char,
                                        style: TextStyle(
                                          fontFamily: 'ZenKakuGothicNew',
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
                      flex: 4,
                      child: _PracticeTool(
                        icon: Icons.undo_rounded,
                        label: _copy(context, 'Undo', 'Annuler'),
                        onTap: _controller.undo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _PracticeTool(
                        icon: Icons.layers_clear_outlined,
                        label: _copy(context, 'Clear', 'Effacer'),
                        onTap: _controller.clear,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: _PracticeTool(
                        icon: hasStrokeOrder
                            ? Icons.format_list_numbered_rounded
                            : _showGuide
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_outlined,
                        label: hasStrokeOrder
                            ? _copy(
                                context,
                                'Stroke order',
                                'Ordre des traits',
                              )
                            : _copy(context, 'Guide', 'Guide'),
                        selected: _showGuide,
                        onTap: _toggleGuide,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NeoPrimaryButton(
                  label: next == null
                      ? _copy(context, 'Done', 'Terminé')
                      : _copy(
                          context,
                          'Next: ${next.isHiragana ? 'Hiragana' : 'Katakana'} ${next.char}',
                          'Suivant : ${next.isHiragana ? 'Hiragana' : 'Katakana'} ${next.char}',
                        ),
                  icon: next == null
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  tone: NeoTone.ink,
                  onTap: _advanceOrFinish,
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
                  fontFamily: 'ZenKakuGothicNew',
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
