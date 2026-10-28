import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'review_page.dart';
import 'widgets.dart';

/// Home tab: streak, what is due now, and what comes back soon.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.store, required this.problems, required this.stats, required this.onOpenSheet});

  final Store store;
  final List<Problem> problems;
  final Stats stats;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final due = problems.where((p) => p.isDue(now)).toList()..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final week = addDays(now, 7);
    final upcoming = problems.where((p) => !p.isDue(now) && !p.nextDue.isAfter(week)).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final reviewedToday = stats.reviewsOn(now);
    final days = streak(stats.days.keys, now);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        StatRow(children: [
          StatTile(icon: Icons.local_fire_department_outlined, value: '$days', label: 'day streak'),
          StatTile(icon: Icons.schedule_outlined, value: '${due.length}', label: 'due now'),
          StatTile(icon: Icons.task_alt, value: '$reviewedToday', label: 'reviewed today'),
        ]),
        if (due.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewPage(store: store, queue: due))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start review · ${due.length} ${due.length == 1 ? 'problem' : 'problems'}'),
            ),
          ),
          const SectionTitle('Due now'),
          for (final p in due) _ProblemRow(problem: p, trailing: dueLabel(p.daysOverdue(now)), highlight: p.daysOverdue(now) > 0),
        ] else
          EmptyState(
            icon: problems.isEmpty ? Icons.rocket_launch_outlined : Icons.celebration_outlined,
            title: problems.isEmpty ? 'Start your stack' : 'All caught up',
            message: problems.isEmpty
                ? 'Solve a problem from the A2Z sheet and tick it. It comes back here for revision tomorrow.'
                : 'Nothing to review right now. Keep the momentum: solve the next sheet problem.',
            action: FilledButton.tonalIcon(onPressed: onOpenSheet, icon: const Icon(Icons.menu_book_outlined), label: const Text('Open A2Z sheet')),
          ),
        if (upcoming.isNotEmpty) ...[
          const SectionTitle('Coming up this week'),
          for (final p in upcoming) _ProblemRow(problem: p, trailing: prettyDay(p.nextDue)),
        ],
      ],
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem, required this.trailing, this.highlight = false});

  final Problem problem;
  final String trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(problem.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${problem.topic} · ${problem.difficulty}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(trailing, style: TextStyle(color: highlight ? colors.error : colors.onSurfaceVariant)),
    );
  }
}
