import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'review_page.dart';
import 'widgets.dart';

/// Home tab: today's review card, streak, what is due now, and what comes back soon.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.store, required this.problems, required this.stats, required this.onOpenSheet});

  final Store store;
  final List<Problem> problems;
  final Stats stats;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final due = problems.where((p) => p.isDue(now)).toList()..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final week = addDays(now, 7);
    final upcoming = problems.where((p) => !p.isDue(now) && !p.nextDue.isAfter(week)).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final reviewedToday = stats.reviewsOn(now);
    final days = streak(stats.days.keys, now);
    final todayTotal = due.length + reviewedToday;
    void startReview() => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewPage(store: store, queue: due)));

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            due.isEmpty ? "You're all set for today. Keep the streak going!" : "Let's make today's revision count.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        HeroCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text("TODAY'S REVISION", style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
              ),
              const Icon(Icons.auto_awesome, size: 20),
            ]),
            const SizedBox(height: 10),
            Text(
              due.isEmpty ? 'All caught up' : '${due.length} ${due.length == 1 ? 'problem' : 'problems'} to review',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              due.isEmpty
                  ? (problems.isEmpty ? 'Solve a sheet problem and it comes back here tomorrow.' : 'Nothing due. Solve the next sheet problem.')
                  : '${due.first.name}${due.length > 1 ? ' and ${due.length - 1} more' : ''}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: todayTotal == 0 ? 1 : reviewedToday / todayTotal,
                minHeight: 8,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: 6),
            Text('$reviewedToday of $todayTotal done today', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF5B3FE0)),
              onPressed: due.isEmpty ? onOpenSheet : startReview,
              icon: Icon(due.isEmpty ? Icons.menu_book_rounded : Icons.play_arrow_rounded),
              label: Text(due.isEmpty ? 'Open A2Z sheet' : 'Start review'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        StatRow(children: [
          StatTile(icon: Icons.local_fire_department_rounded, value: '$days', label: 'day streak', color: Accent.orange),
          StatTile(icon: Icons.schedule_rounded, value: '${due.length}', label: 'due now', color: Accent.red),
          StatTile(icon: Icons.task_alt_rounded, value: '$reviewedToday', label: 'reviewed today', color: Accent.green),
        ]),
        if (due.isNotEmpty) ...[
          const SectionTitle('Due now'),
          for (final p in due) _ProblemCard(problem: p, trailing: dueLabel(p.daysOverdue(now)), overdue: p.daysOverdue(now) > 0),
        ],
        if (upcoming.isNotEmpty) ...[
          const SectionTitle('Coming up this week'),
          for (final p in upcoming) _ProblemCard(problem: p, trailing: prettyDay(p.nextDue)),
        ],
      ],
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.problem, required this.trailing, this.overdue = false});

  final Problem problem;
  final String trailing;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: overdue ? Accent.red : theme.colorScheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(problem.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Pill.difficulty(problem.difficulty),
                Text(problem.topic, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (overdue) const Icon(Icons.event_busy_rounded, size: 14, color: Accent.red),
            if (overdue) const SizedBox(width: 4),
            Text(trailing,
                style: theme.textTheme.labelMedium?.copyWith(color: overdue ? Accent.red : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
