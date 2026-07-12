import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../community/community_decks_view.dart';
import '../dictionary/search_view.dart';
import '../kana/kana_chart_view.dart';
import '../study/decks_view.dart';
import '../study/statistics_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardViewModel(ctx.read<StudyRepository>())..load(),
      child: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static const _reviewIndex = 2;
  static const _tabs = [
    SearchView(),
    KanaChartView(),
    DecksView(),
    CommunityDecksView(),
    StatisticsView(),
  ];
  static const _destinations = [
    _Destination(_NavGlyphKind.book, 'Dico', 'Dico'),
    _Destination(_NavGlyphKind.kana, 'Kana', 'Kana'),
    _Destination(_NavGlyphKind.review, 'Review', 'Réviser'),
    _Destination(_NavGlyphKind.community, 'Community', 'Communauté'),
    _Destination(_NavGlyphKind.profile, 'Profile', 'Profil'),
  ];

  int _index = 0;
  bool _initialised = false;
  PageController? _pager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _index = context.read<AppState>().mode.showsReviewFirst ? _reviewIndex : 0;
    _pager = PageController(initialPage: _index);
    _initialised = true;
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index == _index) return;
    final pager = _pager;
    if (context.win.isCompact && pager != null && pager.hasClients) {
      if (Motion.enabled(context)) {
        pager.animateToPage(
          index,
          duration: Motion.timed(context, Motion.base),
          curve: Motion.outStrong,
        );
      } else {
        pager.jumpToPage(index);
      }
    } else {
      _onPageSettled(index);
    }
  }

  void _onPageSettled(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    if (index == _reviewIndex) context.read<DashboardViewModel>().load();
  }

  void _syncPager() {
    final pager = _pager;
    if (pager == null || !pager.hasClients) return;
    if ((pager.page?.round() ?? _index) != _index) pager.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;
    final due = context.watch<DashboardViewModel>().stats.dueNow;
    final showDue = mode.showsDueBadge && due > 0;

    if (context.win.isCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPager();
      });
      return Scaffold(
        body: PageView(
          controller: _pager,
          onPageChanged: _onPageSettled,
          physics: const _SnappyPageScrollPhysics(),
          children: [for (final tab in _tabs) _KeepAlive(child: tab)],
        ),
        bottomNavigationBar: _NeoBottomNavigation(
          index: _index,
          due: showDue ? due : 0,
          destinations: _destinations,
          onSelect: _go,
        ),
      );
    }

    final extended = context.win == WindowSize.expanded;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _NeoNavigationRail(
              index: _index,
              due: showDue ? due : 0,
              extended: extended,
              destinations: _destinations,
              onSelect: _go,
            ),
            Expanded(child: IndexedStack(index: _index, children: _tabs)),
          ],
        ),
      ),
    );
  }
}

class _NeoBottomNavigation extends StatelessWidget {
  const _NeoBottomNavigation({
    required this.index,
    required this.due,
    required this.destinations,
    required this.onSelect,
  });

