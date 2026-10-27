import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../logic/srs.dart';
import 'widgets.dart';

/// Progress at a glance: totals, the last 7 days, and how well you remember each topic.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.problems, required this.reviews});

  final List<Problem> problems;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(
        child: EmptyState(icon: Icons.insights_outlined, title: 'No stats yet', message: 'Solve and review a few problems and your progress shows up here.'),
      );
    }
    final now = today();
    final remembered = reviews.where((r) => r.remembered).length;
    final recall = reviews.isEmpty ? '–' : '${(remembered * 100 / reviews.length).round()}%';
    final solvedPerTopic = <String, int>{};
    for (final p in problems) {
      solvedPerTopic[p.topic] = (solvedPerTopic[p.topic] ?? 0) + 1;
    }
    final results = topicResults(problems, reviews);
    double rate(String t) => results[t] == null ? 2 : results[t]!.remembered / results[t]!.total; // unreviewed last
    final topics = solvedPerTopic.keys.toList()..sort((a, b) => rate(a).compareTo(rate(b)));

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        StatRow(children: [
          StatTile(icon: Icons.check_circle_outline, value: '${problems.length}', label: 'solved'),
          StatTile(icon: Icons.star_outline, value: '${problems.where((p) => p.mastered).length}', label: 'mastered'),
          StatTile(icon: Icons.local_fire_department_outlined, value: '${streak(reviews.map((r) => r.reviewedOn), now)}', label: 'day streak'),
        ]),
        const SizedBox(height: 10),
        StatRow(children: [
          StatTile(icon: Icons.replay, value: '${reviews.length}', label: 'reviews'),
          StatTile(icon: Icons.psychology_outlined, value: recall, label: 'recall rate'),
          StatTile(icon: Icons.event_outlined, value: '${problems.where((p) => p.isDue(now)).length}', label: 'due now'),
        ]),
        const SectionTitle('Last 7 days'),
        _WeekChart(reviews: reviews, today: now),
        const SectionTitle('Topics, weakest first'),
        for (final t in topics) _TopicRow(topic: t, solved: solvedPerTopic[t]!, result: results[t]),
      ],
    );
  }
}

/// Reviews per day as simple bars.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.reviews, required this.today});

  final List<Review> reviews;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final counts = [for (final d in days) reviews.where((r) => r.reviewedOn == d).length];
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
                  Container(
                    height: 90 * counts[i] / most + 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: i == 6 ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
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
        child: LinearProgressIndicator(
          value: rate ?? 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: weak ? theme.colorScheme.error : null,
        ),
      ),
      trailing: Text(
        r == null ? '$solved solved' : '${(rate! * 100).round()}% · $solved solved',
        style: theme.textTheme.bodySmall?.copyWith(color: weak ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
