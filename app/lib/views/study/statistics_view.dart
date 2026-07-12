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
import '../../viewmodels/statistics_viewmodel.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/status_views.dart';
import 'study_chrome.dart';

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) =>
            StatisticsViewModel(ctx.read<StudyRepository>())..load(),
        child: const _Statistics(),
      );
}

class _Statistics extends StatelessWidget {
  const _Statistics();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StatisticsViewModel>();
    if (vm.isLoading && vm.stats.totalCards == 0) {
      return const Scaffold(body: LoadingView());
    }
    if (vm.hasError) {
      return Scaffold(body: ErrorRetry(message: vm.error!, onRetry: vm.load));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: context.jc.brand,
          onRefresh: vm.load,
          child: BoundedContent(
            maxWidth: context.isExpanded ? 1040 : Breakpoints.maxContent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.isExpanded ? 24 : 16,
                16,
                context.isExpanded ? 24 : 16,
                32,
              ),
              children: [
                _Header(refreshing: vm.isLoading, onRefresh: vm.load),
                const SizedBox(height: 18),
                if (context.isExpanded)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _ProfileMetrics(stats: vm.stats),
                            const SizedBox(height: 16),
                            _HistoryCard(days: vm.stats.history),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        flex: 4,
                        child: _DetailsColumn(stats: vm.stats),
                      ),
                    ],
                  )
                else ...[
                  _ProfileMetrics(stats: vm.stats),
                  const SizedBox(height: 16),
                  _HistoryCard(days: vm.stats.history),
                  const SizedBox(height: 20),
                  _DetailsColumn(stats: vm.stats),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trText('Profile'),
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.trText('Your memory, without vanity metrics.'),
                  style: TextStyle(
                    color: context.jc.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _HeaderAction(
            label: context.trText('Refresh'),
            icon: Icons.refresh_rounded,
            busy: refreshing,
            onTap: refreshing ? null : onRefresh,
          ),
          const SizedBox(width: 8),
          _HeaderAction(
            label: context.trText('Settings'),
            icon: Icons.settings_outlined,
            onTap: () => context.push('/settings'),
          ),
        ],
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 44,
        child: Pressable(
          label: label,
          onTap: onTap,
          child: StudyPanel(
            radius: 10,
            padding: EdgeInsets.zero,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: NeoChaseLoader.small(),
                  )
                : Icon(icon, size: 20),
          ),
        ),
      );
}

