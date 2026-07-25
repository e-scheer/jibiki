import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/rewards_viewmodel.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import 'collection_card_art.dart';

/// The booster opening ceremony (BOOSTER_COLLECTION_PLAN.md), tuned for the
/// tactile, premium feel of a modern TCG pack opening:
///
///  * a foil pack with real depth, a living sheen sweep and a gentle idle bob;
///  * a slash that follows the finger: the blade leaves a glowing trail across
///    the whole stage, and a glowing seam grows along the wrapper wherever the
///    stroke crosses it, with haptic ticks marking the progress;
///  * the cut takes no speed at all (a slow, deliberate glide from edge to
///    edge severs the pack just as well as a violent flick, like the Pokemon
///    TCG Pocket ritual), and the stroke's energy shapes the payoff: a calm
///    glide lets the halves drift apart softly, a fast slash sends them
///    flying with spin, gravity and a camera shake;
///  * either way the cut lands along the exact line of the swipe, at any
///    angle, edges white hot, foil sparks scattering, flash and god-rays;
///  * cards that rise on a spring and tilt in 3D under the finger (parallax),
///    the shiny carrying a moving holographic sheen, rotating rays and sparks;
///  * the shiny kept for last with a slower, darker, more spectacular beat.
///
/// Accessibility: tap-to-open is always available (a clean diagonal slash), a
/// skip button appears once a booster has been opened before, and
/// reduce-motion collapses every decorative animation to an instant, static
/// equivalent. Nothing is hidden behind the animation: the draw is applied the
/// moment the screen loads.
class BoosterOpeningView extends StatefulWidget {
  const BoosterOpeningView({super.key, required this.grantId});

  final String grantId;

  @override
  State<BoosterOpeningView> createState() => _BoosterOpeningViewState();
}

enum _Stage { pack, reveal, summary }

