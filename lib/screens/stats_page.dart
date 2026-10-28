import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'widgets.dart';

/// Progress at a glance: totals, the last 7 days, and how well you remember each topic.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.problems, required this.stats});

  final List<Problem> problems;
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(
        child: EmptyState(icon: Icons.insights_outlined, title: 'No stats yet', message: 'Solve and review a few problems and your progress shows up here.'),
      );
    }
    final now = today();
    final recall = stats.recall == null ? '–' : '${(stats.recall! * 100).round()}%';
    final solvedPerTopic = <String, int>{};
    for (final p in problems) {
      solvedPerTopic[p.topic] = (solvedPerTopic[p.topic] ?? 0) + 1;
    }
    final results = {for (final e in stats.topics.entries) if (e.value.total > 0) e.key: e.value}; // deleted problems can leave 0
    double rate(String t) => results[t] == null ? 2 : results[t]!.remembered / results[t]!.total; // unreviewed last
    final topics = solvedPerTopic.keys.toList()..sort((a, b) => rate(a).compareTo(rate(b)));

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        Rise(child: _RecallCard(recall: stats.recall, label: recall, problems: problems)),
        const SizedBox(height: 12),
        Rise(index: 1, child: StatRow(children: [
          StatTile(icon: Icons.check_circle_rounded, value: '${problems.length}', label: 'solved', color: Accent.green),
          StatTile(icon: Icons.star_rounded, value: '${problems.where((p) => p.mastered).length}', label: 'mastered', color: Accent.amber),
          StatTile(icon: Icons.local_fire_department_rounded, value: '${streak(stats.days.keys, now)}', label: 'day streak', color: Accent.orange),
        ])),
        const SizedBox(height: 10),
        Rise(index: 2, child: StatRow(children: [
          StatTile(icon: Icons.replay_rounded, value: '${stats.reviews}', label: 'reviews', color: Accent.sky),
          StatTile(icon: Icons.event_rounded, value: '${problems.where((p) => p.isDue(now)).length}', label: 'due now', color: Accent.red),
        ])),
        const SectionTitle('Last 7 days'),
        Rise(index: 3, child: _WeekChart(stats: stats, today: now)),
        const SectionTitle('Topics, weakest first'),
        for (final (i, t) in topics.indexed) Rise(index: 4 + i, child: _TopicRow(topic: t, solved: solvedPerTopic[t]!, result: results[t])),
      ],
    );
  }
}

/// Recall rate as a big ring, with where your problems are in the schedule.
class _RecallCard extends StatelessWidget {
  const _RecallCard({required this.recall, required this.label, required this.problems});

  final double? recall;
  final String label;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mastered = problems.where((p) => p.mastered).length;
    final learning = problems.where((p) => p.stage == 0).length;
    final growing = problems.length - mastered - learning;
    Widget legend(Color c, String name, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
            Text('$n', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          SizedBox.square(
            dimension: 120,
            child: Stack(fit: StackFit.expand, children: [
              Grow(
                value: recall ?? 0,
                duration: const Duration(milliseconds: 1200),
                builder: (context, v) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                ),
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('recall', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Memory progress', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              legend(Accent.sky, 'New', learning),
              legend(theme.colorScheme.primary, 'Growing', growing),
              legend(Accent.amber, 'Mastered', mastered),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Reviews per day as simple bars.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats, required this.today});

  final Stats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final counts = [for (final d in days) stats.reviewsOn(d)];
    final most = counts.fold(1, (a, b) => a > b ? a : b);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SizedBox(
          height: 140,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, d) in days.indexed)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${counts[i]}', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Grow(
                    value: counts[i] / most,
                    duration: Duration(milliseconds: 700 + 80 * i), // bars grow left to right
                    builder: (context, v) => Container(
                      height: 90 * v + 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: i == 6 ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1],
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.solved, required this.result});

  final String topic;
  final int solved;
  final ({int remembered, int total})? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final rate = r == null ? null : r.remembered / r.total;
    final weak = r != null && r.total >= minReviewsToJudge && rate! < weakSuccessRate;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(topic),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Grow(
          value: rate ?? 0,
          builder: (context, v) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: weak ? theme.colorScheme.error : null,
          ),
        ),
      ),
      trailing: Text(
        r == null ? '$solved solved' : '${(rate! * 100).round()}% · $solved solved',
        style: theme.textTheme.bodySmall?.copyWith(color: weak ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
