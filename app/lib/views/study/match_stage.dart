import 'package:jibiki/l10n/l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../models/enums.dart';
import '../../models/study.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/review_viewmodel.dart';
import '../widgets/pressable.dart';
import 'study_feedback.dart';
import 'study_prompts.dart';

/// Memory (concentration) over a small batch of the session: every card lays down
/// two face-down tiles, its character and its meaning. Flip two at a time to find
/// the pair. Clearing the board grades the whole batch Good in one step (via
/// [ReviewViewModel.rateMany]) so the board never rebuilds mid-round.
class MatchStage extends StatefulWidget {
  const MatchStage({
    super.key,
    required this.vm,
    required this.lang,
    this.onRated,
  });
  final ReviewViewModel vm;
  final String lang;
  final void Function(List<StudyCard> cards, Rating rating)? onRated;

  @override
  State<MatchStage> createState() => _MatchStageState();
}

class _MatchStageState extends State<MatchStage> {
  late final List<StudyCard> _batch;
  late final List<_Tile> _tiles;
  final Set<int> _matched = {};
  final Set<int> _up = {}; // face-up but not yet matched (max 2)
  int? _first;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.vm.sessionCards.skip(widget.vm.index).toList();
    _batch = remaining.take(math.min(5, remaining.length)).toList();
    _tiles = [
      for (final c in _batch) ...[
        _Tile(c.id, c.front, isPrompt: true, seed: c.id + c.reps),
        _Tile(c.id, answerLabel(c, widget.lang), isPrompt: false, seed: 0),
      ],
    ]..shuffle();
  }

  int get _pairsDone => _matched.length ~/ 2;

  void _tap(int i) {
    if (_busy || _done || _matched.contains(i) || _up.contains(i)) return;
    Haptics.tick();
    setState(() => _up.add(i));
    if (_first == null) {
      _first = i;
      return;
    }
    final a = _tiles[_first!];
    final b = _tiles[i];
    final isPair = a.cardId == b.cardId && a.isPrompt != b.isPrompt;
    if (isPair) {
      Haptics.success();
      setState(() {
        _matched
          ..add(_first!)
          ..add(i);
        _up.clear();
      });
      _first = null;
      if (_matched.length == _tiles.length) _finish();
    } else {
      _busy = true;
      final second = i;
      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          _up
            ..remove(_first!)
            ..remove(second);
          _first = null;
          _busy = false;
        });
      });
    }
  }

  Future<void> _finish() async {
    _done = true;
    await Future.delayed(
        const Duration(milliseconds: 550)); // let the last pair land
    if (!mounted) return;
    widget.onRated?.call(_batch, Rating.good);
    widget.vm.rateMany(_batch, Rating.good);
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final total = _tiles.length ~/ 2;
    return WinOverlay(
      show: _done,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(context.trText('Find the pairs'),
                    style: context.text.titleMedium),
                const Spacer(),
                _PairPips(done: _pairsDone, total: total),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                context.trText(
                    'Flip two tiles to match a character with its meaning.'),
                style: TextStyle(color: jc.muted, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // More columns as the board widens (landscape / tablet) so tiles
                  // stay readable and fewer rows fit a short landscape screen.
                  final base = c.maxWidth >= Breakpoints.expanded
                      ? 4
                      : (c.maxWidth >= Breakpoints.medium ? 3 : 2);
                  final cols = base.clamp(2, _tiles.length);
                  const gap = 12.0;
                  final rows = (_tiles.length / cols).ceil();
                  final tileW = (c.maxWidth - gap * (cols - 1)) / cols;
                  final tileH = (c.maxHeight - gap * (rows - 1)) / rows;
                  return GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: tileW / tileH,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _tiles.length; i++)
                        _MatchTile(
                          tile: _tiles[i],
                          faceUp: _up.contains(i) || _matched.contains(i),
                          matched: _matched.contains(i),
                          onTap: () => _tap(i),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile {
  _Tile(this.cardId, this.text, {required this.isPrompt, required this.seed});
  final int cardId;
  final String text;
  final bool isPrompt;
  final int seed;
}

/// A dot per pair; fills vermilion as pairs are found.
class _PairPips extends StatelessWidget {
  const _PairPips({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: AnimatedContainer(
              duration: Motion.timed(context, Motion.fast),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: i < done ? jc.lime : jc.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: jc.ink, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _MatchTile extends StatefulWidget {
  const _MatchTile(
      {required this.tile,
      required this.faceUp,
      required this.matched,
      required this.onTap});
  final _Tile tile;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;

  @override
  State<_MatchTile> createState() => _MatchTileState();
}

class _MatchTileState extends State<_MatchTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.faceUp ? 1 : 0);

  @override
  void didUpdateWidget(covariant _MatchTile old) {
    super.didUpdateWidget(old);
    if (widget.faceUp != old.faceUp) {
      _c.duration = Motion.timed(context, const Duration(milliseconds: 260));
      widget.faceUp ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: widget.faceUp ? widget.tile.text : 'Hidden tile',
      haptic: false,
      pressedScale: 0.97,
      onTap: widget.matched ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final showFront = t >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(t * math.pi),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _Face(tile: widget.tile, matched: widget.matched),
                  )
                : const _Back(),
          );
        },
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      decoration: BoxDecoration(
        color: jc.lavender,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: jc.ink, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: jc.brand.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.tile, required this.matched});
  final _Tile tile;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final bg = matched ? jc.lime : jc.surface;
    final border = jc.ink;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: border, width: 2.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Stack(
        children: [
          Center(
            child: tile.isPrompt
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tile.text,
                        style: TextStyle(
                            fontFamily: JpFonts.variant(tile.seed),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: jc.ink)),
                  )
                : Text(tile.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: jc.ink,
                        height: 1.2),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
          ),
          if (matched)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.check_circle, size: 16, color: jc.ratingGood),
            ),
        ],
      ),
    );
  }
}