class _BoosterOpeningViewState extends State<BoosterOpeningView>
    with TickerProviderStateMixin {
  _Stage _stage = _Stage.pack;
  BoosterOpening? _opening;
  Object? _error;
  int _revealIndex = 0;
  // Every card lands face-down; the first tap flips it, the next advances.
  bool _cardFlipped = false;

  // The slash: one stroke across the pack cuts the wrapper clean along the
  // swipe line. Two ways to earn the cut, so the gesture never frustrates:
  // a fast Fruit Ninja flick bites as soon as it crosses half the pack, and
  // a slow, deliberate glide (Pokemon TCG Pocket style) cuts the moment it
  // reaches the far edge, no speed required. While the finger is down it
  // leaves a fading blade trail over the whole stage and a persistent glowing
  // seam across the wrapper itself.
  static const double _trailLife = .22; // seconds a trail point stays lit
  static const double _flickSpeed = 500; // px/s for the fast cut shortcut
  final List<_TrailPoint> _trail = [];
  final List<Offset> _seam = []; // the lit seam traced over the pack
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _bladeTicker = createTicker(_onBladeTick);
  _TrailPoint? _lastSample;
  Offset? _strokeEntry; // stage point where the stroke engaged the pack
  double _strokeEntryT = 0;
  int _seamTick = 0; // last haptic ratchet step along the seam
  bool _sliced = false;
  // The cut, in pack-local coordinates, extended to the wrapper's borders.
  Offset _cutA = Offset.zero;
  Offset _cutB = Offset.zero;
  // How hard the stroke hit, 0 calm glide .. 1 violent flick; shapes the
  // separation physics, the sparks and the shake.
  double _cutEnergy = .5;
  List<_Spark> _sparks = const [];
  // Where the pack sits inside the slash arena; refreshed on every layout.
  Rect _packRect = Rect.zero;

  // Continuous foil sheen + ray rotation; runs only while motion is allowed.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  // The tear burst: white flash + expanding god-rays.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  // The severed halves flying apart, and the sparks along the cut.
  late final AnimationController _split = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  @override
  void initState() {
    super.initState();
    // The draw is idempotent and applied up front; the animation is pure
    // celebration, never a gate on the actual reward.
    unawaited(_openNow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Motion.enabled(context)) _ambient.repeat();
    });
  }

  Future<void> _openNow() async {
    try {
      final opening =
          await context.read<RewardsViewModel>().openBooster(widget.grantId);
      if (mounted) setState(() => _opening = opening);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _bladeTicker.dispose();
    _ambient.dispose();
    _burst.dispose();
    _split.dispose();
    super.dispose();
  }

  double get _nowS => _clock.elapsedMicroseconds / 1e6;

  // Ages the blade trail so it fades behind the finger like a real streak.
  void _onBladeTick(Duration _) {
    final cutoff = _nowS - _trailLife;
    _trail.removeWhere((p) => p.t < cutoff);
    if (_trail.isEmpty) _bladeTicker.stop();
    if (mounted) setState(() {});
  }

  void _slashStart(Offset p) {
    final now = _nowS;
    _strokeEntry = null;
    _seam.clear();
    _lastSample = _TrailPoint(p, now);
    if (!_sliced) _feedBlade(p, now);
    if (Motion.enabled(context)) {
      _trail
        ..clear()
        ..add(_TrailPoint(p, now));
      if (!_bladeTicker.isActive) _bladeTicker.start();
      setState(() {});
    }
  }

  void _slashUpdate(Offset p) {
    final now = _nowS;
    if (!_sliced) _feedBlade(p, now);
    if (Motion.enabled(context)) {
      _trail.add(_TrailPoint(p, now));
      if (!_bladeTicker.isActive) _bladeTicker.start();
      setState(() {});
    }
  }

  void _slashEnd() {
    _strokeEntry = null;
    _lastSample = null;
    // An abandoned seam does not snap away: it lingers as the blade trail's
    // residue while that fades out.
    if (_seam.isNotEmpty) setState(_seam.clear);
  }

  // Decides whether the stroke has earned the cut. Two paths, so the gesture
  // rewards flair without demanding it: a fast flick cuts once it crosses
  // half the pack, and a calm glide cuts when it reaches the far edge.
  void _feedBlade(Offset p, double now) {
    final zone = _packRect.inflate(12);
    if (_strokeEntry == null) {
      final last = _lastSample;
      if (zone.contains(p)) {
        _strokeEntry = p;
        _strokeEntryT = now;
        _seamTick = 0;
        Haptics.tick();
      } else if (last != null && _segmentHitsRect(last.pos, p, zone)) {
        // A very fast swipe can jump clean over the pack between two samples.
        _strokeEntry = last.pos;
        _strokeEntryT = last.t;
        _seamTick = 0;
      }
    }
    _lastSample = _TrailPoint(p, now);
    final entry = _strokeEntry;
    if (entry == null) return;
    // The seam lights up the wrapper along the exact path traced so far.
    if (zone.contains(p) && Motion.enabled(context)) {
      _seam.add(p);
      if (_seam.length > 200) _seam.removeAt(0);
    }
    final chord = (p - entry).distance;
    if (chord < _packRect.width * .35) return;
    final origin = _packRect.topLeft;
    final hits = _lineRectHits(_packRect.size, entry - origin, p - entry);
    if (hits == null) return;
    final span = hits.$2 - hits.$1;
    final len = span.distance;
    if (len < 1) return;
    final u = span / len;
    final proj = _dot(p - origin - hits.$1, u);
    // A soft ratchet of haptic ticks as the seam advances across the pack.
    final step = ((proj / len).clamp(0.0, 1.0) * 6).floor();
    if (step > _seamTick) {
      _seamTick = step;
      Haptics.tick();
    }
    final dt = now - _strokeEntryT;
    final speed = dt <= 0 ? double.infinity : chord / dt;
    final flick = speed >= _flickSpeed && chord >= _packRect.width * .55;
    final traverse = proj >= len - 8;
    if (!flick && !traverse) return;
    _cutEnergy = ((speed - 350) / 1500).clamp(0.0, 1.0);
    _slice(entry, p);
  }

  // Severs the wrapper along the line through [aStage] and [bStage].
  void _slice(Offset aStage, Offset bStage) {
    if (_sliced) return;
    final origin = _packRect.topLeft;
    final hits =
        _lineRectHits(_packRect.size, aStage - origin, bStage - aStage);
    if (hits == null) return;
    _sliced = true;
    _cutA = hits.$1;
    _cutB = hits.$2;
    _strokeEntry = null;
    _seam.clear();
    Haptics.success();
    if (Motion.enabled(context)) {
      _sparks = _spawnSparks(_cutA + origin, _cutB + origin, _cutEnergy);
      // Keep the ambient controller running: it also drives the reveal's
      // back-face shimmer, idle breath and shiny rays.
      // A calm glide opens slowly and gracefully; a flick snaps apart.
      final ms = 920 - (280 * _cutEnergy).round();
      _split.duration = Duration(milliseconds: ms);
      _split.forward(from: 0);
      _burst.forward(from: 0);
      Future<void>.delayed(Duration(milliseconds: (ms * .72).round()), () {
        if (mounted) setState(() => _stage = _Stage.reveal);
      });
      setState(() {});
    } else {
      setState(() => _stage = _Stage.reveal);
    }
  }

  // Accessible fallback: a clean diagonal slash through the middle.
  void _autoSlash() {
    if (_sliced) return;
    final c = _packRect.center;
    const d = Offset(1, -.45);
    _cutEnergy = .5;
    _slice(c - d * 600, c + d * 600);
  }

  // Foil sparks scattered along the fresh cut, thrown outward on both sides;
  // a calm cut sheds a soft glitter, a flick throws a storm. Seeded by index
  // (not by a live RNG) so rebuilds never reshuffle them.
  List<_Spark> _spawnSparks(Offset a, Offset b, double energy) {
    final dir = b - a;
    final len = dir.distance;
    if (len < 1) return const [];
    final tangent = dir / len;
    final normal = Offset(-tangent.dy, tangent.dx);
    double h(int i, double salt) =>
        (math.sin(i * 127.1 + salt * 311.7) * 43758.5453).abs() % 1.0;
    final count = 16 + (18 * energy).round();
    final punch = .55 + .75 * energy;
    return List.generate(count, (i) {
      final u = (i + h(i, 1)) / count;
      final side = i.isEven ? 1.0 : -1.0;
      final speed = (90 + h(i, 2) * 260) * punch;
      return _Spark(
        pos: a + dir * u,
        vel: normal * side * speed +
            tangent * (h(i, 3) - .5) * 160 * punch +
            const Offset(0, -40),
        size: 1.5 + h(i, 4) * 2.6,
        color: switch (i % 3) {
          0 => Colors.white,
          1 => const Color(0xFFFF57A8),
          _ => const Color(0xFF9AB8FF),
        },
      );
    });
  }

  void _advanceReveal() {
    final opening = _opening;
    if (opening == null) return;
    // First tap on a face-down card flips it; the ritual is the reveal itself.
    if (!_cardFlipped) {
      final shiny = _revealIndex == opening.cards.length - 1;
      shiny ? Haptics.success() : Haptics.medium();
      setState(() => _cardFlipped = true);
      return;
    }
    // Already face-up: move to the next card, or finish.
    if (_revealIndex < opening.cards.length - 1) {
      Haptics.light();
      setState(() {
        _revealIndex += 1;
        _cardFlipped = false;
      });
    } else {
      setState(() => _stage = _Stage.summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    if (_error != null) {
      // Nothing to celebrate (already opened elsewhere, unknown id): return
      // to the previous surface rather than faking an opening.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.canPop() ? navigator.pop() : context.go('/');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    // A deep stage for the ceremony: the pack and reveals read as lit objects
    // floating in space, not flat cards on a page.
    final onStage = _stage != _Stage.summary;
    return Scaffold(
      backgroundColor: onStage ? const Color(0xFF0B0A12) : jc.canvas,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (onStage) const _StageBackdrop(),
            AnimatedSwitcher(
              duration: Motion.timed(context, Motion.base),
              child: switch (_stage) {
                _Stage.pack => _buildPack(context),
                _Stage.reveal => _buildReveal(context),
                _Stage.summary => _buildSummary(context),
              },
            ),
            // The tear burst overlays the transition into the reveal.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) => _burst.value == 0
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _BurstPainter(_burst.value),
                        size: Size.infinite,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPack(BuildContext context) {
    final l10n = context.l10n;
    final rewards = context.watch<RewardsViewModel>();
    final language = Localizations.localeOf(context).languageCode;
    final setName = rewards.activeSet?.name.resolve(language) ?? '';

    return Column(
      key: const ValueKey('pack'),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _GlassIconButton(
              icon: Icons.close_rounded,
              label: MaterialLocalizations.of(context).closeButtonTooltip,
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.canPop() ? navigator.pop() : context.go('/');
              },
            ),
          ),
        ),
        Expanded(
          // The whole stage is the slash arena: the blade trail follows the
          // finger anywhere, and the cut lands wherever the stroke crosses
          // the pack, exactly like slicing fruit.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final arena = constraints.biggest;
              final packWidth = math.min(arena.width * .58, 260.0);
              _packRect = Rect.fromCenter(
                center: arena.center(Offset.zero),
                width: packWidth,
                height: packWidth * 1.5,
              );
              final motion = Motion.enabled(context);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _slashStart(d.localPosition),
                onPanUpdate: (d) => _slashUpdate(d.localPosition),
                onPanEnd: (_) => _slashEnd(),
                onPanCancel: _slashEnd,
                onTap: _autoSlash,
                child: Semantics(
                  button: true,
                  label: l10n.boosterTapToOpen,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_ambient, _split]),
                    builder: (context, _) {
                      // A short camera shake sells the impact: barely a
                      // shiver for a calm glide, a real jolt for a flick.
                      final shake = motion && _sliced
                          ? math.sin(_split.value * math.pi * 12) *
                              (1 - _split.value) *
                              (.8 + 4.2 * _cutEnergy)
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(shake, shake * .6),
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            // What the wrapper hid: a bloom of light and card
                            // tops, blooming out of the cut as it opens.
                            if (_sliced)
                              Positioned.fromRect(
                                rect: _packRect,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: motion
                                        ? (_split.value * 2).clamp(0.0, 1.0)
                                        : 1,
                                    child: _PackInterior(
                                      open: motion ? _split.value : 1,
                                      focus: Offset(
                                        ((_cutA.dx + _cutB.dx) / 2) /
                                            _packRect.width,
                                        ((_cutA.dy + _cutB.dy) / 2) /
                                            _packRect.height,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fromRect(
                              rect: _packRect,
                              child: _SlashPack(
                                width: _packRect.width,
                                height: _packRect.height,
                                sliced: _sliced,
                                split: motion ? _split.value : 1,
                                energy: _cutEnergy,
                                cutA: _cutA,
                                cutB: _cutB,
                                sheen: motion ? _ambient.value : .25,
                                setName: setName,
                                engaged: _strokeEntry != null,
                                bladeAt: _trail.isEmpty
                                    ? null
                                    : _trail.last.pos - _packRect.topLeft,
                              ),
                            ),
                            // The seam: a persistent incandescent line along
                            // the traced path, light leaking from the foil.
                            if (!_sliced && _seam.length >= 2)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SeamPainter(
                                      points: _seam,
                                      clip: _packRect.inflate(6),
                                    ),
                                  ),
                                ),
                              ),
                            // Foil sparks fly off the cut, over the stage.
                            if (_sliced && motion)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SparksPainter(
                                      sparks: _sparks,
                                      t: _split.value,
                                    ),
                                  ),
                                ),
                              ),
                            // The blade: the finger's glowing trail.
                            if (motion)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _BladeTrailPainter(
                                      trail: _trail,
                                      now: _nowS,
                                      life: _trailLife,
                                    ),
                                  ),
                                ),
                              ),
                            // Before the first stroke, a ghost slash sweeps
                            // across the pack to teach the gesture.
                            if (motion && !_sliced && _trail.isEmpty)
                              Positioned.fromRect(
                                rect: _packRect.inflate(30),
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SlashHintPainter(
                                        phase: _ambient.value),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              _PulseHint(text: l10n.boosterSlideToOpen),
              const SizedBox(height: 8),
              if (rewards.hasOpenedBefore)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sliced = true;
                      _cardFlipped = true;
                      _stage = _Stage.summary;
                    });
                  },
                  child: Text(
                    l10n.boosterSkipAnimation,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReveal(BuildContext context) {
    final l10n = context.l10n;
    final opening = _opening;
    final rewards = context.watch<RewardsViewModel>();
    if (opening == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final drawn = opening.cards[_revealIndex];
    final card = rewards.catalog?.cardsById[drawn.cardId];
    if (card == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isShinySlot = _revealIndex == opening.cards.length - 1;
    final motion = Motion.enabled(context);

    return GestureDetector(
      key: const ValueKey('reveal'),
      behavior: HitTestBehavior.opaque,
      onTap: _advanceReveal,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < opening.cards.length; i++)
                AnimatedContainer(
                  duration: Motion.timed(context, Motion.fast),
                  width: i == _revealIndex ? 22 : 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: i <= _revealIndex
                        ? context.jc.magenta
                        : Colors.white24,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      math.min(MediaQuery.sizeOf(context).width * .72, 320),
                ),
                // Cards slide in from the right with a slight turn, like
                // flicking through a deck; the outgoing card fades as it goes.
                child: AnimatedSwitcher(
                  duration: Motion.timed(context, Motion.slow),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    if (!motion) {
                      return FadeTransition(opacity: animation, child: child);
                    }
                    return FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) {
                          final t = animation.value; // 0 → 1 as it enters
                          return Transform.translate(
                            offset: Offset((1 - t) * 90, 0),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .0012)
                                ..rotateY((1 - t) * 0.5)
                                ..scaleByDouble(
                                    0.9 + t * 0.1, 0.9 + t * 0.1, 1, 1),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.center,
                    children: [...previous, if (current != null) current],
                  ),
                  // Keyed by index only: within an index the card flips in
                  // place (back → front); a new index slides the next card in.
                  child: _RevealCard(
                    key: ValueKey('card-$_revealIndex'),
                    index: _revealIndex,
                    card: card,
                    drawn: drawn,
                    shiny: isShinySlot,
                    flipped: _cardFlipped,
                    ambient: _ambient,
                    motion: motion,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                if (motion && _cardFlipped)
                  Text(
                    l10n.boosterTiltHint,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 6),
                _PulseHint(
                  text: _cardFlipped
                      ? l10n.boosterTapToContinue
                      : l10n.boosterTapToReveal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final l10n = context.l10n;
    final opening = _opening;
    final rewards = context.watch<RewardsViewModel>();
    final set = rewards.activeSet;
    if (opening == null || set == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ownedDistinct = rewards.ownedInSet(set);
    return SingleChildScrollView(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.boosterSummaryTitle,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  NeoBadge(
                    l10n.boosterSummaryNew(opening.newCards.length),
                    tone: NeoTone.lime,
                  ),
                  if (opening.duplicateCards.isNotEmpty)
                    NeoBadge(
                      l10n.boosterSummaryDuplicates(
                          opening.duplicateCards.length),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: context.isWide ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: kCollectionCardAspect,
                children: [
                  for (final drawn in opening.cards)
                    if (rewards.catalog?.cardsById[drawn.cardId]
                        case final card?)
                      Stack(
                        children: [
                          CollectionCardFace(
                            card: card,
                            copies: drawn.countAfter,
                            dense: true,
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: NeoBadge(
                              drawn.isNew
                                  ? l10n.boosterNewCard
                                  : l10n.boosterDuplicate(drawn.countAfter),
                              tone:
                                  drawn.isNew ? NeoTone.acid : NeoTone.paper,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
              const SizedBox(height: 18),
              NeoCard(
                padding: const EdgeInsets.all(Insets.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.collectionSetProgress(
                          ownedDistinct, set.cards.length),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    NeoProgress(
                      value: set.cards.isEmpty
                          ? 0
                          : ownedDistinct / set.cards.length,
                      tone: NeoTone.magenta,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              NeoPrimaryButton(
                label: l10n.boosterGoToCollection,
                icon: Icons.grid_view_rounded,
                onTap: () => context.pushReplacement('/collection'),
              ),
              const SizedBox(height: 10),
              NeoPrimaryButton(
                label: context.trText('Done'),
                tone: NeoTone.paper,
                icon: Icons.check_rounded,
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.canPop() ? navigator.pop() : context.go('/');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── stage backdrop ───────────────────────────────────────────────────────────

/// A deep radial vignette behind the pack and reveals so lit objects pop.
class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.15),
            radius: 1.1,
            colors: [Color(0xFF241D3A), Color(0xFF0B0A12)],
          ),
        ),
      );
}

// ── the foil pack ──────────────────────────────────────────────────────────

/// The sealed pack, and its two halves once slashed. Before the cut it idles
/// with a bob and shies away from the blade gliding over it; after the cut
/// ([cutA] to [cutB], pack-local, on the wrapper's borders) the halves part
/// along the cut's normal, edges white hot. [energy] shapes the exit: near 0
/// the halves drift apart softly and settle away, near 1 they fly with spin,
/// gravity and momentum.
class _SlashPack extends StatelessWidget {
  const _SlashPack({
    required this.width,
    required this.height,
    required this.sliced,
    required this.split,
    required this.energy,
    required this.cutA,
    required this.cutB,
    required this.sheen,
    required this.setName,
    this.engaged = false,
    this.bladeAt,
  });

  final double width;
  final double height;
  final bool sliced;
  final double split; // 0..1 flight of the halves
  final double energy; // 0 calm glide .. 1 violent flick
  final Offset cutA;
  final Offset cutB;
  final double sheen; // 0..1 loop phase
  final String setName;
  final bool engaged; // a stroke is cutting: hold still under the blade
  final Offset? bladeAt; // blade position in pack coordinates, while tracing

  Widget _castShadow(double opacity) => Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .55),
                    blurRadius: 34,
                    spreadRadius: 2,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: const Color(0xFF6A4BFF).withValues(alpha: .35),
                    blurRadius: 46,
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final motion = Motion.enabled(context);

    _PackFront front() => _PackFront(
          width: width,
          height: height,
          sheen: sheen,
          setName: setName,
        );

    if (!sliced) {
      // The pack holds perfectly still while the blade is cutting it, so the
      // seam tracks the finger exactly; it only bobs and shies away from a
      // blade that is hovering nearby without having engaged the foil yet.
      final bob =
          motion && !engaged ? math.sin(sheen * math.pi * 2) * 4 : 0.0;
      var lean = 0.0;
      var dodge = Offset.zero;
      final blade = bladeAt;
      if (!engaged &&
          blade != null &&
          blade.dx > -20 &&
          blade.dx < width + 20 &&
          blade.dy > -20 &&
          blade.dy < height + 20) {
        final off = (blade.dx / width - .5).clamp(-.5, .5);
        lean = off * .06;
        dodge = Offset(off * -6, 3);
      }
      return Transform.translate(
        offset: Offset(0, bob) + dodge,
        child: Transform.rotate(
          angle: lean,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _castShadow(1),
              SizedBox(width: width, height: height, child: front()),
            ],
          ),
        ),
      );
    }

    // Cut geometry: the halves separate along the cut's normal, spin in
    // opposite directions around the cut's midpoint, and drop away. Energy
    // scales every amplitude, from a soft parting to a full send-off.
    final dir = cutB - cutA;
    final len = dir.distance;
    final tangent = len < 1 ? const Offset(1, 0) : dir / len;
    final normal = Offset(-tangent.dy, tangent.dx);
    final mid = (cutA + cutB) / 2;
    final fly = Curves.easeOutCubic.transform(split);
    final drop = split * split;
    final fade = (1 - (split - .45) / .4).clamp(0.0, 1.0);
    final glow = (1 - split * 1.6).clamp(0.0, 1.0);
    final part = width * (.16 + .38 * energy);
    final spin = .08 + .26 * energy;
    final sink = height * (.14 + .44 * energy);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _castShadow((1 - split * 2).clamp(0.0, 1.0)),
        for (final side in const [1.0, -1.0])
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: normal * side * fly * part +
                      Offset(0, drop * sink),
                  child: Transform.rotate(
                    angle: side * fly * spin,
                    origin: mid - Offset(width / 2, height / 2),
                    child: ClipPath(
                      clipper: _HalfClipper(a: cutA, b: cutB, side: side),
                      child: Stack(
                        children: [
                          SizedBox(width: width, height: height, child: front()),
                          // The freshly cut foil edge, white hot then cooling.
                          if (glow > 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CutGlowPainter(
                                    a: cutA, b: cutB, glow: glow),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The branded foil front of the pack (no tearing), rendered full-height so it
/// can be clipped into a top and a bottom half that line up seamlessly.
class _PackFront extends StatelessWidget {
  const _PackFront({
    required this.width,
    required this.height,
    required this.sheen,
    required this.setName,
  });

  final double width;
  final double height;
  final double sheen;
  final String setName;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: CustomPaint(
          // The rim is baked into the foil so it is clipped away exactly where
          // the pack is cut, instead of a full outline that survives the slice.
          painter: _FoilBodyPainter(sheen: sheen, rim: true),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _EmbossedKanji(size: width * .3),
                const SizedBox(height: 8),
                JibikiWordmark(
                  fontSize: width * .1,
                  variant: JibikiBrandVariant.negative,
                ),
                const SizedBox(height: 18),
                if (setName.isNotEmpty) _FoilSetBadge(label: setName),
              ],
            ),
          ),
        ),
      );
}

/// What's inside the pack: a white core blooming out of the cut plus a few
/// card tops, revealed as the severed halves fly apart. [focus] is the cut's
/// midpoint in normalized pack coordinates, so the light pours from the slice
/// itself wherever the blade landed.
class _PackInterior extends StatelessWidget {
  const _PackInterior({required this.open, this.focus = const Offset(.5, .2)});

  final double open; // 0..1+
  final Offset focus; // normalized (0..1, 0..1) origin of the bloom

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final t = open.clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: h * focus.dy.clamp(0.0, 1.0) - h * .35,
              height: h * .7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(focus.dx.clamp(0.0, 1.0) * 2 - 1, 0),
                    colors: [
                      Colors.white,
                      const Color(0xFFFF9AD8).withValues(alpha: .6),
                      Colors.transparent,
                    ],
                    stops: const [0, .4, 1],
                  ),
                ),
              ),
            ),
            // Card tops peeking out of the opening, fanned and rising.
            for (final (i, angle) in const [(0, -0.14), (1, 0.0), (2, 0.14)])
              Positioned(
                left: w * .16 + i * w * .01,
                right: w * .16 - i * w * .01,
                top: h * .04 - t * h * .12,
                height: h * .5,
                child: Transform.rotate(
                  angle: angle * t,
                  child: Opacity(
                    opacity: (t * 1.4 - 0.2).clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Color.lerp(Colors.white,
                                const Color(0xFF6A4BFF), .25 + i * .15)!,
                          ],
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .9),
                            width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One half of the slashed wrapper: the pack rectangle clipped to one side of
/// the infinite line through [a] and [b] (pack-local). [side] picks the side.
class _HalfClipper extends CustomClipper<Path> {
  const _HalfClipper({required this.a, required this.b, required this.side});

  final Offset a;
  final Offset b;
  final double side;

  @override
  Path getClip(Size size) {
    double s(Offset p) =>
        ((b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx)) * side;
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];
    // Half-plane clip of the rect: keep corners on this side of the cut and
    // insert the crossing points where an edge straddles it.
    final poly = <Offset>[];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final n = corners[(i + 1) % corners.length];
      final sc = s(c);
      final sn = s(n);
      if (sc >= 0) poly.add(c);
      if ((sc > 0 && sn < 0) || (sc < 0 && sn > 0)) {
        poly.add(c + (n - c) * (sc / (sc - sn)));
      }
    }
    final path = Path();
    if (poly.length < 3) return path;
    path.moveTo(poly.first.dx, poly.first.dy);
    for (final p in poly.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HalfClipper old) =>
      old.a != a || old.b != b || old.side != side;
}

/// The freshly sliced foil edge on a severed half: a hot white core over a
/// magenta bloom along the cut line, cooling off as the halves fly ([glow]).
class _CutGlowPainter extends CustomPainter {
  const _CutGlowPainter({required this.a, required this.b, required this.glow});

  final Offset a;
  final Offset b;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow <= 0) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF57A8).withValues(alpha: .55 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: glow),
    );
  }

  @override
  bool shouldRepaint(_CutGlowPainter old) =>
      old.a != a || old.b != b || old.glow != glow;
}

// ── the blade ────────────────────────────────────────────────────────────────

/// One sample of the finger's path, stamped with the stopwatch time so the
/// trail can fade on age.
class _TrailPoint {
  const _TrailPoint(this.pos, this.t);

  final Offset pos;
  final double t; // seconds on the view's stopwatch
}

/// The Fruit Ninja blade: the finger's recent path drawn as a streak that
/// tapers toward the tail and fades with age, a hot white core inside a
/// magenta bloom, with a bright glint under the fingertip.
class _BladeTrailPainter extends CustomPainter {
  const _BladeTrailPainter({
    required this.trail,
    required this.now,
    required this.life,
  });

  final List<_TrailPoint> trail;
  final double now;
  final double life;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isEmpty) return;
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()..strokeCap = StrokeCap.round;
    for (var i = 1; i < trail.length; i++) {
      final p0 = trail[i - 1];
      final p1 = trail[i];
      final age = ((now - p1.t) / life).clamp(0.0, 1.0);
      final head = i / (trail.length - 1);
      final w = (2 + 12 * head) * (1 - age);
      if (w <= .1) continue;
      glow
        ..strokeWidth = w * 2.4
        ..color = const Color(0xFFFF57A8).withValues(alpha: .45 * (1 - age));
      canvas.drawLine(p0.pos, p1.pos, glow);
      core
        ..strokeWidth = w
        ..color = Colors.white.withValues(alpha: .95 * (1 - age));
      canvas.drawLine(p0.pos, p1.pos, core);
    }
    // Hot glint under the fingertip.
    final tip = trail.last;
    final tipAge = ((now - tip.t) / life).clamp(0.0, 1.0);
    if (tipAge < 1) {
      canvas.drawCircle(
        tip.pos,
        10,
        Paint()
          ..color = Colors.white.withValues(alpha: .8 * (1 - tipAge))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        tip.pos,
        3.5,
        Paint()..color = Colors.white.withValues(alpha: 1 - tipAge),
      );
    }
  }

  @override
  bool shouldRepaint(_BladeTrailPainter old) => true; // trail mutates in place
}

/// The living seam over the wrapper while a stroke is in progress: unlike the
/// blade trail it does not fade behind the finger, it stays lit along the
/// whole traced path (Pokemon TCG Pocket style), light leaking out of the
/// foil, with a hot cutter head at the front.
class _SeamPainter extends CustomPainter {
  const _SeamPainter({required this.points, required this.clip});

  final List<Offset> points;
  final Rect clip;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(clip, const Radius.circular(Radii.lg)));
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Light leaking out of the parted foil.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFF57A8).withValues(alpha: .38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Warm inner bloom.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFC9E8).withValues(alpha: .75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // The incandescent core of the cut.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.restore();
    // The cutter head, glowing past the clip so it reads under the finger.
    final head = points.last;
    canvas.drawCircle(
      head,
      11,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: .75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(head, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SeamPainter old) => true; // seam mutates in place
}

/// Before the first stroke: a ghost blade sweeps diagonally across the pack
/// once per ambient loop, teaching the slash without a single word.
class _SlashHintPainter extends CustomPainter {
  const _SlashHintPainter({required this.phase});

  final double phase; // 0..1 ambient loop

  @override
  void paint(Canvas canvas, Size size) {
    const from = .15;
    const span = .42;
    final p = (phase - from) / span;
    if (p <= 0 || p >= 1) return;
    final a = Offset(size.width * .06, size.height * .30);
    final b = Offset(size.width * .94, size.height * .58);
    final head = Offset.lerp(a, b, Curves.easeInOut.transform(p))!;
    final tail = Offset.lerp(
        a, b, Curves.easeInOut.transform((p - .28).clamp(0.0, 1.0)))!;
    final alpha = math.sin(p * math.pi);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: .28 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      head,
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: .55 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_SlashHintPainter old) => old.phase != phase;
}

/// A foil spark thrown off the cut: a start position, a velocity, and a look.
class _Spark {
  const _Spark({
    required this.pos,
    required this.vel,
    required this.size,
    required this.color,
  });

  final Offset pos;
  final Offset vel;
  final double size;
  final Color color;
}

/// Draws the sparks ballistically from the cut: out along their velocity,
/// pulled down by gravity, shrinking and fading as the flight ends.
class _SparksPainter extends CustomPainter {
  const _SparksPainter({required this.sparks, required this.t});

  final List<_Spark> sparks;
  final double t; // 0..1 split progress

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || sparks.isEmpty) return;
    final paint = Paint()..blendMode = BlendMode.plus;
    final alpha = (1 - t).clamp(0.0, 1.0);
    for (final s in sparks) {
      final p = s.pos + s.vel * t + Offset(0, 420 * t * t);
      paint.color = s.color.withValues(alpha: alpha);
      canvas.drawCircle(p, s.size * (1 - t * .6), paint);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) =>
      old.t != t || old.sparks != sparks;
}

// ── slash geometry ───────────────────────────────────────────────────────────

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// Intersects the infinite line through [a] with direction [d] against the
/// rect (0,0)..[size], returning the two border points of the cut (ordered
/// along [d]), or null when the line misses the pack.
(Offset, Offset)? _lineRectHits(Size size, Offset a, Offset d) {
  final hits = <(double, Offset)>[];
  if (d.dx.abs() > 1e-6) {
    for (final x in [0.0, size.width]) {
      final t = (x - a.dx) / d.dx;
      final y = a.dy + d.dy * t;
      if (y >= -.5 && y <= size.height + .5) {
        hits.add((t, Offset(x, y.clamp(0.0, size.height))));
      }
    }
  }
  if (d.dy.abs() > 1e-6) {
    for (final y in [0.0, size.height]) {
      final t = (y - a.dy) / d.dy;
      final x = a.dx + d.dx * t;
      if (x >= -.5 && x <= size.width + .5) {
        hits.add((t, Offset(x.clamp(0.0, size.width), y)));
      }
    }
  }
  if (hits.length < 2) return null;
  hits.sort((p, q) => p.$1.compareTo(q.$1));
  final first = hits.first.$2;
  final last = hits.last.$2;
  if ((last - first).distance < 1) return null;
  return (first, last);
}

/// True when the segment [a]..[b] touches [r] (either endpoint inside, or the
/// segment crossing one of the rect's edges).
bool _segmentHitsRect(Offset a, Offset b, Rect r) {
  if (r.contains(a) || r.contains(b)) return true;
  final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  for (var i = 0; i < 4; i++) {
    if (_segmentsCross(a, b, corners[i], corners[(i + 1) % 4])) return true;
  }
  return false;
}

bool _segmentsCross(Offset p1, Offset p2, Offset q1, Offset q2) {
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final d1 = cross(q1, q2, p1);
  final d2 = cross(q1, q2, p2);
  final d3 = cross(p1, p2, q1);
  final d4 = cross(p1, p2, q2);
  return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
}

class _EmbossedKanji extends StatelessWidget {
  const _EmbossedKanji({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          // Emboss: a dark drop under a light glyph.
          Text(
            '辞引',
            style: TextStyle(
              fontFamily: 'NotoSansJP',
              fontSize: size,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: .35),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -1.5),
            child: Text(
              '辞引',
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: size,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: .6),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _FoilSetBadge extends StatelessWidget {
  const _FoilSetBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .55)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: .3,
          ),
        ),
      );
}

/// Paints the foil surface: a rich multi-stop gradient, a soft top highlight,
/// and a diagonal light band that travels across the pack with [sheen].
class _FoilBodyPainter extends CustomPainter {
  const _FoilBodyPainter({required this.sheen, this.rim = false});
  final double sheen;
  final bool rim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base foil.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B2E8F),
            Color(0xFF6A4BFF),
            Color(0xFFB23CC9),
            Color(0xFFFF57A8),
          ],
          stops: [0, .38, .7, 1],
        ).createShader(rect),
    );
    // Subtle holographic ribs.
    final ribs = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 5; i++) {
      final t = i / 5;
      ribs.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HSVColor.fromAHSV(0, (t * 360) % 360, .8, 1).toColor(),
          HSVColor.fromAHSV(.06, (t * 360) % 360, .8, 1).toColor(),
          HSVColor.fromAHSV(0, (t * 360) % 360, .8, 1).toColor(),
        ],
        stops: [t, (t + .1).clamp(0.0, 1.0), (t + .2).clamp(0.0, 1.0)],
      ).createShader(rect);
      canvas.drawRect(rect, ribs);
    }
    // Top glossy highlight.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: .22), Colors.transparent],
        ).createShader(rect),
    );
    // Travelling diagonal sheen band.
    final pos = sheen * (size.width + size.height) - size.height;
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(pos, 0);
    canvas.transform(Matrix4.skewX(-0.55).storage);
    final bandWidth = size.width * .32;
    final band = Rect.fromLTWH(-bandWidth / 2, -size.height,
        bandWidth, size.height * 3);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .35),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.restore();
    // Metallic rim baked into the surface: a rounded-rect stroke inset from
    // the edge. It is clipped along with the pack, so it disappears exactly
    // where the pack is cut rather than outlining a whole card.
    if (rim) {
      final r = RRect.fromRectAndRadius(
        rect.deflate(1.2),
        const Radius.circular(Radii.lg),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: .5),
      );
    }
  }

  @override
  bool shouldRepaint(_FoilBodyPainter old) =>
      old.sheen != sheen || old.rim != rim;
}