  final int index;
  final int due;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border(top: BorderSide(color: context.jc.ink, width: 3)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _NeoNavButton(
                        destination: destinations[i],
                        selected: index == i,
                        due: i == _ShellState._reviewIndex ? due : 0,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoNavigationRail extends StatelessWidget {
  const _NeoNavigationRail({
    required this.index,
    required this.due,
    required this.extended,
    required this.destinations,
    required this.onSelect,
  });

  final int index;
  final int due;
  final bool extended;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return RepaintBoundary(
      child: Container(
        width: extended ? 224 : 88,
        decoration: BoxDecoration(
          color: jc.surface,
          border: Border(right: BorderSide(color: jc.ink, width: 3)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              extended ? 16 : 10,
              18,
              extended ? 16 : 10,
              18,
            ),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RailBrand(extended: extended),
                  const SizedBox(height: 34),
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    SizedBox(
                      height: 58,
                      child: _NeoNavButton(
                        destination: destinations[i],
                        selected: index == i,
                        due: i == _ShellState._reviewIndex ? due : 0,
                        horizontal: extended,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          extended ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        if (!extended)
          Text(
            '字',
            style: TextStyle(
              color: context.jc.brand,
              fontFamily: 'NotoSansJP',
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          )
        else ...[
          Text(
            context.trText('jibiki'),
            style: const TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 6),
          Transform.rotate(
            angle: 0.2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: context.jc.acid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NeoNavButton extends StatefulWidget {
  const _NeoNavButton({
    required this.destination,
    required this.selected,
    required this.due,
    required this.onTap,
    this.horizontal = false,
  });

  final _Destination destination;
  final bool selected;
  final int due;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  State<_NeoNavButton> createState() => _NeoNavButtonState();
}

class _NeoNavButtonState extends State<_NeoNavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final label = widget.destination.label(context);
    final icon = _NavIcon(
      kind: widget.destination.kind,
      due: widget.due,
    );
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        color: jc.ink,
        fontSize: widget.horizontal ? 13 : 10.5,
        height: 1,
        fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w700,
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () {
          Haptics.tick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: Motion.timed(context, const Duration(milliseconds: 120)),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            _pressed && widget.selected ? 4 : 0,
            _pressed && widget.selected ? 4 : 0,
            0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontal ? 14 : 2,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: widget.selected ? jc.acid : Colors.transparent,
            border:
                widget.selected ? Border.all(color: jc.ink, width: 2.5) : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.selected && !_pressed
                ? [
                    BoxShadow(
                      color: jc.ink,
                      blurRadius: 0,
                      offset: const Offset(3, 3),
                    ),
                  ]
                : null,
          ),
          child: widget.horizontal
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: labelWidget),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 3),
                    FittedBox(fit: BoxFit.scaleDown, child: labelWidget),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.kind, required this.due});

  final _NavGlyphKind kind;
  final int due;

  @override
  Widget build(BuildContext context) {
    final glyph = kind == _NavGlyphKind.kana
        ? Text(
            'あ',
            style: TextStyle(
              color: context.jc.ink,
              fontFamily: 'NotoSansJP',
              fontSize: 19,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          )
        : CustomPaint(
            size: const Size.square(22),
            painter: _NavGlyphPainter(kind: kind, color: context.jc.ink),
          );
    if (due <= 0) return SizedBox.square(dimension: 22, child: glyph);
    return SizedBox(
      width: 30,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, child: glyph),
          Positioned(
            right: -2,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.jc.magenta,
                border: Border.all(color: context.jc.ink, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                due > 99 ? '99+' : '$due',
                style: const TextStyle(
                  fontSize: 8.5,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGlyphPainter extends CustomPainter {
  const _NavGlyphPainter({required this.kind, required this.color});

  final _NavGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case _NavGlyphKind.book:
        final path = Path()
          ..moveTo(11, 4.5)
          ..cubicTo(9.2, 3.2, 6.6, 2.8, 3.5, 3.2)
          ..lineTo(3.5, 16.8)
          ..cubicTo(6.6, 16.4, 9.2, 16.8, 11, 18.1)
          ..cubicTo(12.8, 16.8, 15.4, 16.4, 18.5, 16.8)
          ..lineTo(18.5, 3.2)
          ..cubicTo(15.4, 2.8, 12.8, 3.2, 11, 4.5)
          ..lineTo(11, 18.1);
        canvas.drawPath(path, paint);
      case _NavGlyphKind.review:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.5, 3, 13, 9.5),
            const Radius.circular(2),
          ),
          paint,
        );
        final path = Path()
          ..moveTo(3.5, 8)
          ..lineTo(3.5, 16.5)
          ..quadraticBezierTo(3.5, 19, 6, 19)
          ..lineTo(15.5, 19);
        canvas.drawPath(path, paint);
      case _NavGlyphKind.community:
        final path = Path()
          ..moveTo(19, 10)
          ..cubicTo(19, 13.9, 15.9, 17, 12, 17)
          ..cubicTo(10.9, 17, 9.8, 16.8, 8.9, 16.3)
          ..lineTo(4, 18)
          ..lineTo(5.6, 14.3)
          ..cubicTo(5.2, 13, 5, 11.6, 5, 10)
          ..cubicTo(5, 6.1, 8.1, 3, 12, 3)
          ..cubicTo(15.9, 3, 19, 6.1, 19, 10)
          ..close();
        canvas.drawPath(path, paint);
      case _NavGlyphKind.profile:
        canvas.drawCircle(const Offset(11, 7.5), 3.6, paint);
        final path = Path()
          ..moveTo(4.5, 19)
          ..cubicTo(5.3, 15.6, 7.9, 13.8, 11, 13.8)
          ..cubicTo(14.1, 13.8, 16.7, 15.6, 17.5, 19);
        canvas.drawPath(path, paint);
      case _NavGlyphKind.kana:
        break;
    }
  }

  @override
  bool shouldRepaint(_NavGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

enum _NavGlyphKind { book, kana, review, community, profile }

class _Destination {
  const _Destination(this.kind, this.english, this.french);

  final _NavGlyphKind kind;
  final String english;
  final String french;

  String label(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fr' ? french : english;
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SnappyPageScrollPhysics extends ScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 200,
        ratio: 1,
      );
}
