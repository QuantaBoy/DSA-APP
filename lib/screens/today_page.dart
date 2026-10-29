import 'dart:async';

import 'package:flutter/material.dart';

import '../data/prefs.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'coach.dart';
import 'motion.dart';
import 'review_page.dart';
import 'solve_page.dart';
import 'streak_page.dart';
import 'widgets.dart';

/// Home: one obvious next step (review → solve the next sheet problem → done), today's goal,
/// the streak, and what is due or coming up.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.store, required this.problems, required this.stats, required this.onOpenSheet, this.onSeeAll});

  final Store store;
  final List<Problem> problems;
  final Stats stats;
  final VoidCallback onOpenSheet;
  final VoidCallback? onSeeAll; // opens the library

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _sheet = loadA2zSheet();
  final _heroKey = GlobalKey(), _goalKey = GlobalKey(), _streakKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    showTipsOnce(context, 'home', [
      (
        target: _heroKey,
        title: 'Your next step',
        text: 'This card always shows the one thing to do now: review what is due, then solve the next problem.',
      ),
      (
        target: _goalKey,
        title: "Today's goal",
        text: 'Clear every due review and solve your new problems for the day. Change the goal in Profile.',
      ),
      (
        target: _streakKey,
        title: 'Keep the streak',
        text: 'Revise every day to grow it. Miss one day a week and a streak freeze saves it. Tap for details.',
      ),
    ]);
  }

  void _review(List<Problem> queue, {required int streakNow, required bool firstToday}) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          store: widget.store,
          queue: queue,
          // First review of the day grows the streak: celebrate it when the session ends.
          streakBefore: firstToday ? streakNow : null,
          reviewDays: {...widget.stats.days.keys.map(dateOnly), today()},
        ),
      ),
    ),
  );

  void _solve(Sheet sheet, SheetProblem p) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SolvePage(store: widget.store, sheet: sheet, problem: p, solved: false),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problems = widget.problems, stats = widget.stats;
    final now = today();
    final due = problems.where((p) => p.isDue(now)).toList()..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final upcoming = problems.where((p) => !p.isDue(now) && !p.nextDue.isAfter(addDays(now, 7))).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final reviewedToday = stats.reviewsOn(now);
    final solvedToday = problems.where((p) => p.solvedOn == now).length;
    final days = streakWithFreezes(stats.days.keys, now);

    return ValueListenableBuilder(
      valueListenable: Prefs.dailyNewGoal,
      builder: (context, goal, _) => FutureBuilder<Sheet>(
        future: _sheet,
        builder: (context, snap) {
          final sheet = snap.data;
          final next = sheet?.nextUnsolved({for (final p in problems) p.id});
          final hero = _NextStep(
            due: due,
            solvedToday: solvedToday,
            goal: goal,
            next: next,
            sheetStep: next == null || sheet == null ? null : sheet.steps[next.step - 1],
            onReview: () => _review(due, streakNow: days, firstToday: reviewedToday == 0),
            onSolve: sheet == null || next == null ? widget.onOpenSheet : () => _solve(sheet, next),
            onOpenSheet: widget.onOpenSheet,
          );
          return LayoutBuilder(
            builder: (context, box) {
              final twoColumns = box.maxWidth >= 720; // PC: due and upcoming side by side
              List<Widget> dueList(int start) => [
                SectionTitle('Due now', action: due.isEmpty ? null : 'See all', onAction: widget.onSeeAll),
                if (due.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text('Nothing due. Nice!', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                for (final (i, p) in due.indexed)
                  Rise(
                    index: start + i,
                    child: _ProblemCard(
                      problem: p,
                      now: now,
                      onTap: () => _review([p], streakNow: days, firstToday: reviewedToday == 0),
                    ),
                  ),
              ];
              List<Widget> upcomingList(int start) => [
                if (upcoming.isNotEmpty) const SectionTitle('Coming up this week'),
                for (final (i, p) in upcoming.indexed)
                  Rise(
                    index: start + i,
                    child: _ProblemCard(problem: p, now: now),
                  ),
              ];
              return ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 32),
                children: [
                  Rise(
                    child: KeyedSubtree(key: _heroKey, child: hero),
                  ),
                  const SizedBox(height: 14),
                  Rise(
                    index: 1,
                    child: StatRow(
                      children: [
                        StatTile(
                          key: _streakKey,
                          icon: Icons.local_fire_department_rounded,
                          value: '$days',
                          label: 'Day streak',
                          color: Accent.orange,
                          onTap: () =>
                              unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StreakPage(stats: stats)))),
                        ),
                        StatTile(
                          key: _goalKey,
                          icon: Icons.task_alt_rounded,
                          value: '${reviewedToday + solvedToday}/${due.length + reviewedToday + goal}',
                          label: "Today's goal",
                          color: Accent.green,
                        ),
                        StatTile(icon: Icons.event_note_rounded, value: '${due.length}', label: 'Due now', color: Accent.red),
                      ],
                    ),
                  ),
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: dueList(2))),
                        Expanded(child: Column(children: upcomingList(2))),
                      ],
                    )
                  else ...[
                    ...dueList(2),
                    ...upcomingList(2 + due.length),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The hero card: exactly one thing to do next, with progress towards today's goal.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.due,
    required this.solvedToday,
    required this.goal,
    required this.next,
    required this.sheetStep,
    required this.onReview,
    required this.onSolve,
    required this.onOpenSheet,
  });

  final List<Problem> due;
  final int solvedToday;
  final int goal;
  final SheetProblem? next;
  final String? sheetStep;
  final VoidCallback onReview;
  final VoidCallback onSolve;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.85);
    final (label, title, subtitle, button, icon, action) = due.isNotEmpty
        ? (
            'STEP 1 · REVIEW',
            '${due.length} ${due.length == 1 ? 'problem' : 'problems'} to review',
            '${due.first.name}${due.length > 1 ? ' and ${due.length - 1} more' : ''} · about ${(due.length * 0.5).ceil()} min',
            'Start review',
            Icons.play_arrow_rounded,
            onReview,
          )
        : solvedToday < goal
        ? (
            'STEP 2 · SOLVE',
            next?.title ?? 'Start the A2Z sheet',
            next == null
                ? 'Solve problems in order; each one comes back for review.'
                : 'Next in ${sheetStep ?? 'the sheet'} · ${goal - solvedToday} new to go today',
            next == null ? 'Open the sheet' : 'Solve it',
            next == null ? Icons.menu_book_rounded : Icons.terminal_rounded,
            next == null ? onOpenSheet : onSolve,
          )
        : (
            "TODAY'S GOAL",
            'Done for today 🎉',
            'Every review cleared${goal > 0 ? ' and $solvedToday new solved' : ''}. Come back tomorrow, or keep going.',
            'Solve one more',
            Icons.add_rounded,
            next == null ? onOpenSheet : onSolve,
          );
    final progress = due.isNotEmpty ? 0.0 : (goal == 0 ? 1.0 : (solvedToday / goal).clamp(0.0, 1.0));
    return HeroCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: white70),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Grow(
                  value: progress,
                  builder: (context, v) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: HeroCard.ink(context),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: action,
                  icon: Icon(icon),
                  label: Text(button),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Bob(height: 6, child: Image.asset('assets/illustrations/stack.png', width: 96, height: 96)),
        ],
      ),
    );
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
          child: Row(
            children: [
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      problem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill.difficulty(problem.difficulty),
                        Text(problem.topic, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(overdue > 0 ? Icons.event_busy_rounded : Icons.event_rounded, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
