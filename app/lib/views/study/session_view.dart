import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import '../widgets/status_views.dart';
import 'listen_stage.dart';
import 'match_stage.dart';
import 'quiz_stage.dart';
import 'swipe_stage.dart';

IconData _modeIcon(StudyMode m) => switch (m) {
      StudyMode.swipe => Icons.swipe_rounded,
      StudyMode.quiz => Icons.quiz_outlined,
      StudyMode.match => Icons.grid_view_rounded,
      StudyMode.listen => Icons.hearing_rounded,
    };

/// One study session over a deck (or the global due queue), playable as swipe
/// flashcards or a multiple-choice quiz.
class SessionView extends StatelessWidget {
  const SessionView(
      {super.key, this.deckId, this.initialMode = StudyMode.swipe, this.title});
  final String? deckId;
  final StudyMode initialMode;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          ReviewViewModel(ctx.read<StudyRepository>(), deckId: deckId)..load(),
      child: _Session(initialMode: initialMode, title: title),
    );
  }
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

  @override
  void initState() {
    super.initState();
    // Resume the last game the learner chose; an explicit ?mode= deep link wins.
    final remembered = context.read<AppState>().studyMode;
    _mode =
        widget.initialMode != StudyMode.swipe ? widget.initialMode : remembered;
  }

  StudyDirection _direction = StudyDirection.recognize;

  void _pick(StudyMode m) {
    setState(() => _mode = m);
    context.read<AppState>().setStudyMode(m);
  }

  void _toggleDirection() => setState(() => _direction =
      _direction.isRecall ? StudyDirection.recognize : StudyDirection.recall);

  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<StudyMode>(
      context: context,
      builder: (_) => _GamePickerSheet(current: _mode),
    );
    if (picked != null) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    final lang = context.read<AppState>().mnemonicLanguage;
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.finished
            ? (widget.title ?? 'Study')
            : '${vm.reviewed + 1} of ${vm.total}'),
        actions: [
          // Recognize ↔ recall toggle. Quiz is the game that supports both
          // directions (produce the meaning, or produce the Japanese).
          if (!vm.finished && _mode == StudyMode.quiz)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Direction: ${_direction.label}',
              isSelected: _direction.isRecall,
              onPressed: _toggleDirection,
            ),
          if (!vm.finished)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _GameButton(mode: _mode, onTap: _openPicker),
            ),
        ],
        bottom: vm.total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: vm.progress),
                      duration: Motion.timed(context, Motion.base),
                      curve: Motion.out,
                      builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: jc.surfaceAlt,
                          color: jc.brand),
                    ),
                  ),
                ),
              ),
      ),
      body: vm.isLoading && vm.total == 0
          ? const LoadingView()
          : vm.hasError && vm.total == 0
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : vm.finished
                  ? _Summary(
                      reviewed: vm.reviewed,
                      hasMore: vm.hasMoreNew,
                      loadingMore: vm.loadingMore,
                      onMore: vm.studyMore,
                      onDone: () => context.pop(),
                    )
                  : AnimatedSwitcher(
                      duration: Motion.timed(context, Motion.base),
                      switchInCurve: Motion.outStrong,
                      switchOutCurve: Motion.out,
                      // Each card rises into place as the last one clears, so
                      // advancing reads as a deliberate hand-off, not an abrupt
                      // swap that leaves you unsure anything happened.
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (_mode) {
                        StudyMode.swipe => SwipeStage(
                            key: ValueKey('s${vm.current!.id}'),
                            vm: vm,
                            lang: lang),
                        StudyMode.quiz => QuizStage(
                            key: ValueKey('q${vm.current!.id}-${_direction.name}'),
                            vm: vm,
                            lang: lang,
                            direction: _direction),
                        StudyMode.match => MatchStage(
                            key: ValueKey('m${vm.current!.id}'),
                            vm: vm,
                            lang: lang),
                        StudyMode.listen => ListenStage(
                            key: ValueKey('l${vm.current!.id}'),
                            vm: vm,
                            lang: lang),
                      },
                    ),
    );
  }
}

/// The current game, tapped to open the picker. One control that scales to any
/// number of games, instead of a segmented toggle that runs out of room.
class _GameButton extends StatelessWidget {
  const _GameButton({required this.mode, required this.onTap});
  final StudyMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: 'Game: ${mode.label}. Change game',
      haptic: false,
      onTap: () {
        Haptics.tick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
            color: jc.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_modeIcon(mode), size: 17, color: jc.brand),
            const SizedBox(width: 6),
            Text(mode.label,
                style: TextStyle(
                    color: jc.ink, fontWeight: FontWeight.w700, fontSize: 13)),
            Icon(Icons.expand_more_rounded, size: 18, color: jc.muted),
          ],
        ),
      ),
    );
  }
}

/// The game picker: each game as a row with its icon, name and what you do in it.
class _GamePickerSheet extends StatelessWidget {
  const _GamePickerSheet({required this.current});
  final StudyMode current;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: jc.hairline,
                    borderRadius: BorderRadius.circular(Radii.pill)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 12),
              child: Text('Choose a game', style: context.text.titleLarge),
            ),
            for (final m in StudyMode.values)
              _GameRow(
                  mode: m,
                  selected: m == current,
                  onTap: () => Navigator.pop(context, m)),
          ],
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow(
      {required this.mode, required this.selected, required this.onTap});
  final StudyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        label: mode.label,
        selected: selected,
        haptic: false,
        pressedScale: 0.98,
        onTap: () {
          Haptics.tick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? jc.brandSoft : jc.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
                color:
                    selected ? jc.brand.withValues(alpha: 0.5) : jc.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? jc.brand : jc.brandSoft,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: Icon(_modeIcon(mode),
                    size: 22, color: selected ? Colors.white : jc.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.label, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(mode.blurb,
                        style: TextStyle(
                            color: jc.muted, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_circle_rounded, color: jc.brand, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.reviewed,
    required this.hasMore,
    required this.loadingMore,
    required this.onMore,
    required this.onDone,
  });
  final int reviewed;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onMore;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // Three honest states, but never a dead-end: whenever new cards remain, the
    // primary action keeps you studying instead of announcing "done for today".
    final (IconData icon, String title, String subtitle) = hasMore
        ? (
            Icons.bolt_rounded,
            reviewed == 0 ? 'Ready to learn?' : 'Nice, $reviewed done',
            'More new cards are waiting whenever you are.'
          )
        : reviewed == 0
            ? (
                Icons.check_rounded,
                'All caught up',
                'Nothing is due and no new cards are left.'
              )
            : (
                Icons.done_all_rounded,
                'Session complete',
                'You reviewed $reviewed ${reviewed == 1 ? "card" : "cards"}.'
              );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: Motion.timed(context, Motion.slow),
              curve: Motion.outStrong,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration:
                    BoxDecoration(color: jc.brandSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 42, color: jc.brand),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(color: jc.muted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (hasMore) ...[
              FilledButton(
                onPressed: loadingMore
                    ? null
                    : () {
                        Haptics.light();
                        onMore();
                      },
                child: loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Study more'),
              ),
              const SizedBox(height: 6),
              TextButton(onPressed: onDone, child: const Text('Done for now')),
            ] else
              FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
