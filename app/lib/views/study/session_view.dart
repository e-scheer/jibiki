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
import 'quiz_stage.dart';
import 'swipe_stage.dart';

/// One study session over a deck (or the global due queue), playable as swipe
/// flashcards or a multiple-choice quiz.
class SessionView extends StatelessWidget {
  const SessionView({super.key, this.deckId, this.initialMode = StudyMode.swipe, this.title});
  final String? deckId;
  final StudyMode initialMode;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ReviewViewModel(ctx.read<StudyRepository>(), deckId: deckId)..load(),
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
  late StudyMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    final lang = context.read<AppState>().mnemonicLanguage;
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.finished ? (widget.title ?? 'Study') : '${vm.reviewed + 1} of ${vm.total}'),
        actions: [
          if (!vm.finished)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ModeToggle(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
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
                        value: v, minHeight: 6, backgroundColor: jc.surfaceAlt, color: jc.brand),
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
                      duration: Motion.timed(context, Motion.fast),
                      child: _mode == StudyMode.swipe
                          ? SwipeStage(key: ValueKey('s${vm.current!.id}'), vm: vm, lang: lang)
                          : QuizStage(key: ValueKey('q${vm.current!.id}'), vm: vm, lang: lang),
                    ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final StudyMode mode;
  final ValueChanged<StudyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    Widget seg(StudyMode m, IconData icon, String label) {
      final on = mode == m;
      return Pressable(
        label: label,
        selected: on,
        haptic: false,
        onTap: () {
          Haptics.tick();
          onChanged(m);
        },
        child: AnimatedContainer(
          duration: Motion.timed(context, Motion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? jc.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Icon(icon, size: 18, color: on ? Colors.white : jc.muted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(StudyMode.swipe, Icons.style_outlined, 'Swipe cards'),
        seg(StudyMode.quiz, Icons.quiz_outlined, 'Quiz'),
      ]),
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
        ? (Icons.bolt_rounded, reviewed == 0 ? 'Ready to learn?' : 'Nice, $reviewed done',
            'More new cards are waiting whenever you are.')
        : reviewed == 0
            ? (Icons.check_rounded, 'All caught up', 'Nothing is due and no new cards are left.')
            : (Icons.done_all_rounded, 'Session complete',
                'You reviewed $reviewed ${reviewed == 1 ? "card" : "cards"}.');

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
                decoration: BoxDecoration(color: jc.brandSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 42, color: jc.brand),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: jc.muted), textAlign: TextAlign.center),
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
