import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/study.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/statistics_viewmodel.dart';
import '../widgets/status_views.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trText('Statistics')),
        actions: [
          IconButton(
            tooltip: context.trText('Refresh'),
            onPressed: vm.isLoading ? null : vm.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: vm.isLoading && vm.stats.totalCards == 0
          ? const LoadingView()
          : vm.hasError
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : BoundedContent(
                  child: RefreshIndicator(
                    onRefresh: vm.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        _Headline(stats: vm.stats),
                        const SizedBox(height: 24),
                        const _SectionTitle('Knowledge accumulation'),
                        const SizedBox(height: 10),
                        _StateBreakdown(stats: vm.stats),
                        const SizedBox(height: 24),
                        const _SectionTitle('Last 14 days'),
                        const SizedBox(height: 10),
                        _HistoryChart(days: vm.stats.history),
                        const SizedBox(height: 24),
                        const _SectionTitle('Answer profile'),
                        const SizedBox(height: 10),
                        _RatingBreakdown(stats: vm.stats),
                        const SizedBox(height: 24),
                        const _SectionTitle('What these numbers mean'),
                        const SizedBox(height: 8),
                        Text(
                          context.trText(
                              'Accuracy counts Hard, Good and Easy as a successful recall. Mature retention only measures cards already in review, so it reflects durable knowledge rather than first exposure.'),
                          style:
                              TextStyle(color: context.jc.muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.stats});
  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(
          label: 'Cards known',
          value: '${stats.byState['review'] ?? 0}',
          icon: Icons.auto_awesome),
      _Metric(
          label: 'Reviews',
          value: '${stats.totalReviews}',
          icon: Icons.repeat_rounded),
      _Metric(
          label: 'Accuracy',
          value: _percent(stats.accuracy),
          icon: Icons.track_changes),
      _Metric(
          label: 'Mature recall',
          value: _percent(stats.matureRetention),
          icon: Icons.insights_rounded),
    ];
    return GridView.extent(
      maxCrossAxisExtent: 220,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [for (final card in cards) _MetricCard(metric: card)],
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: jc.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, color: jc.brand, size: 21),
          Text(metric.value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(context.trText(metric.label),
              style: TextStyle(color: jc.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        context.trText(text),
        style: context.text.titleLarge,
      );
}

class _StateBreakdown extends StatelessWidget {
  const _StateBreakdown({required this.stats});
  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('New', stats.byState['new'] ?? 0, context.jc.muted),
      ('Learning', stats.byState['learning'] ?? 0, context.jc.warn),
      ('Review', stats.byState['review'] ?? 0, context.jc.success),
    ];
    final max = values.map((v) => v.$2).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(context.trText(value.$1))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: value.$2 / max,
                      minHeight: 10,
                      backgroundColor: context.jc.surfaceAlt,
                      color: value.$3,
                    ),
                  ),
                ),
                SizedBox(
                    width: 42,
                    child: Text('${value.$2}', textAlign: TextAlign.right)),
              ],
            ),
          ),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.days});
  final List<StudyStatsDay> days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final byDate = {for (final day in days) _dateKey(day.date): day};
    final values = [
      for (var i = 13; i >= 0; i--)
        byDate[_dateKey(today.subtract(Duration(days: i)))] ??
            StudyStatsDay(
                date: today.subtract(Duration(days: i)),
                reviews: 0,
                correct: 0),
    ];
    final max =
        values.map((v) => v.reviews).fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: context.jc.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.jc.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (day.reviews > 0)
                      Text('${day.reviews}',
                          style:
                              TextStyle(fontSize: 10, color: context.jc.muted)),
                    const SizedBox(height: 4),
                    Container(
                      height: 120 * day.reviews / max,
                      decoration: BoxDecoration(
                        color: context.jc.brand,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${day.date.day}',
                        style:
                            TextStyle(fontSize: 10, color: context.jc.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.stats});
  final StudyStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Again', '1', context.jc.ratingAgain),
      ('Hard', '2', context.jc.warn),
      ('Good', '3', context.jc.ratingGood),
      ('Easy', '4', context.jc.brand),
    ];
    final max = values
        .map((value) => stats.reviewsByRating[value.$2] ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(width: 62, child: Text(context.trText(value.$1))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: (stats.reviewsByRating[value.$2] ?? 0) / max,
                      minHeight: 9,
                      backgroundColor: context.jc.surfaceAlt,
                      color: value.$3,
                    ),
                  ),
                ),
                SizedBox(
                    width: 42,
                    child: Text('${stats.reviewsByRating[value.$2] ?? 0}',
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
      ],
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _percent(double value) => '${(value * 100).round()}%';