// ── the tear burst ───────────────────────────────────────────────────────────

/// Full-screen flash + expanding god-rays at the moment of tearing.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t);
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Flash: bright early, gone by ~60%.
    final flash = (1 - (t / .6)).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flash * .9),
      );
    }
    // God-rays: sweep out, brightest mid-way, fading at the end.
    final rayAlpha = (math.sin(t * math.pi)).clamp(0.0, 1.0) * .7;
    if (rayAlpha <= 0) return;
    final radius = size.longestSide * (.2 + t * .9);
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withValues(alpha: rayAlpha);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * .6);
    const count = 12;
    for (var i = 0; i < count; i++) {
      canvas.rotate(2 * math.pi / count);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(-radius * .05, -radius)
        ..lineTo(radius * .05, -radius)
        ..close();
      paint.shader = _rayShader(radius);
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

Shader _rayShader(double radius) => LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Colors.white.withValues(alpha: .0), Colors.white],
    ).createShader(Rect.fromLTWH(-radius, -radius, radius * 2, radius));

// ── rays behind the shiny ────────────────────────────────────────────────────

/// Slowly rotating radial rays behind the shiny card.
class _ShinyRaysPainter extends CustomPainter {
  const _ShinyRaysPainter({required this.phase, required this.color});
  final double phase; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide * .75;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * 2 * math.pi);
    const count = 16;
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < count; i++) {
      canvas.rotate(2 * math.pi / count);
      final wide = i.isEven ? .06 : .03;
      final alpha = i.isEven ? .22 : .1;
      paint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.topCenter,
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(-radius, -radius, radius * 2, radius));
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(-radius * wide, -radius)
        ..lineTo(radius * wide, -radius)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinyRaysPainter old) =>
      old.phase != phase || old.color != color;
}