class _ProfileMetrics extends StatelessWidget {
  const _ProfileMetrics({required this.stats});

  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final known = stats.byState['review'] ?? 0;
    return Column(
      children: [
        StudyPanel(
          color: context.jc.acid,
          shadow: 4,
          radius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$known',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.trText('Cards known'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              StudySticker(
                context.trText('${stats.reviewsToday} today'),
                color: context.jc.surface,
                angle: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Metric(
                value: '${stats.streak}',
                label: context.trText('day streak'),
                color: context.jc.lime,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                value: _percent(stats.accuracy),
                label: context.trText('Accuracy'),
                color: context.jc.lavender,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Metric(
                value: '${stats.totalReviews}',
                label: context.trText('Reviews'),
                color: context.jc.magenta,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                value: _percent(stats.matureRetention),
                label: context.trText('Mature recall'),
                color: context.jc.surface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => StudyPanel(
        color: color,
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.days});

  final List<StudyStatsDay> days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final byDate = {for (final day in days) _dateKey(day.date): day};
    final values = [
      for (var i = 6; i >= 0; i--)
        byDate[_dateKey(today.subtract(Duration(days: i)))] ??
            StudyStatsDay(
              date: today.subtract(Duration(days: i)),
              reviews: 0,
              correct: 0,
            ),
    ];
    final max =
        values.map((day) => day.reviews).fold<int>(1, (a, b) => a > b ? a : b);
    return StudyPanel(
      shadow: 4,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.trText('Last 7 days'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${values[i].reviews}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: 64 * values[i].reviews / max + 4,
                            decoration: BoxDecoration(
                              color: i == values.length - 1
                                  ? context.jc.acid
                                  : context.jc.brand,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: context.jc.ink, width: 2.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${values[i].date.day}',
                            style: TextStyle(
                              color: context.jc.body,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.trText(
                '${days.fold<int>(0, (sum, day) => sum + day.reviews)} reviews logged.'),
            style: TextStyle(
              color: context.jc.body,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsColumn extends StatelessWidget {
  const _DetailsColumn({required this.stats});

  final StudyStats stats;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.trText('Knowledge accumulation'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          StudyPanel(
            radius: 14,
            padding: const EdgeInsets.all(14),
            child: _StateBreakdown(stats: stats),
          ),
          const SizedBox(height: 20),
          Text(
            context.trText('Answer profile'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          StudyPanel(
            radius: 14,
            padding: const EdgeInsets.all(14),
            child: _RatingBreakdown(stats: stats),
          ),
          const SizedBox(height: 20),
          const _ProfileModeCard(),
          const SizedBox(height: 18),
          Text(
            context.trText(
              'Accuracy counts Hard, Good and Easy as a successful recall. Mature retention only measures cards already in review, so it reflects durable knowledge rather than first exposure.',
            ),
            style: TextStyle(
              color: context.jc.body,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      );
}

class _ProfileModeCard extends StatelessWidget {
  const _ProfileModeCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mode = app.mode;
    final helper = switch (mode) {
      AppMode.dictionary => context.trText(
          'Dictionary keeps lookup first and hides the daily review pressure.'),
      AppMode.middle => context.trText(
          'Balanced keeps lookup central while surfacing useful review cues.'),
      AppMode.learning => context.trText(
          'Learning enables the full review queue, new cards and progress data.'),
    };
    return StudyPanel(
      shadow: 4,
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.trText('Mode'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          NeoSegmentedControl<AppMode>(
            height: 52,
            segments: [
              NeoSegment(AppMode.dictionary, context.trText('Dictionary')),
              NeoSegment(AppMode.middle, context.trText('Balanced')),
              NeoSegment(AppMode.learning, context.trText('Learning')),
            ],
            selected: mode,
            onChanged: (value) {
              app.updateProfile({'mode': value.wire});
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: Motion.timed(context, Motion.fast),
            child: Text(
              helper,
              key: ValueKey(mode),
              style: TextStyle(
                color: context.jc.body,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBreakdown extends StatelessWidget {
  const _StateBreakdown({required this.stats});

  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      (context.trText('New'), stats.byState['new'] ?? 0, context.jc.surfaceAlt),
      (
        context.trText('Learning'),
        stats.byState['learning'] ?? 0,
        context.jc.acid
      ),
      (context.trText('Review'), stats.byState['review'] ?? 0, context.jc.lime),
    ];
    final max =
        values.map((value) => value.$2).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _DataBar(
            label: values[i].$1,
            value: values[i].$2,
            max: max,
            color: values[i].$3,
          ),
        ],
      ],
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.stats});

  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        context.trText('Again'),
        stats.reviewsByRating['1'] ?? 0,
        context.jc.coral
      ),
      (
        context.trText('Hard'),
        stats.reviewsByRating['2'] ?? 0,
        context.jc.acid
      ),
      (
        context.trText('Good'),
        stats.reviewsByRating['3'] ?? 0,
        context.jc.lime
      ),
      (
        context.trText('Easy'),
        stats.reviewsByRating['4'] ?? 0,
        context.jc.brand
      ),
    ];
    final max =
        values.map((value) => value.$2).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _DataBar(
            label: values[i].$1,
            value: values[i].$2,
            max: max,
            color: values[i].$3,
          ),
        ],
      ],
    );
  }
}

class _DataBar extends StatelessWidget {
  const _DataBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Container(
              height: 13,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.jc.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.jc.ink, width: 2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value / max,
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _percent(double value) => '${(value * 100).round()}%';
