import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../community/community_decks_view.dart';
import '../dashboard/tablet_dashboard_view.dart';
import '../dictionary/search_view.dart';
import '../kana/kana_chart_view.dart';
import '../study/decks_view.dart';
import '../study/statistics_view.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/pressable.dart';

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
  static const _destinations = [
    _Destination(_NavGlyphKind.book, 'Dico', 'Dico'),
    _Destination(_NavGlyphKind.kana, 'Kana', 'Kana'),
    _Destination(_NavGlyphKind.review, 'Review', 'Réviser'),
    _Destination(_NavGlyphKind.community, 'Commu', 'Commu'),
    _Destination(_NavGlyphKind.profile, 'Profile', 'Profil'),
  ];

  int _index = 0;
  int? _navigationTarget;
  bool _initialised = false;
  PageController? _pager;
  final _homeTabKey = GlobalKey<_ResponsiveHomeTabState>();
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _ResponsiveHomeTab(key: _homeTabKey),
      const KanaChartView(),
      const DecksView(),
      const CommunityDecksView(),
      const StatisticsView(),
    ];
  }

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
    if (index == 0) _homeTabKey.currentState?.showDashboard();
    if (index == _index) return;
    setState(() {
      _navigationTarget = index;
      _index = index;
    });
    if (context.isWide) {
      _navigationTarget = null;
      if (index == _reviewIndex) context.read<DashboardViewModel>().load();
      return;
    }
    final pager = _pager;
    if (pager != null && pager.hasClients) {
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
    final target = _navigationTarget;
    if (target != null && index != target) return;
    if (target == index) {
      _navigationTarget = null;
      if (index == _reviewIndex) context.read<DashboardViewModel>().load();
      return;
    }
    if (index == _index) return;
    setState(() => _index = index);
    if (index == _reviewIndex) context.read<DashboardViewModel>().load();
  }

  void _syncPager() {
    if (_navigationTarget != null) return;
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

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _NeoNavigationRail(
              index: _index,
              due: showDue ? due : 0,
              destinations: _destinations,
              onSelect: _go,
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [for (final tab in _tabs) _KeepAlive(child: tab)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveHomeTab extends StatefulWidget {
  const _ResponsiveHomeTab({super.key});

  @override
  State<_ResponsiveHomeTab> createState() => _ResponsiveHomeTabState();
}

class _ResponsiveHomeTabState extends State<_ResponsiveHomeTab> {
  bool _dictionaryOpen = false;
  String _dictionaryQuery = '';
  int _dashboardRevision = 0;
  int _dictionaryRevision = 0;

  void showDashboard() {
    setState(() {
      _dictionaryOpen = false;
      _dashboardRevision++;
    });
  }

  void _openDictionary([String query = '']) {
    setState(() {
      _dictionaryQuery = query.trim();
      _dictionaryRevision++;
      _dictionaryOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 768) {
      return const SearchView();
    }
    return AnimatedSwitcher(
      duration: Motion.timed(context, const Duration(milliseconds: 180)),
      switchInCurve: Motion.out,
      switchOutCurve: Motion.out,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.018, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _dictionaryOpen
          ? SearchView(
              key: ValueKey('dictionary-$_dictionaryRevision'),
              initialQuery: _dictionaryQuery,
            )
          : TabletDashboardView(
              key: ValueKey('dashboard-$_dashboardRevision'),
              onOpenDictionary: _openDictionary,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 4.0;
                final itemWidth =
                    (constraints.maxWidth - gap * (destinations.length - 1)) /
                        destinations.length;
                return SizedBox(
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: Motion.timed(
                          context,
                          const Duration(milliseconds: 230),
                        ),
                        curve: Motion.outStrong,
                        left: index * (itemWidth + gap),
                        top: 0,
                        width: itemWidth,
                        height: 56,
                        child: const IgnorePointer(
                          child: _NavSelectionPill(),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < destinations.length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            Expanded(
                              child: _NeoNavButton(
                                destination: destinations[i],
                                selected: index == i,
                                showSelection: false,
                                due: i == _ShellState._reviewIndex ? due : 0,
                                onTap: () => onSelect(i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
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
    required this.destinations,
    required this.onSelect,
  });

  final int index;
  final int due;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: jc.surface,
        border: Border(right: BorderSide(color: jc.ink, width: 3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontal = 7.0;
          const top = 14.0;
          const brandSize = 46.0;
          const brandGap = 12.0;
          const itemHeight = 56.0;
          const itemGap = 6.0;
          const itemTop = brandSize + brandGap;
          final contentHeight = itemTop +
              destinations.length * itemHeight +
              (destinations.length - 1) * itemGap +
              14;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(horizontal, top, horizontal, 14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 28,
                minWidth: constraints.maxWidth - horizontal * 2,
              ),
              child: SizedBox(
                height: contentHeight > constraints.maxHeight - 28
                    ? contentHeight
                    : constraints.maxHeight - 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _RailSlidingSelection(
                          index: index,
                          top: itemTop,
                          itemHeight: itemHeight,
                          slotHeight: itemHeight + itemGap,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _RailBrand(),
                        const SizedBox(height: brandGap),
                        for (var i = 0; i < destinations.length; i++) ...[
                          if (i > 0) const SizedBox(height: itemGap),
                          SizedBox(
                            height: itemHeight,
                            child: _NeoNavButton(
                              destination: destinations[i],
                              selected: index == i,
                              showSelection: false,
                              due: i == _ShellState._reviewIndex ? due : 0,
                              onTap: () => onSelect(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) =>
      const Center(child: JibikiBrandMark(size: 46));
}

class _NeoNavButton extends StatefulWidget {
  const _NeoNavButton({
    required this.destination,
    required this.selected,
    this.showSelection = true,
    required this.due,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool showSelection;
  final int due;
  final VoidCallback onTap;

  @override
  State<_NeoNavButton> createState() => _NeoNavButtonState();
}

class _NeoNavButtonState extends State<_NeoNavButton> {
  bool _hovered = false;

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
        fontSize: 10.5,
        height: 1,
        fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w700,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable.builder(
        label: label,
        selected: widget.selected,
        focusRadius: 10,
        onTap: widget.onTap,
        builder: (context, pressed) => Transform.scale(
          scale: widget.selected
              ? 1.08
              : _hovered
                  ? 1.055
                  : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: widget.selected && widget.showSelection
                  ? jc.acid
                  : _hovered
                      ? jc.acid.withValues(alpha: .2)
                      : Colors.transparent,
              border: widget.selected && widget.showSelection
                  ? Border.all(color: jc.ink, width: 2.5)
                  : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: widget.selected && widget.showSelection && !pressed
                  ? [
                      BoxShadow(
                        color: jc.ink,
                        blurRadius: 0,
                        offset: const Offset(3, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 3),
                FittedBox(fit: BoxFit.scaleDown, child: labelWidget),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSelectionPill extends StatelessWidget {
  const _NavSelectionPill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.jc.acid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.jc.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
      );
}

class _RailSlidingSelection extends StatefulWidget {
  const _RailSlidingSelection({
    required this.index,
    required this.top,
    required this.itemHeight,
    required this.slotHeight,
  });

  final int index;
  final double top;
  final double itemHeight;
  final double slotHeight;

  @override
  State<_RailSlidingSelection> createState() => _RailSlidingSelectionState();
}

class _RailSlidingSelectionState extends State<_RailSlidingSelection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _position =
      AlwaysStoppedAnimation(widget.index.toDouble());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration =
        Motion.timed(context, const Duration(milliseconds: 280));
  }

  @override
  void didUpdateWidget(covariant _RailSlidingSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    final from = _position.value;
    if (kIsWeb) {
      _controller.stop();
      _position = AlwaysStoppedAnimation(widget.index.toDouble());
      return;
    }
    if (!Motion.enabled(context)) {
      _controller.stop();
      _position = AlwaysStoppedAnimation(widget.index.toDouble());
      return;
    }
    _position = Tween<double>(
      begin: from,
      end: widget.index.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Motion.outStrong));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RailSelectionPainter(
          position: _position,
          top: widget.top,
          itemHeight: widget.itemHeight,
          slotHeight: widget.slotHeight,
          ink: context.jc.ink,
          acid: context.jc.acid,
        ),
      );
}

class _RailSelectionPainter extends CustomPainter {
  _RailSelectionPainter({
    required this.position,
    required this.top,
    required this.itemHeight,
    required this.slotHeight,
    required this.ink,
    required this.acid,
  }) : super(repaint: position);

  final Animation<double> position;
  final double top;
  final double itemHeight;
  final double slotHeight;
  final Color ink;
  final Color acid;

  @override
  void paint(Canvas canvas, Size size) {
    final y = top + position.value * slotHeight;
    final rect = Rect.fromLTWH(0, y, size.width, itemHeight);
    final radius = const Radius.circular(10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(3, 3)), radius),
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = acid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.25), radius),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_RailSelectionPainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.itemHeight != itemHeight ||
      oldDelegate.slotHeight != slotHeight ||
      oldDelegate.ink != ink ||
      oldDelegate.acid != acid ||
      oldDelegate.position != position;
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
              fontFamily: 'ZenKakuGothicNew',
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