// ── sparkles ─────────────────────────────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.phase, required this.color});
  final double phase; // 0..1
  final Color color;

  static const _seeds = [
    Offset(.14, .2), Offset(.82, .16), Offset(.68, .34), Offset(.28, .52),
    Offset(.9, .58), Offset(.1, .74), Offset(.52, .82), Offset(.74, .78),
    Offset(.4, .12), Offset(.6, .6), Offset(.2, .9), Offset(.86, .9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..color = color;
    for (var i = 0; i < _seeds.length; i++) {
      // Each sparkle twinkles on its own offset phase.
      final local = (phase + i / _seeds.length) % 1.0;
      final twinkle = math.sin(local * math.pi * 2).clamp(0.0, 1.0);
      if (twinkle <= 0.02) continue;
      final c = Offset(_seeds[i].dx * size.width, _seeds[i].dy * size.height);
      final r = (2.0 + (i % 3)) * twinkle;
      paint.color = color.withValues(alpha: twinkle);
      // A four-point star: two crossed lozenges.
      final path = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..lineTo(c.dx + r * .6, c.dy)
        ..lineTo(c.dx, c.dy + r * 2)
        ..lineTo(c.dx - r * .6, c.dy)
        ..close()
        ..moveTo(c.dx - r * 2, c.dy)
        ..lineTo(c.dx, c.dy + r * .6)
        ..lineTo(c.dx + r * 2, c.dy)
        ..lineTo(c.dx, c.dy - r * .6)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.phase != phase || old.color != color;
}

// ── holographic overlay ──────────────────────────────────────────────────────

/// A tilt-reactive sheen laid over a card: a moving glare for every card, plus
/// a rainbow holo wash for shiny cards. Driven by the parallax tilt so the
/// light appears to slide across the foil as the card turns.
class _HoloPainter extends CustomPainter {
  const _HoloPainter({
    required this.tiltX,
    required this.tiltY,
    required this.rainbow,
  });

  final double tiltX; // -1..1
  final double tiltY; // -1..1
  final bool rainbow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rainbow) {
      // Rainbow wash sliding with horizontal tilt.
      final shift = tiltY * .5;
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            transform: GradientRotation(tiltX * .4),
            colors: [
              const HSVColor.fromAHSV(.0, 0, .9, 1).toColor(),
              HSVColor.fromAHSV(.22, ((shift + .0) * 360) % 360, .9, 1)
                  .toColor(),
              HSVColor.fromAHSV(.22, ((shift + .33) * 360) % 360, .9, 1)
                  .toColor(),
              HSVColor.fromAHSV(.22, ((shift + .66) * 360) % 360, .9, 1)
                  .toColor(),
              const HSVColor.fromAHSV(.0, 0, .9, 1).toColor(),
            ],
            stops: const [0, .25, .5, .75, 1],
          ).createShader(rect),
      );
    }
    // Glare streak that tracks the tilt for every card.
    final gx = (tiltY * .5 + .5).clamp(0.0, 1.0);
    final gy = (tiltX * .5 + .5).clamp(0.0, 1.0);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(gx * 2 - 1, gy * 2 - 1),
          radius: .9,
          colors: [
            Colors.white.withValues(alpha: rainbow ? .32 : .18),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HoloPainter old) =>
      old.tiltX != tiltX || old.tiltY != tiltY || old.rainbow != rainbow;
}

