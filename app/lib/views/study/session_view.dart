import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/enums.dart';
import '../../models/study.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/status_views.dart';
import 'listen_stage.dart';
import 'match_stage.dart';
import 'quiz_stage.dart';
import 'study_chrome.dart';
import 'swipe_stage.dart';

IconData _modeIcon(StudyMode mode) => switch (mode) {
      StudyMode.swipe => Icons.swipe_rounded,
      StudyMode.quiz => Icons.quiz_outlined,
      StudyMode.match => Icons.grid_view_rounded,
      StudyMode.listen => Icons.hearing_rounded,
    };

class SessionView extends StatelessWidget {
  const SessionView({
    super.key,
    this.deckId,
    this.initialMode = StudyMode.swipe,
    this.title,
  });

  final String? deckId;
  final StudyMode initialMode;
  final String? title;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) =>
            ReviewViewModel(ctx.read<StudyRepository>(), deckId: deckId)
              ..load(),
        child: _Session(initialMode: initialMode, title: title),
      );
}

class _Session extends StatefulWidget {
  const _Session({required this.initialMode, this.title});

  final StudyMode initialMode;
  final String? title;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  late StudyMode _mode;
  final List<_SessionResult> _results = [];
  final DateTime _startedAt = DateTime.now();
  StudyDirection _direction = StudyDirection.recognize;

  @override
  void initState() {
    super.initState();
    final remembered = context.read<AppState>().studyMode;
    _mode =
        widget.initialMode != StudyMode.swipe ? widget.initialMode : remembered;
  }

  void _pick(StudyMode mode) {
    if (_mode == mode) return;
    Haptics.tick();
    setState(() => _mode = mode);
    context.read<AppState>().setStudyMode(mode);
  }

  void _toggleDirection() {
    Haptics.tick();
    setState(() {
      _direction = _direction.isRecall
          ? StudyDirection.recognize
          : StudyDirection.recall;
    });
  }

  void _record(StudyCard card, Rating rating) {
    if (_results.any((result) => result.card.id == card.id)) return;
    _results.add(_SessionResult(card, rating));
  }

  void _recordMany(List<StudyCard> cards, Rating rating) {
    for (final card in cards) {
      _record(card, rating);
    }
  }

