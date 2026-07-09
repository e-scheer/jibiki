import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../community/studio_view.dart';
import '../dictionary/kanji_browse_view.dart';
import '../dictionary/search_view.dart';
import '../kana/kana_chart_view.dart';
import '../study/decks_view.dart';

/// The signed-in home. Five tabs: Explore (search + browse) · Kana · Kanji ·
/// Study · Studio (the mnemonic-drawing ecosystem). Settings lives behind a gear
/// icon on the tab app bars, not as a tab.
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
  int _index = 0;
  bool _initialised = false;
  PageController? _pager;

  static const _studyIndex = 3;
  static const _tabs = [
    SearchView(),
    KanaChartView(),
    KanjiBrowseView(),
    DecksView(),
    StudioView(),
  ];

  static const _dests = [
    (icon: Icons.search, sel: Icons.search, label: 'Explore'),
    (icon: Icons.grid_view_outlined, sel: Icons.grid_view, label: 'Kana'),
    (icon: Icons.translate_outlined, sel: Icons.translate, label: 'Kanji'),
    (icon: Icons.school_outlined, sel: Icons.school, label: 'Study'),
    (icon: Icons.palette_outlined, sel: Icons.palette, label: 'Studio'),
  ];

  Widget _navIcon(int i, {required bool selected, required int due, required bool showBadge}) {
    final d = _dests[i];
    final icon = Icon(selected ? d.sel : d.icon);
    if (i != _studyIndex) return icon;
    return Badge(isLabelVisible: showBadge, label: Text('$due'), child: icon);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      // Learning mode opens on the review dashboard; everyone else on Explore.
      _index = context.read<AppState>().mode.showsReviewFirst ? _studyIndex : 0;
      _pager = PageController(initialPage: _index);
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  // One entry point for both navs. Compact drives the swipeable PageView (jump →
  // onPageChanged → _onPageSettled); wide has no live pager (IndexedStack), so it
  // just sets the tab. A tap jumps instantly rather than animating through the
  // intermediate tabs (which would also build each one).
  void _go(int i) {
    if (i == _index) return;
    final pager = _pager;
    if (pager != null && pager.hasClients) {
      pager.jumpToPage(i);
    } else {
      _onPageSettled(i);
    }
  }

  void _onPageSettled(int i) {
    if (i == _index) return;
    Haptics.tick();
    setState(() => _index = i);
    if (i == _studyIndex) context.read<DashboardViewModel>().load();
  }

  // After a wide→compact switch (rotation) the PageView reattaches at its old page
  // while _index moved via the rail; nudge it back so the bar and content agree.
  void _syncPager() {
    final pager = _pager;
    if (pager != null && pager.hasClients && (pager.page?.round() ?? _index) != _index) {
      pager.jumpToPage(_index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;
    final due = context.watch<DashboardViewModel>().stats.dueNow;
    final showBadge = mode.showsDueBadge && due > 0;

    // Compact (phones portrait): bottom bar + a swipeable, keep-alive PageView.
    if (context.win.isCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPager();
      });
      return Scaffold(
        body: PageView(
          controller: _pager,
          onPageChanged: _onPageSettled,
          physics: const _SnappyPageScrollPhysics(),
          children: [
            for (final tab in _tabs) _KeepAlive(child: tab),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            for (var i = 0; i < _dests.length; i++)
              NavigationDestination(
                icon: _navIcon(i, selected: false, due: due, showBadge: showBadge),
                selectedIcon: _navIcon(i, selected: true, due: due, showBadge: showBadge),
                label: _dests[i].label,
              ),
          ],
        ),
      );
    }

    // Medium+ (landscape phones, tablets, desktop): a side rail beside an
    // IndexedStack. No PageController here, so the rail's selection and the shown
    // tab can never drift apart the way a resized PageView's can on rotation. The
    // rail frees the scarce vertical space landscape needs and reads native on a
    // tablet; it extends with labels + brand mark on truly wide screens.
    final extended = MediaQuery.sizeOf(context).width >= Breakpoints.railExtended;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _NavRail(
              index: _index,
              extended: extended,
              onSelect: _go,
              iconBuilder: (i, selected) => _navIcon(i, selected: selected, due: due, showBadge: showBadge),
              labels: [for (final d in _dests) d.label],
            ),
            VerticalDivider(width: 1, thickness: 1, color: context.jc.hairline),
            Expanded(child: IndexedStack(index: _index, children: _tabs)),
          ],
        ),
      ),
    );
  }
}

/// The wide-screen navigation: a Material 3 rail styled to match the bottom bar
/// (transparent indicator, vermilion when selected, quiet otherwise). Scrolls if
/// a short landscape phone can't fit every destination, extends with labels and a
/// brand mark on tablet/desktop widths.
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.index,
    required this.extended,
    required this.onSelect,
    required this.iconBuilder,
    required this.labels,
  });

  final int index;
  final bool extended;
  final ValueChanged<int> onSelect;
  final Widget Function(int i, bool selected) iconBuilder;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              backgroundColor: jc.canvas,
              selectedIndex: index,
              onDestinationSelected: onSelect,
              extended: extended,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
              groupAlignment: -0.75,
              useIndicator: false,
              leading: extended
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('字', style: TextStyle(fontSize: 26, color: jc.brand, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('jibiki',
                              style: TextStyle(fontSize: 17, color: jc.ink, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        ],
                      ),
                    )
                  : null,
              selectedIconTheme: IconThemeData(color: jc.brand, size: 26),
              unselectedIconTheme: IconThemeData(color: jc.muted, size: 25),
              selectedLabelTextStyle:
                  TextStyle(color: jc.brand, fontWeight: FontWeight.w700, fontSize: 12.5),
              unselectedLabelTextStyle:
                  TextStyle(color: jc.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: iconBuilder(i, false),
                    selectedIcon: iconBuilder(i, true),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a tab mounted once it's first built, so swiping away and back doesn't
/// reset its scroll offset or re-fire its initial requests.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A slightly firmer page fling so tab-to-tab swipes feel crisp rather than
/// loose, matching the app's tight, snappy motion language.
class _SnappyPageScrollPhysics extends ScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPageScrollPhysics(parent: buildParent(ancestor));

  // Lighter mass + stiffer than the default, critically damped: the page snaps
  // home crisply without an overshoot wobble.
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: 0.5, stiffness: 200, ratio: 1.0);
}