// ── parallax tilt ────────────────────────────────────────────────────────────

/// Wraps a card in a 3D tilt that follows the finger and springs back on
/// release. The [builder] receives the current tilt so an overlay can react.
class _TiltCard extends StatefulWidget {
  const _TiltCard({required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(BuildContext, double tiltX, double tiltY) builder;

  @override
  State<_TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<_TiltCard> {
  // Target tilt in radians; -x when dragging up, etc.
  double _tx = 0;
  double _ty = 0;
  bool _dragging = false;

  static const _max = 0.28;

  void _update(DragUpdateDetails d, Size size) {
    setState(() {
      _dragging = true;
      _ty = (_ty + d.delta.dx / size.width).clamp(-_max, _max);
      _tx = (_tx - d.delta.dy / size.height).clamp(-_max, _max);
    });
  }

  void _release() => setState(() {
        _dragging = false;
        _tx = 0;
        _ty = 0;
      });

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, 0, 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onPanUpdate: (d) => _update(d, size),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: Offset(_tx, _ty)),
            // Follow closely while dragging, spring back on release.
            duration: _dragging
                ? const Duration(milliseconds: 90)
                : const Duration(milliseconds: 520),
            curve: _dragging ? Curves.easeOut : Curves.elasticOut,
            builder: (context, t, _) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(t.dx)
                ..rotateY(t.dy),
              child: widget.builder(context, t.dx / _max, t.dy / _max),
            ),
          ),
        );
      },
    );
  }
}

