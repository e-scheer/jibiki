import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/browse_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';
import '../widgets/status_views.dart';
import '../widgets/word_tile.dart';
import 'browse_list_view.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SearchViewModel(
        ctx.read<DictionaryRepository>(),
        glossLanguage: ctx.read<AppState>().mnemonicLanguage,
      )..loadLanding(),
      child: const _SearchScreen(),
    );
  }
}

class _SearchScreen extends StatelessWidget {
  const _SearchScreen();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    return Scaffold(
      body: Column(
        children: [
          _HomeHeader(vm: vm),
          Expanded(
            child: BoundedContent(
              maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
              child: _results(context, vm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, SearchViewModel vm) {
    if (vm.hasError) {
      return ErrorRetry(message: vm.error!, onRetry: () => vm.submit(vm.query));
    }
    if (!vm.hasSearched) return _ExploreLanding(vm: vm);
    if (vm.results.isEmpty && vm.names.isEmpty && vm.isLoading) {
      return const SkeletonTileList();
    }
    if (vm.results.isEmpty && vm.names.isEmpty && !vm.isLoading) {
      return EmptyHint(
        icon: Icons.search_off_rounded,
        title: _copy(
          context,
          'No matches for "${vm.query}"',
          'Aucun résultat pour « ${vm.query} »',
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            _copy(context, 'Dictionary results', 'Résultats du dictionnaire'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        for (final word in vm.results)
          WordTile(
            word: word,
            lang: vm.glossLanguage,
            onTap: () {
              vm.rememberOpened(word);
              context.push('/word/${word.id}');
            },
          ),
        if (vm.names.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
            child: Text(
              context.trText('Names'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          for (final name in vm.names) _NameTile(name: name),
        ],
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
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
      child: ColoredBox(
        color: jc.brand,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: jc.ink, width: 3)),
          ),
          child: SafeArea(
            bottom: false,
            child: BoundedContent(
              maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.trText('jibiki'),
                          style: TextStyle(
                            color: jc.surface,
                            fontSize: 24,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Transform.rotate(
                          angle: 0.2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: jc.acid,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          streak == 1
                              ? _copy(
                                  context, 'Streak: 1 day', 'Série : 1 jour')
                              : _copy(
                                  context,
                                  'Streak: $streak days',
                                  'Série : $streak jours',
                                ),
                          style: TextStyle(
                            color: jc.surface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: jc.surface,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: jc.surface,
                        border: Border.all(color: jc.ink, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: jc.ink,
                            blurRadius: 0,
                            offset: const Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: jc.ink, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              textInputAction: TextInputAction.search,
                              style: TextStyle(
                                color: jc.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: _copy(
                                  context,
                                  'A word, kanji or romaji...',
                                  'Un mot, un kanji, du rōmaji…',
                                ),
                                hintStyle: TextStyle(
                                  color: jc.body,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: vm.onQueryChanged,
                              onSubmitted: vm.submit,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: Motion.timed(context, Motion.fast),
                            child: vm.isLoading
                                ? SizedBox.square(
                                    key: const ValueKey('search-loading'),
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: jc.ink,
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('search-idle'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreLanding extends StatelessWidget {
  const _ExploreLanding({required this.vm});

  final SearchViewModel vm;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardViewModel>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final due = _DueCard(dashboard: dashboard);
            final editorial = Column(
              children: [
                _WordOfTheDay(vm: vm),
                const SizedBox(height: 18),
                _RecentWords(vm: vm),
              ],
            );
            if (!wide) {
              return Column(
                children: [
                  due,
                  const SizedBox(height: 26),
                  editorial,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: due),
                const SizedBox(width: 26),
                Expanded(child: editorial),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          _copy(context, 'Explore', 'Explorer'),
          style: const TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _copy(
            context,
            'Browse useful vocabulary and kanji by level.',
            'Parcourez le vocabulaire et les kanji utiles par niveau.',
          ),
          style: TextStyle(
            color: context.jc.body,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _BrowseSection(
          label: _copy(context, 'Words', 'Mots'),
          children: [
            _BrowseChip(
              label: _copy(context, 'Common', 'Courants'),
              onTap: () => _open(
                context,
                const BrowseListView(
                  spec: BrowseSpec.words(title: 'Common words', common: true),
                ),
              ),
            ),
            _BrowseChip(
              label: _copy(context, 'All words', 'Tous les mots'),
              onTap: () => _open(
                context,
                const BrowseListView(
                  spec: BrowseSpec.words(title: 'All words'),
                ),
              ),
            ),
            for (final level in [5, 4, 3, 2, 1])
              _BrowseChip(
                label: 'JLPT N$level',
                onTap: () => _open(
                  context,
                  BrowseListView(
                    spec: BrowseSpec.words(
                      title: 'JLPT N$level words',
                      jlpt: level,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _BrowseSection(
          label: 'Kanji',
          children: [
            for (final level in [5, 4, 3, 2, 1])
              _BrowseChip(
                label: 'JLPT N$level',
                onTap: () => _open(
                  context,
                  BrowseListView(
                    spec: BrowseSpec.kanji(
                      title: 'JLPT N$level kanji',
                      jlpt: level,
                    ),
                  ),
                ),
              ),
            _BrowseChip(
              label: _copy(context, '部 By radical', '部 Par radical'),
              onTap: () => _open(context, const RadicalPickerView()),
            ),
          ],
        ),
      ],
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.dashboard});

  final DashboardViewModel dashboard;

  @override
  Widget build(BuildContext context) {
    final stats = dashboard.stats;
    final due = stats.dueNow;
    final minutes = due == 0 ? 2 : (due * 0.75).ceil();
    return NeoCard(
      tone: NeoTone.acid,
      shadow: 6,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                      '$due',
                      style: const TextStyle(
                        fontSize: 96,
                        height: 0.86,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      due == 0
                          ? _copy(context, 'nothing due', 'rien à réviser')
                          : _copy(context, 'to review', 'à réviser'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (stats.newRemaining > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.jc.surface,
                    border: Border.all(color: context.jc.ink, width: 2.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+ ${stats.newRemaining} '
                    '${_copy(context, 'new', 'nouvelles')}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _copy(
              context,
              '$minutes minutes, on the clock.',
              '$minutes minutes, chrono.',
            ),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _InkButton(
            label: due == 0
                ? _copy(context, 'Start learning', 'Commencer à apprendre')
                : _copy(context, 'Start the session', 'Lancer la session'),
            icon: Icons.play_arrow_rounded,
            onTap: () => context.push('/session'),
          ),
        ],
      ),
    );
  }
}

class _WordOfTheDay extends StatelessWidget {
  const _WordOfTheDay({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final word = vm.wordOfTheDay;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeoCard(
          tone: NeoTone.lavender,
          shadow: 4,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          onTap: word == null
              ? null
              : () {
                  vm.rememberOpened(word);
                  context.push('/word/${word.id}');
                },
          semanticLabel:
              word == null ? null : '${word.headword}, ${word.primaryReading}',
          child: AnimatedSwitcher(
            duration: Motion.timed(context, Motion.base),
            child: word == null
                ? _WordOfTheDaySkeleton(loading: vm.landingLoading)
                : Row(
                    key: ValueKey(word.id),
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 88),
                        child: Column(
                          children: [
                            if (word.primaryReading.isNotEmpty)
                              Text(
                                word.primaryReading,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Text(
                              word.headword,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansJP',
                                fontSize: 46,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
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
                            Text(
                              word.primaryReading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              word.summaryGloss(vm.glossLanguage),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          top: -13,
          left: 14,
          child: Transform.rotate(
            angle: -0.035,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.jc.magenta,
                border: Border.all(color: context.jc.ink, width: 2.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: context.jc.ink,
                    blurRadius: 0,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Text(
                _copy(context, 'Word of the day', 'Mot du jour'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WordOfTheDaySkeleton extends StatelessWidget {
  const _WordOfTheDaySkeleton({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return SizedBox(
        height: 70,
        child: Center(
          child: Text(
            _copy(
              context,
              'Available with a dictionary pack.',
              'Disponible avec un dictionnaire téléchargé.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return const SizedBox(
      height: 70,
      child: Row(
        children: [
          _SkeletonBlock(width: 88, height: 54),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(width: 86, height: 12),
                SizedBox(height: 9),
                _SkeletonBlock(height: 12),
                SizedBox(height: 7),
                _SkeletonBlock(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWords extends StatelessWidget {
  const _RecentWords({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final words = vm.recentWords;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final hasYesterday = words.any(
      (recent) => _sameDay(recent.viewedAt, yesterday),
    );
    final visibleWords = hasYesterday
        ? words
            .where((recent) => _sameDay(recent.viewedAt, yesterday))
            .toList(growable: false)
        : words;
    final label = hasYesterday
        ? _copy(context, 'Seen yesterday', 'Vus hier')
        : _copy(context, 'Recently seen', 'Vus récemment');

    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.jc.surface,
        border: Border.all(color: context.jc.ink, width: 3),
        borderRadius: BorderRadius.circular(14),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.timed(context, Motion.base),
              child: visibleWords.isEmpty
                  ? Align(
                      key: const ValueKey('recent-empty'),
                      alignment: Alignment.centerRight,
                      child: Text(
                        _copy(context, 'Your history starts here',
                            'Votre historique commence ici'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: context.jc.body,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      key: ValueKey(
                        visibleWords.map((e) => e.word.id).join(','),
                      ),
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (var i = 0; i < visibleWords.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            _RecentWordButton(
                              word: visibleWords[i].word,
                              onTap: () {
                                vm.rememberOpened(visibleWords[i].word);
                                context.push(
                                  '/word/${visibleWords[i].word.id}',
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWordButton extends StatelessWidget {
  const _RecentWordButton({required this.word, required this.onTap});

  final WordEntry word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: word.headword,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 92),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.jc.canvas,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          word.headword,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'NotoSansJP',
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _BrowseSection extends StatelessWidget {
  const _BrowseSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 9, children: children),
      ],
    );
  }
}

class _BrowseChip extends StatelessWidget {
  const _BrowseChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkButton extends StatelessWidget {
  const _InkButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: context.jc.ink,
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
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.jc.acid,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: context.jc.acid, size: 21),
          ],
        ),
      ),
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({required this.name});

  final NameItem name;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (name.kanji.isNotEmpty && name.reading.isNotEmpty) name.reading,
      if (name.translations.isNotEmpty) name.translations.take(3).join(', '),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: NeoListRow(
        leading: const Icon(Icons.badge_outlined, size: 22),
        title: Text(
          name.display,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: name.types.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.jc.acid,
                  border: Border.all(color: context.jc.ink, width: 2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  name.types.first.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.jc.ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