  void _openCurrentDetail(ReviewViewModel vm) {
    final card = vm.current;
    if (card == null) return;
    final path = switch (card.itemType) {
      ItemType.word => '/word/${card.itemRef}',
      ItemType.kanji => '/kanji/${card.itemRef}',
      ItemType.kana => '/kana/${card.itemRef}',
    };
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    final lang = context.read<AppState>().mnemonicLanguage;

    return Scaffold(
      backgroundColor: context.jc.lavender,
      body: vm.isLoading && vm.total == 0
          ? const LoadingView()
          : vm.hasError && vm.total == 0
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : vm.finished
                  ? _Summary(
                      title: widget.title,
                      reviewed: vm.reviewed,
                      results: _results,
                      elapsed: DateTime.now().difference(_startedAt),
                      hasMore: vm.hasMoreNew,
                      loadingMore: vm.loadingMore,
                      onMore: vm.studyMore,
                      onDone: () => context.pop(),
                    )
                  : Column(
                      children: [
                        _SessionHeader(
                          current: vm.reviewed + 1,
                          total: vm.total,
                          progress: vm.progress,
                          mode: _mode,
                          direction: _direction,
                          onClose: () => context.pop(),
                          onMode: _pick,
                          onDirection: _toggleDirection,
                          onDetails: () => _openCurrentDetail(vm),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Motion.timed(context, Motion.base),
                            switchInCurve: Motion.outStrong,
                            switchOutCurve: Motion.out,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.035),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: switch (_mode) {
                              StudyMode.swipe => SwipeStage(
                                  key: ValueKey('s${vm.current!.id}'),
                                  vm: vm,
                                  lang: lang,
                                  onRated: _record,
                                ),
                              StudyMode.quiz => QuizStage(
                                  key: ValueKey(
                                    'q${vm.current!.id}-${_direction.name}',
                                  ),
                                  vm: vm,
                                  lang: lang,
                                  direction: _direction,
                                  onRated: _record,
                                ),
                              StudyMode.match => MatchStage(
                                  key: ValueKey('m${vm.current!.id}'),
                                  vm: vm,
                                  lang: lang,
                                  onRated: _recordMany,
                                ),
                              StudyMode.listen => ListenStage(
                                  key: ValueKey('l${vm.current!.id}'),
                                  vm: vm,
                                  lang: lang,
                                  onRated: _record,
                                ),
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.current,
    required this.total,
    required this.progress,
    required this.mode,
    required this.direction,
    required this.onClose,
    required this.onMode,
    required this.onDirection,
    required this.onDetails,
  });

  final int current;
  final int total;
  final double progress;
  final StudyMode mode;
  final StudyDirection direction;
  final VoidCallback onClose;
  final ValueChanged<StudyMode> onMode;
  final VoidCallback onDirection;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final left = (total - current).clamp(0, total);
    return SafeArea(
      bottom: false,
      child: BoundedContent(
        maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$current'),
                              TextSpan(
                                text: ' / $total',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: context.jc.ink,
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            height: 0.96,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          left == 0
                              ? context.trText('Last card. Finish strong.')
                              : context.trText('$left left. Keep the rhythm.'),
                          style: TextStyle(
                            color: context.jc.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox.square(
                    dimension: 44,
                    child: Pressable(
                      label: context.trText('Close'),
                      onTap: onClose,
                      child: StudyPanel(
                        shadow: 4,
                        radius: 10,
                        padding: EdgeInsets.zero,
                        child: Icon(Icons.close_rounded, color: context.jc.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StudyProgressRail(value: progress),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _ModeSwitcher(
                      selected: mode,
                      onSelected: onMode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (mode == StudyMode.quiz) ...[
                    _MiniAction(
                      label: context.trText(direction.label),
                      icon: Icons.swap_horiz_rounded,
                      selected: direction.isRecall,
                      onTap: onDirection,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _MiniAction(
                    label: context.trText('Open full details'),
                    icon: Icons.menu_book_outlined,
                    onTap: onDetails,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.selected, required this.onSelected});

  final StudyMode selected;
  final ValueChanged<StudyMode> onSelected;

  @override
  Widget build(BuildContext context) => StudyPanel(
        radius: 12,
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final mode in StudyMode.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _ModeItem(
                    mode: mode,
                    selected: mode == selected,
                    onTap: () => onSelected(mode),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final StudyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        label: context.trText(mode.label),
        selected: selected,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.timed(context, Motion.fast),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? context.jc.acid : context.jc.surface,
            borderRadius: BorderRadius.circular(8),
            border:
                selected ? Border.all(color: context.jc.ink, width: 2) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.jc.ink,
                      blurRadius: 0,
                      offset: const Offset(2, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(_modeIcon(mode), size: 19, color: context.jc.ink),
        ),
      );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 48,
        child: Pressable(
          label: label,
          selected: selected,
          onTap: onTap,
          child: StudyPanel(
            color: selected ? context.jc.acid : context.jc.surface,
            radius: 10,
            padding: EdgeInsets.zero,
            child: Icon(icon, size: 20, color: context.jc.ink),
          ),
        ),
      );
}

class _SessionResult {
  const _SessionResult(this.card, this.rating);

  final StudyCard card;
  final Rating rating;
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.title,
    required this.reviewed,
    required this.results,
    required this.elapsed,
    required this.hasMore,
    required this.loadingMore,
    required this.onMore,
    required this.onDone,
  });

  final String? title;
  final int reviewed;
  final List<_SessionResult> results;
  final Duration elapsed;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onMore;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final successful = results
        .where((result) =>
            result.rating == Rating.good || result.rating == Rating.easy)
        .length;
    final accuracy =
        results.isEmpty ? 0 : (successful / results.length * 100).round();
    final revisit = results
        .where((result) =>
            result.rating == Rating.again || result.rating == Rating.hard)
        .take(3)
        .toList();
    final minutes = elapsed.inMinutes.clamp(1, 999);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.isExpanded ? 28 : 18,
            22,
            context.isExpanded ? 28 : 18,
            20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isExpanded ? 760 : 540,
                minHeight: viewport.maxHeight - 42,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.trText(
                      '${title ?? 'Study'} · $reviewed cards · $minutes min',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.trText('Session complete.'),
                    style: context.text.headlineMedium?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      StudyPanel(
                        shadow: 8,
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$accuracy%',
                              style: TextStyle(
                                color: context.jc.ink,
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2.5,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.trText('accuracy'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 13),
                            StudyProgressRail(
                              value: accuracy / 100,
                              animate: true,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              context.trText(
                                '$successful on the first try, ${results.length - successful} to revisit.',
                              ),
                              style: TextStyle(
                                color: context.jc.body,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -19,
                        right: -4,
                        child: StudySticker('$reviewed/$reviewed', large: true),
                      ),
                      const Positioned(
                        top: -62,
                        right: -5,
                        child: IgnorePointer(child: StudyConfetti()),
                      ),
                    ],
                  ),
                  if (revisit.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      context.trText('${revisit.length} cards return soon'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < revisit.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _RevisitRow(result: revisit[i]),
                    ],
                  ],
                  const SizedBox(height: 18),
                  Text(
                    hasMore
                        ? context.trText(
                            'More new cards are ready whenever you want to keep going.',
                          )
                        : context.trText(
                            'Your next batch will be ready tomorrow. Nice work.',
                          ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (hasMore) ...[
                    StudyActionButton(
                      label: context.trText('Study more'),
                      icon: Icons.add_rounded,
                      color: context.jc.ink,
                      foreground: context.jc.acid,
                      busy: loadingMore,
                      onTap: onMore,
                    ),
                    const SizedBox(height: 10),
                  ],
                  StudyActionButton(
                    label: context.trText('Back to packs'),
                    color: context.jc.surface,
                    onTap: onDone,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevisitRow extends StatelessWidget {
  const _RevisitRow({required this.result});

  final _SessionResult result;

  @override
  Widget build(BuildContext context) {
    final card = result.card;
    return StudyPanel(
      radius: 11,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            card.front,
            style: TextStyle(
              fontFamily: JpFonts.variant(card.id + card.reps),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                card.reading,
                card.meaning(Localizations.localeOf(context).languageCode)
              ].where((value) => value.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.jc.body,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.jc.acid,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: context.jc.ink, width: 2),
            ),
            child: Text(
              context.trText(
                result.rating == Rating.again ? '10 min' : 'tomorrow',
              ),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