// ── the reveal card (face-down, flips on tap) ────────────────────────────────

/// One card in the reveal ritual: it arrives face-down and flips to its front
/// when [flipped] turns true. The front carries the tilt-reactive holo, a
/// rarity glow, an idle breath, and (for shiny or new cards) rays and sparks.
/// Per-card timing and lean vary so the sequence never feels mechanical.
class _RevealCard extends StatefulWidget {
  const _RevealCard({
    super.key,
    required this.index,
    required this.card,
    required this.drawn,
    required this.shiny,
    required this.flipped,
    required this.ambient,
    required this.motion,
  });

  final int index;
  final CollectionCardDef card;
  final DrawnCard drawn;
  final bool shiny;
  final bool flipped;
  final Animation<double> ambient;
  final bool motion;

  @override
  State<_RevealCard> createState() => _RevealCardState();
}

class _RevealCardState extends State<_RevealCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    // Slight per-card variation so reveals are not mechanically identical.
    duration: Duration(milliseconds: 460 + (widget.index * 53) % 200),
    value: widget.flipped ? 1 : 0,
  );

  // A tiny fixed lean unique to each card.
  late final double _seedLean = ((widget.index * 37) % 7 - 3) * 0.006;

  @override
  void didUpdateWidget(_RevealCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped == old.flipped) return;
    if (!widget.motion) {
      _flip.value = widget.flipped ? 1 : 0;
    } else {
      _flip.animateTo(widget.flipped ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final jc = context.jc;
    final motion = widget.motion;
    final shiny = widget.shiny;
    final drawn = widget.drawn;
    final celebrate = shiny || drawn.isNew;

    final tilt = _TiltCard(
      enabled: motion,
      builder: (context, tx, ty) => AnimatedBuilder(
        animation: Listenable.merge([_flip, widget.ambient]),
        builder: (context, _) {
          final angle = _flip.value * math.pi;
          final front = angle > math.pi / 2;
          // Idle breath once revealed.
          final breath = motion && widget.flipped
              ? 1 + math.sin(widget.ambient.value * math.pi * 2) * 0.012
              : 1.0;
          final glare = math.sin(_flip.value * math.pi); // peaks edge-on

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateZ(_seedLean)
              ..rotateY(angle)
              ..scaleByDouble(breath, breath, 1, 1),
            child: Stack(
              children: [
                Transform(
                  alignment: Alignment.center,
                  // The plane is mirrored once past 90°, so counter-rotate the
                  // front to keep it readable; the back reads straight at 0°.
                  transform: Matrix4.identity()..rotateY(front ? math.pi : 0),
                  child: front
                      ? _CardFront(
                          card: widget.card,
                          shiny: shiny,
                          tiltX: tx,
                          tiltY: ty,
                        )
                      : _RevealCardBack(shiny: shiny, ambient: widget.ambient),
                ),
                if (glare > 0.02)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: glare * .5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.md),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0x00FFFFFF),
                                Color(0x66FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                              stops: [.3, .5, .7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (shiny && motion && widget.flipped)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: widget.ambient,
                      builder: (context, _) => CustomPaint(
                        painter: _ShinyRaysPainter(
                            phase: widget.ambient.value, color: jc.acid),
                      ),
                    ),
                  ),
                ),
              tilt,
              // Sparkles greet every newly obtained card, brightest for shiny.
              if (celebrate && motion && widget.flipped)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: widget.ambient,
                      builder: (context, _) => Opacity(
                        opacity: shiny ? 1 : .6,
                        child: CustomPaint(
                          painter: _SparklePainter(
                              phase: widget.ambient.value,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // The label stays hidden until the card is revealed (mystery first).
        AnimatedOpacity(
          duration: Motion.timed(context, Motion.fast),
          opacity: widget.flipped ? 1 : 0,
          child: NeoBadge(
            drawn.isNew
                ? l10n.boosterNewCard
                : l10n.boosterDuplicate(drawn.countAfter),
            tone: drawn.isNew
                ? (shiny ? NeoTone.magenta : NeoTone.acid)
                : NeoTone.paper,
          ),
        ),
      ],
    );
  }
}

/// The revealed front: rarity glow + card face + tilt-reactive holo.
class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.shiny,
    required this.tiltX,
    required this.tiltY,
  });

  final CollectionCardDef card;
  final bool shiny;
  final double tiltX;
  final double tiltY;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return AspectRatio(
      aspectRatio: kCollectionCardAspect,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: [
                    BoxShadow(
                      color: (shiny ? jc.magenta : jc.brand)
                          .withValues(alpha: shiny ? .6 : .3),
                      blurRadius: shiny ? 40 : 22,
                      spreadRadius: shiny ? 4 : 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CollectionCardFace(card: card)),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: CustomPaint(
                  painter:
                      _HoloPainter(tiltX: tiltX, tiltY: tiltY, rainbow: shiny),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The face-down back of a card: a foil panel with a travelling sheen and a
/// centered mark. The shiny back glows and pulses to build anticipation.
class _RevealCardBack extends StatelessWidget {
  const _RevealCardBack({required this.shiny, required this.ambient});

  final bool shiny;
  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.enabled(context);
    final phase = motion ? ambient.value : .25;
    final glow = motion && shiny
        ? 12 + math.sin(ambient.value * math.pi * 2) * 10
        : (shiny ? 12.0 : 0.0);
    return AspectRatio(
      aspectRatio: kCollectionCardAspect,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: shiny
                ? Colors.white.withValues(alpha: .6)
                : Colors.white.withValues(alpha: .35),
            width: shiny ? 2 : 1.5,
          ),
          boxShadow: [
            if (shiny)
              BoxShadow(
                color: const Color(0xFFFF57A8).withValues(alpha: .55),
                blurRadius: glow,
                spreadRadius: glow / 4,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: CustomPaint(
            painter: _FoilBodyPainter(sheen: phase),
            child: Center(
              child: shiny
                  ? Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white.withValues(alpha: .95),
                      size: 58,
                      shadows: const [Shadow(color: Colors.white, blurRadius: 18)],
                    )
                  : Text(
                      '辞引',
                      style: TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: .85),
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: .4),
                            blurRadius: 10,
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

// ── small chrome ─────────────────────────────────────────────────────────────

/// A translucent icon button that reads on the dark ceremony stage.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () {
            Haptics.tick();
            onTap();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );
}

/// A gently pulsing prompt on the dark stage.
class _PulseHint extends StatefulWidget {
  const _PulseHint({required this.text});
  final String text;

  @override
  State<_PulseHint> createState() => _PulseHintState();
}

class _PulseHintState extends State<_PulseHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Motion.enabled(context)) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    );
    if (!Motion.enabled(context)) return text;
    return FadeTransition(
      opacity: Tween(begin: .5, end: 1.0).animate(_c),
      child: text,
    );
  }
}
