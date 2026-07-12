import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/speech.dart';
import '../../models/enums.dart';
import '../../models/mnemonic_deck.dart';
import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/mnemonic_deck_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/mnemonic_deck_viewmodel.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';

/// The NeoPop 16 tablet home. It owns only the editorial and community data;
/// review totals stay in the shell-level [DashboardViewModel] so the due badge
/// and dashboard always agree.
class TabletDashboardView extends StatelessWidget {
  const TabletDashboardView({
    super.key,
    required this.onOpenDictionary,
  });

  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final language = context.read<AppState>().mnemonicLanguage;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => SearchViewModel(
            ctx.read<DictionaryRepository>(),
            glossLanguage: language,
          )..loadLanding(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CommunityDecksViewModel(
            ctx.read<MnemonicDeckRepository>(),
            language: language,
          )..load(),
        ),
      ],
      child: _TabletDashboard(onOpenDictionary: onOpenDictionary),
    );
  }
}

class _TabletDashboard extends StatelessWidget {
  const _TabletDashboard({required this.onOpenDictionary});

  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return ColoredBox(
      color: context.jc.canvas,
      child: Column(
        children: [
          _DashboardHeader(onOpenDictionary: onOpenDictionary),
          Expanded(
            child: _DashboardBody(
              wide: wide,
              onOpenDictionary: onOpenDictionary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onOpenDictionary});

  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final streak = context.watch<DashboardViewModel>().stats.streak;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? _copy(context, 'Morning. Ready to begin?', 'Bonjour. On commence ?')
        : hour < 18
            ? _copy(
                context, 'Hello. Shall we continue?', 'Bonjour. On continue ?')
            : _copy(
                context, 'Evening. Back to it?', 'Bonsoir. On s\'y remet ?');
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: context.jc.brand,
          border: Border(bottom: BorderSide(color: context.jc.ink, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
        child: Column(
          children: [
            Row(
              children: [
                const JibikiWordmark(
                  fontSize: 24,
                  variant: JibikiBrandVariant.negative,
                ),
                const Spacer(),
                Text(
                  streak == 1
                      ? _copy(context, 'Streak: 1 day', 'Série : 1 jour')
                      : _copy(context, 'Streak: $streak days',
                          'Série : $streak jours'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Flexible(
                  flex: 0,
                  child: Text(
                    greeting,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _DashboardSearchField(
                    onSubmitted: onOpenDictionary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSearchField extends StatefulWidget {
  const _DashboardSearchField({required this.onSubmitted});

  final void Function([String query]) onSubmitted;

  @override
  State<_DashboardSearchField> createState() => _DashboardSearchFieldState();
}

class _DashboardSearchFieldState extends State<_DashboardSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) widget.onSubmitted(query);
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.only(left: 14, right: 6),
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
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 21, color: context.jc.ink),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: _copy(
                    context,
                    'A word, kanji or romaji...',
                    'Un mot, un kanji, du rōmaji…',
                  ),
                ),
              ),
            ),
            Pressable(
              label: _copy(context, 'Search', 'Rechercher'),
              onTap: _submit,
              focusRadius: 8,
              child: SizedBox.square(
                dimension: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.jc.acid,
                    border: Border.all(color: context.jc.ink, width: 2.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.wide,
    required this.onOpenDictionary,
  });

  final bool wide;
  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (wide) {
          final gridHeight = math.max(620.0, constraints.maxHeight - 42);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            child: SizedBox(
              height: gridHeight,
              child: _WideDashboardGrid(
                onOpenDictionary: onOpenDictionary,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          child: SizedBox(
            height: 752,
            child: _TwoColumnDashboard(
              onOpenDictionary: onOpenDictionary,
            ),
          ),
        );
      },
    );
  }
}

class _WideDashboardGrid extends StatelessWidget {
  const _WideDashboardGrid({required this.onOpenDictionary});

  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = (constraints.maxWidth - 32) / 3.32;
        final left = unit * 1.32;
        const top = 186.0;
        const bottom = 108.0;
        final middle =
            math.max(170.0, constraints.maxHeight - top - bottom - 32);
        final thirdX = left + 32 + unit;
        final middleY = top + 16;
        final bottomY = middleY + middle + 16;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: left,
              height: top + 16 + middle,
              child: const _DueCard(),
            ),
            Positioned(
              left: left + 16,
              top: 0,
              width: unit * 2 + 16,
              height: top,
              child: _WordOfTheDayCard(
                onOpenDictionary: onOpenDictionary,
              ),
            ),
            Positioned(
              left: left + 16,
              top: middleY,
              width: unit,
              height: middle,
              child: const _ForecastCard(),
            ),
            Positioned(
              left: thirdX,
              top: middleY,
              width: unit,
              height: middle + 16 + bottom,
              child: const _CommunityCard(),
            ),
            Positioned(
              left: 0,
              top: bottomY,
              width: left + 16 + unit,
              height: bottom,
              child: _RecentCard(onOpenDictionary: onOpenDictionary),
            ),
          ],
        );
      },
    );
  }
}

class _TwoColumnDashboard extends StatelessWidget {
  const _TwoColumnDashboard({required this.onOpenDictionary});

  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - 16) / 2;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: column,
              height: 416,
              child: const _DueCard(compact: true),
            ),
            Positioned(
              left: column + 16,
              top: 0,
              width: column,
              height: 186,
              child: _WordOfTheDayCard(
                compact: true,
                onOpenDictionary: onOpenDictionary,
              ),
            ),
            Positioned(
              left: column + 16,
              top: 202,
              width: column,
              height: 214,
              child: const _ForecastCard(compact: true),
            ),
            Positioned(
              left: 0,
              top: 432,
              width: column,
              height: 108,
              child: _RecentCard(
                compact: true,
                onOpenDictionary: onOpenDictionary,
              ),
            ),
            Positioned(
              left: column + 16,
              top: 432,
              width: column,
              height: 320,
              child: const _CommunityCard(compact: true),
            ),
          ],
        );
      },
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final stats = vm.stats;
    if (vm.isLoading && stats.totalCards == 0) {
      return _DashboardPanel(
        color: context.jc.acid,
        shadow: 6,
        padding: const EdgeInsets.all(20),
        child: const _DueSkeleton(),
      );
    }
    final minutes =
        stats.dueNow == 0 ? 2 : math.max(1, (stats.dueNow * .75).ceil());
    return _DashboardPanel(
      color: context.jc.acid,
      shadow: 6,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.dueNow}',
                      style: TextStyle(
                        fontSize: compact ? 96 : 128,
                        height: .84,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      stats.dueNow == 0
                          ? _copy(context, 'nothing due', 'rien à réviser')
                          : _copy(context, 'to review', 'à réviser'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (stats.newRemaining > 0)
                _MiniTag(
                  '+ ${stats.newRemaining} ${_copy(context, 'new', 'nouvelles')}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _copy(context, '$minutes minutes, on the clock.',
                '$minutes minutes, chrono.'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _dueMix(context, vm.dueByType, stats.dueNow),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: context.jc.body,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _HardButton(
            height: 56,
            color: context.jc.ink,
            radius: 12,
            semanticLabel:
                _copy(context, 'Start the session', 'Lancer la session'),
            onTap: () => context.push('/session'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stats.dueNow == 0
                      ? _copy(
                          context, 'Start learning', 'Commencer à apprendre')
                      : _copy(
                          context, 'Start the session', 'Lancer la session'),
                  style: TextStyle(
                      color: context.jc.acid,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 9),
                Icon(Icons.play_arrow_rounded,
                    color: context.jc.acid, size: 21),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordOfTheDayCard extends StatelessWidget {
  const _WordOfTheDayCard({
    required this.onOpenDictionary,
    this.compact = false,
  });

  final bool compact;
  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final word = vm.wordOfTheDay;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _HardButton(
            color: context.jc.lavender,
            radius: 14,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            semanticLabel: word == null
                ? null
                : '${word.headword}, ${word.primaryReading}',
            onTap: word == null
                ? null
                : () {
                    vm.rememberOpened(word);
                    onOpenDictionary(word.headword);
                  },
            child: vm.landingLoading && word == null
                ? const _WordSkeleton()
                : word == null
                    ? Center(
                        child: Text(
                          _copy(context, 'Available with a dictionary pack.',
                              'Disponible avec un dictionnaire téléchargé.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      )
                    : _WordOfTheDayContent(word: word, compact: compact),
          ),
        ),
        Positioned(
          left: 16,
          top: -13,
          child: Transform.rotate(
            angle: -0.035,
            child: _HardButton(
              color: context.jc.magenta,
              borderWidth: 2.5,
              shadow: 3,
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                _copy(context, 'Word of the day', 'Mot du jour'),
                style: const TextStyle(
                    fontSize: 12, height: 1, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WordOfTheDayContent extends StatelessWidget {
  const _WordOfTheDayContent({required this.word, required this.compact});

  final WordEntry word;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reading = word.primaryReading;
    final gloss =
        word.summaryGloss(context.read<SearchViewModel>().glossLanguage);
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (reading.isNotEmpty)
              Text(reading,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            Text(
              word.headword,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'ZenKakuGothicNew',
                fontSize: compact ? 46 : 58,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                gloss,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          _HardButton(
            color: context.jc.surface,
            borderWidth: 2.5,
            shadow: 3,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 44,
            semanticLabel: _copy(
                context, 'Play pronunciation', 'Écouter la prononciation'),
            onTap: reading.isEmpty ? null : () => Speech.instance.say(reading),
            child: Row(
              children: [
                const Icon(Icons.volume_up_rounded, size: 18),
                const SizedBox(width: 7),
                Text(reading,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    return _DashboardPanel(
      color: context.jc.surface,
      padding: EdgeInsets.fromLTRB(16, 14, 16, compact ? 12 : 14),
      child: vm.forecastLoading
          ? const _ForecastSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _copy(context, 'Upcoming load', 'Charge à venir'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(child: _ForecastBars(values: vm.forecast)),
                const SizedBox(height: 8),
                Text(
                  _copy(
                    context,
                    'Tomorrow: ${vm.forecast.first} · In 7 days: ${vm.forecast.fold<int>(0, (sum, value) => sum + value)} total.',
                    'Demain : ${vm.forecast.first} · Dans 7 j : ${vm.forecast.fold<int>(0, (sum, value) => sum + value)} au total.',
                  ),
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

class _ForecastBars extends StatelessWidget {
  const _ForecastBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(1, values.fold<int>(0, math.max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barSpace = math.max(16.0, constraints.maxHeight - 29);
                final height = math.max(6.0, barSpace * values[i] / maxValue);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i]}',
                        style: const TextStyle(
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Container(
                      width: double.infinity,
                      height: height,
                      decoration: BoxDecoration(
                        color: i == 0 ? context.jc.acid : context.jc.brand,
                        border: Border.all(color: context.jc.ink, width: 2.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('+${i + 1}',
                        style: const TextStyle(
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w600)),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CommunityDecksViewModel>();
    final decks = vm.decks.take(2).toList(growable: false);
    return _DashboardPanel(
      color: context.jc.magenta,
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.trText('Community'),
              style: const TextStyle(
                  fontSize: 20, height: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            _copy(context, 'Packs made by other learners.',
                'Les paquets des autres. Prends, note, améliore.'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (vm.isLoading && decks.isEmpty) ...[
            const Expanded(child: _CommunitySkeleton()),
          ] else if (decks.isEmpty) ...[
            Expanded(
              child: Center(
                child: Text(
                  _copy(context, 'No public pack yet.',
                      'Aucun paquet public pour le moment.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else ...[
            for (var i = 0; i < decks.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              _CommunityRow(deck: decks[i]),
            ],
            const Spacer(),
          ],
          const SizedBox(height: 9),
          _HardButton(
            height: compact ? 46 : 50,
            color: context.jc.ink,
            radius: 12,
            semanticLabel: _copy(context, 'Explore community packs',
                'Explorer les paquets de la communauté'),
            onTap: () => context.push('/decks/community'),
            child: Center(
              child: Text(
                '${_copy(context, 'Explore', 'Explorer')}  ›',
                style: TextStyle(
                    color: context.jc.acid,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({required this.deck});

  final MnemonicDeck deck;

  @override
  Widget build(BuildContext context) {
    return _HardButton(
      color: context.jc.surface,
      borderWidth: 2.5,
      shadow: 3,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      semanticLabel: deck.title,
      onTap: () => context.push('/decks/community/${deck.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deck.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, height: 1.15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '${_copy(context, 'by', 'par')} ${deck.authorName} · ${deck.itemCount} ${_copy(context, 'cards', 'cartes')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: context.jc.body,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('▲ ${deck.score}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.onOpenDictionary,
    this.compact = false,
  });

  final void Function([String query]) onOpenDictionary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final words = vm.recentWords;
    return _DashboardPanel(
      color: context.jc.surface,
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 13 : 18, vertical: 12),
      child: vm.landingLoading
          ? const _RecentSkeleton()
          : LayoutBuilder(
              builder: (context, constraints) {
                final header = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _copy(context, 'Seen recently', 'Vus récemment'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    if (compact) const Spacer(),
                    if (compact)
                      _HistoryButton(
                        onTap: words.isEmpty
                            ? onOpenDictionary
                            : () => _showHistory(context, vm),
                      ),
                  ],
                );
                final chips = words.isEmpty
                    ? Text(
                        _copy(context, 'Your history starts here.',
                            'Votre historique commence ici.'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.jc.body,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < words.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _RecentWordButton(
                                recent: words[i],
                                onOpenDictionary: onOpenDictionary,
                              ),
                            ],
                          ],
                        ),
                      );
                if (compact || constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 8),
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerLeft, child: chips)),
                    ],
                  );
                }
                return Row(
                  children: [
                    header,
                    const SizedBox(width: 14),
                    Expanded(child: chips),
                    const SizedBox(width: 10),
                    _HistoryButton(
                      onTap: words.isEmpty
                          ? onOpenDictionary
                          : () => _showHistory(context, vm),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _showHistory(BuildContext context, SearchViewModel vm) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: NeoCard(
            shadow: 6,
            radius: 14,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _copy(
                          context,
                          'Dictionary history',
                          'Historique du dictionnaire',
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    NeoIconButton(
                      icon: Icons.close_rounded,
                      label: _copy(context, 'Close', 'Fermer'),
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vm.recentWords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final recent = vm.recentWords[index];
                      return _HistoryRow(
                        recent: recent,
                        onTap: () {
                          Navigator.pop(dialogContext);
                          vm.rememberOpened(recent.word);
                          onOpenDictionary(recent.word.headword);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentWordButton extends StatelessWidget {
  const _RecentWordButton({
    required this.recent,
    required this.onOpenDictionary,
  });

  final RecentDictionaryWord recent;
  final void Function([String query]) onOpenDictionary;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SearchViewModel>();
    return Pressable(
      label: recent.word.headword,
      onTap: () {
        vm.rememberOpened(recent.word);
        onOpenDictionary(recent.word.headword);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 96),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: context.jc.canvas,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          recent.word.headword,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'ZenKakuGothicNew',
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.recent, required this.onTap});

  final RecentDictionaryWord recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        label: recent.word.headword,
        onTap: onTap,
        focusRadius: 10,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: context.jc.canvas,
            border: Border.all(color: context.jc.ink, width: 2.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recent.word.headword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ZenKakuGothicNew',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (recent.word.primaryReading.isNotEmpty)
                      Text(
                        recent.word.primaryReading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.jc.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      );
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        child: Text(
          '${_copy(context, 'Full history', 'Tout l\'historique')}  ›',
          maxLines: 1,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadow = 4,
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: context.jc.ink, width: 3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: context.jc.ink,
              blurRadius: 0,
              offset: Offset(shadow, shadow)),
        ],
      ),
      child: child,
    );
  }
}

class _HardButton extends StatelessWidget {
  const _HardButton({
    required this.color,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
    this.height,
    this.radius = 12,
    this.borderWidth = 3,
    this.shadow = 4,
  });

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double radius;
  final double borderWidth;
  final double shadow;

  @override
  Widget build(BuildContext context) {
    Widget paint(bool pressed) => AnimatedContainer(
          duration: Motion.timed(context, const Duration(milliseconds: 120)),
          curve: Curves.easeOut,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: context.jc.ink, width: borderWidth),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: shadow <= 0 || pressed
                ? null
                : [
                    BoxShadow(
                      color: context.jc.ink,
                      blurRadius: 0,
                      offset: Offset(shadow, shadow),
                    ),
                  ],
          ),
          child: child,
        );
    if (onTap == null) return paint(false);
    return Pressable.builder(
      label: semanticLabel,
      focusRadius: radius,
      onTap: onTap,
      builder: (context, pressed) => paint(pressed),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.jc.surface,
        border: Border.all(color: context.jc.ink, width: 2.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, height: 1, fontWeight: FontWeight.w700)),
    );
  }
}

class _DueSkeleton extends StatelessWidget {
  const _DueSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 126, height: 94),
        SizedBox(height: 14),
        _SkeletonBlock(width: 120, height: 18),
        SizedBox(height: 18),
        _SkeletonBlock(width: 170, height: 12),
        Spacer(),
        _SkeletonBlock(height: 56),
      ],
    );
  }
}

class _WordSkeleton extends StatelessWidget {
  const _WordSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBlock(width: 94, height: 72),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBlock(width: 90, height: 14),
              SizedBox(height: 10),
              _SkeletonBlock(height: 12),
              SizedBox(height: 7),
              _SkeletonBlock(width: 150, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForecastSkeleton extends StatelessWidget {
  const _ForecastSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 110, height: 13),
        SizedBox(height: 14),
        Expanded(child: _SkeletonBlock()),
        SizedBox(height: 10),
        _SkeletonBlock(width: 170, height: 11),
      ],
    );
  }
}

class _CommunitySkeleton extends StatelessWidget {
  const _CommunitySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: _SkeletonBlock()),
        SizedBox(height: 10),
        Expanded(child: _SkeletonBlock()),
      ],
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBlock(width: 70, height: 13),
        SizedBox(width: 14),
        _SkeletonBlock(width: 62, height: 44),
        SizedBox(width: 8),
        _SkeletonBlock(width: 62, height: 44),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.jc.ink.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

String _dueMix(
  BuildContext context,
  Map<ItemType, int> counts,
  int total,
) {
  final parts = <String>[];
  final kanji = counts[ItemType.kanji] ?? 0;
  final words = counts[ItemType.word] ?? 0;
  final kana = counts[ItemType.kana] ?? 0;
  if (kanji > 0) parts.add('$kanji kanji');
  if (words > 0) parts.add('$words ${_copy(context, 'words', 'mots')}');
  if (kana > 0) parts.add('$kana kana');
  if (parts.isNotEmpty) return '${parts.join(' · ')}.';
  return total == 0
      ? _copy(context, 'Your queue is clear.', 'Votre file est à jour.')
      : _copy(context, '$total cards ready.', '$total cartes prêtes.');
}

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
