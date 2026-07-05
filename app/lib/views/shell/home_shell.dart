import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  // A bottom-nav tap jumps instantly (Instagram-style, no animating through the
  // tabs in between, which would also build every intermediate tab). Swiping is
  // the smooth, animated gesture. Both funnel through [_onPageSettled].
  void _onTap(int i) {
    if (i == _index) return;
    _pager?.jumpToPage(i);
  }

  void _onPageSettled(int i) {
    if (i == _index) return;
    Haptics.tick();
    setState(() => _index = i);
    if (i == _studyIndex) context.read<DashboardViewModel>().load();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;
    final due = context.watch<DashboardViewModel>().stats.dueNow;
    final showBadge = mode.showsDueBadge && due > 0;

    return Scaffold(
      // Swipe left/right to move between tabs; pages are kept alive so their
      // scroll position and loaded data survive the swipe (like the old
      // IndexedStack), while still building lazily on first visit.
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
        onDestinationSelected: _onTap,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Kana'),
          const NavigationDestination(
              icon: Icon(Icons.translate_outlined), selectedIcon: Icon(Icons.translate), label: 'Kanji'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: showBadge,
              label: Text('$due'),
              child: const Icon(Icons.school_outlined),
            ),
            selectedIcon: const Icon(Icons.school),
            label: 'Study',
          ),
          const NavigationDestination(
              icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette), label: 'Studio'),
        ],
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