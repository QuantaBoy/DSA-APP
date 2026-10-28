import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'review_page.dart';
import 'streak_page.dart';
import 'widgets.dart';

/// Home tab: today's review card, streak, what is due now, and what comes back soon.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.store, required this.problems, required this.stats, required this.onOpenSheet, this.onSeeAll});

  final Store store;
  final List<Problem> problems;
  final Stats stats;
  final VoidCallback onOpenSheet;
  final VoidCallback? onSeeAll; // opens My stack

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
    void review(List<Problem> queue) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewPage(
              store: store,
              queue: queue,
              // First review of the day grows the streak: celebrate it when the session ends.
              streakBefore: reviewedToday == 0 ? days : null,
              reviewDays: {...stats.days.keys.map(dateOnly), now},
            ),
          ),
        );

    final hero = HeroCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TODAY'S REVISION",
                style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 10),
            if (due.isEmpty)
              const Text('All caught up', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5))
            else
              Text.rich(TextSpan(children: [
                TextSpan(text: '${due.length} ', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                TextSpan(text: due.length == 1 ? 'problem to review' : 'problems to review'),
              ]), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(
              due.isEmpty
                  ? (problems.isEmpty ? 'Solve a sheet problem and it comes back here tomorrow.' : 'Nothing due. Solve the next sheet problem.')
                  : '${due.first.name}${due.length > 1 ? ' and ${due.length - 1} more' : ''}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Grow(
              value: todayTotal == 0 ? 0 : reviewedToday / todayTotal,
              builder: (context, v) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: v, minHeight: 6, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            const SizedBox(height: 6),
            Text('$reviewedToday of $todayTotal done today', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: HeroCard.ink(context),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: due.isEmpty ? onOpenSheet : () => review(due),
              icon: Icon(due.isEmpty ? Icons.menu_book_rounded : Icons.play_arrow_rounded),
              label: Text(due.isEmpty ? 'Open A2Z sheet' : 'Start review'),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Bob(height: 6, child: Image.asset('assets/illustrations/stack.png', width: 100, height: 100)),
      ]),
    );

    final stats3 = StatRow(children: [
      StatTile(
        icon: Icons.local_fire_department_rounded,
        value: '$days',
        label: 'Day streak',
        color: Accent.orange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreakPage(stats: stats))),
      ),
      StatTile(icon: Icons.event_note_rounded, value: '${due.length}', label: 'Due now', color: Accent.red),
      StatTile(icon: Icons.check_circle_rounded, value: '$reviewedToday', label: 'Reviewed today', color: Accent.green),
    ]);

    List<Widget> dueList(int start) => [
          SectionTitle('Due now', action: due.isEmpty ? null : 'See all', onAction: onSeeAll),
          if (due.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Nothing due. Nice!', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          for (final (i, p) in due.indexed)
            Rise(index: start + i, child: _ProblemCard(problem: p, now: now, onTap: () => review([p]))),
        ];
    List<Widget> upcomingList(int start) => [
          if (upcoming.isNotEmpty) const SectionTitle('Coming up this week'),
          for (final (i, p) in upcoming.indexed) Rise(index: start + i, child: _ProblemCard(problem: p, now: now)),
        ];

    return LayoutBuilder(builder: (context, box) {
      final twoColumns = box.maxWidth >= 720; // PC: due and upcoming side by side
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text("Let's make today's revision count.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Rise(child: hero),
          const SizedBox(height: 14),
          Rise(index: 1, child: stats3),
          if (twoColumns)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: dueList(2))),
              Expanded(child: Column(children: upcomingList(2))),
            ])
          else ...[
            ...dueList(2),
            ...upcomingList(2 + due.length),
          ],
        ],
      );
    });
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.problem, required this.now, this.onTap});

  final Problem problem;
  final DateTime now;
  final VoidCallback? onTap; // due problems open a review of just that one

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = problem.daysOverdue(now);
    final due = problem.isDue(now);
    final (label, color) = overdue > 0
        ? (dueLabel(overdue), Accent.red)
        : due
            ? ('Due today', Accent.amber)
            : (prettyDay(problem.nextDue).replaceFirst(RegExp(r' \d{4}$'), ''), theme.colorScheme.onSurfaceVariant);
    return Pressable(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: difficultyColor(problem.difficulty),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: difficultyColor(problem.difficulty).withValues(alpha: 0.35), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(problem.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Pill.difficulty(problem.difficulty),
                  Text(problem.topic, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(overdue > 0 ? Icons.event_busy_rounded : Icons.event_rounded, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
