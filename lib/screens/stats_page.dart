import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'streak_page.dart';
import 'widgets.dart';

enum _Period { week, month, all }

/// Progress at a glance: recall ring, totals, reviews over time, and how well you remember each topic.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.problems, required this.stats});

  final List<Problem> problems;
  final Stats stats;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final problems = widget.problems, stats = widget.stats;
    if (problems.isEmpty) {
      return const Center(
        child: EmptyState(icon: Icons.insights_outlined, title: 'No stats yet', message: 'Solve and review a few problems and your progress shows up here.'),
      );
    }
    final now = today();
    final solvedPerTopic = <String, int>{};
    for (final p in problems) {
      solvedPerTopic[p.topic] = (solvedPerTopic[p.topic] ?? 0) + 1;
    }
    final results = {for (final e in stats.topics.entries) if (e.value.total > 0) e.key: e.value}; // deleted problems can leave 0
    double rate(String t) => results[t] == null ? 2 : results[t]!.remembered / results[t]!.total; // unreviewed last
    final topics = solvedPerTopic.keys.toList()..sort((a, b) => rate(a).compareTo(rate(b)));

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<_Period>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Period.week, label: Text('7D')),
              ButtonSegment(value: _Period.month, label: Text('30D')),
              ButtonSegment(value: _Period.all, label: Text('All time')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.single),
          ),
        ),
        Rise(child: _RecallCard(recall: stats.recall, problems: problems)),
        const SizedBox(height: 12),
        Rise(
          index: 1,
          child: StatRow(children: [
            StatTile(icon: Icons.check_circle_rounded, value: '${problems.length}', label: 'Solved', color: Accent.green),
            StatTile(icon: Icons.star_rounded, value: '${problems.where((p) => p.mastered).length}', label: 'Mastered', color: Accent.amber),
            StatTile(
              icon: Icons.local_fire_department_rounded,
              value: '${streak(stats.days.keys, now)}',
              label: 'Day streak',
              color: Accent.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreakPage(stats: stats))),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Rise(
          index: 2,
          child: StatRow(children: [
            StatTile(icon: Icons.replay_rounded, value: '${stats.reviews}', label: 'Reviews', color: Accent.sky),
            StatTile(icon: Icons.event_note_rounded, value: '${problems.where((p) => p.isDue(now)).length}', label: 'Due now', color: Accent.red),
          ]),
        ),
        SectionTitle(switch (_period) { _Period.week => 'Last 7 days', _Period.month => 'Last 30 days', _Period.all => 'Last 12 weeks' }),
        Rise(index: 3, child: _ReviewChart(stats: stats, today: now, period: _period)),
        const SectionTitle('Topics, weakest first'),
        for (final (i, t) in topics.indexed) Rise(index: 4 + i, child: _TopicRow(topic: t, solved: solvedPerTopic[t]!, result: results[t])),
      ],
    );
  }
}

/// Ring split into New / Growing / Mastered, recall rate in the middle.
class _RecallCard extends StatelessWidget {
  const _RecallCard({required this.recall, required this.problems});

  final double? recall;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mastered = problems.where((p) => p.mastered).length;
    final fresh = problems.where((p) => p.stage == 0).length;
    final growing = problems.length - mastered - fresh;
    final segments = [(Accent.sky, fresh), (theme.colorScheme.primary, growing), (Accent.amber, mastered)];
    Widget legend(Color c, String name, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
            Text('$n', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          SizedBox.square(
            dimension: 128,
            child: Grow(
              value: 1,
              duration: const Duration(milliseconds: 1200),
              builder: (context, t) => CustomPaint(
                painter: _RingPainter(segments, t, theme.colorScheme.surfaceContainerHighest),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(recall == null ? '–' : '${(recall! * 100 * t).round()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    Text('Recall', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Memory progress', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              legend(Accent.sky, 'New', fresh),
              legend(theme.colorScheme.primary, 'Growing', growing),
              legend(Accent.amber, 'Mastered', mastered),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.segments, this.t, this.track);

  final List<(Color, int)> segments;
  final double t; // 0..1 draw progress
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0, gap = 0.08; // radians between segments
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
    final total = segments.fold(0, (a, s) => a + s.$2);
    if (total == 0) return;
    final parts = segments.where((s) => s.$2 > 0).toList();
    final usable = 2 * pi - gap * parts.length;
    var start = -pi / 2;
    for (final (color, n) in parts) {
      final sweep = usable * n / total;
      canvas.drawArc(rect, start + gap / 2, sweep * t, false, paint..color = color);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.track != track;
}

/// Reviews per day (7D, 30D) or per week (all time), today's bar highlighted.
class _ReviewChart extends StatelessWidget {
  const _ReviewChart({required this.stats, required this.today, required this.period});

  final Stats stats;
  final DateTime today;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<int> counts;
    final List<String> labels;
    if (period == _Period.all) {
      final weeks = [for (var w = 11; w >= 0; w--) addDays(today, -7 * w - 6)];
      counts = [for (final start in weeks) [for (var d = 0; d < 7; d++) stats.reviewsOn(addDays(start, d))].fold(0, (a, b) => a + b)];
      labels = [for (final (i, s) in weeks.indexed) i == 11 ? 'Now' : (i % 3 == 0 ? prettyDay(s).split(' ').take(2).join(' ') : '')];
    } else {
      final n = period == _Period.week ? 7 : 30;
      final days = [for (var i = n - 1; i >= 0; i--) addDays(today, -i)];
      counts = [for (final d in days) stats.reviewsOn(d)];
      labels = [for (final (i, d) in days.indexed) i == n - 1 ? 'Today' : (n == 7 || i % 5 == 0 ? '${d.day}' : '')];
    }
    final most = max(1, counts.fold(0, max));
    final dense = counts.length > 12;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(
          height: 160,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, c) in counts.indexed)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (!dense) Text('$c', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Grow(
                    value: c / most,
                    duration: Duration(milliseconds: 600 + (dense ? 15 : 70) * i),
                    builder: (context, v) => Container(
                      height: 100 * v + 3,
                      margin: EdgeInsets.symmetric(horizontal: dense ? 1.5 : 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: i == counts.length - 1 ? 1 : 0.35),
                        borderRadius: BorderRadius.circular(dense ? 3 : 6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: dense ? 9 : 11, color: theme.colorScheme.onSurfaceVariant)),
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

  /// Weak topics red, then orange, amber, blue, strong topics green.
  static Color _strength(double rate, Color blue) => rate < 0.3
      ? Accent.red
      : rate < 0.5
          ? Accent.orange
          : rate < 0.65
              ? Accent.amber
              : rate < 0.8
                  ? blue
                  : Accent.green;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final rate = r == null ? null : r.remembered / r.total;
    final color = rate == null ? theme.colorScheme.outline : _strength(rate, theme.colorScheme.primary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(topic, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(rate == null ? '$solved solved' : '${(rate * 100).round()}% · $solved solved',
              style: theme.textTheme.labelLarge?.copyWith(color: rate == null ? theme.colorScheme.onSurfaceVariant : color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Grow(
          value: rate ?? 0,
          builder: (context, v) => LinearProgressIndicator(
            value: v,
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ]),
    );
  }
}
