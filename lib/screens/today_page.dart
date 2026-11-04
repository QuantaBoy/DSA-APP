import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/leaderboard.dart';
import '../data/prefs.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/ascension.dart';
import '../logic/models.dart';
import '../logic/quiz.dart';
import '../logic/srs.dart';
import 'aptitude_page.dart';
import 'ascension_view.dart';
import 'coach.dart';
import 'goal_celebration.dart';
import 'interview_page.dart';
import 'motion.dart';
import 'open_link.dart';
import 'quiz_page.dart';
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
      (target: _goalKey, title: 'New today', text: 'New problems solved today out of your daily goal. Change the goal in Profile.'),
      (
        target: _streakKey,
        title: 'Keep the streak',
        text: 'Revise every day to grow it. Miss one day a week and a streak freeze saves it. Tap for details.',
      ),
    ]);
  }

  Future<void> _review(List<Problem> queue, {required int streakNow, required bool firstToday}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReviewPage(
        store: widget.store,
        queue: queue,
        // First review of the day grows the streak: celebrate it when the session ends.
        streakBefore: firstToday ? streakNow : null,
        reviewDays: {...activeDays(widget.problems, widget.stats), today()},
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

  /// Plays the goal party the first time today's goal is seen complete (once a day).
  void _maybeCelebrate({required bool done, required int streak, required int solvedToday}) {
    final day = dayKey(today());
    if (!done || Prefs.goalCelebrated == day) return;
    Prefs.markGoalCelebrated(day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Navigator.push(
          context,
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => GoalCelebration(streak: streak, solvedToday: solvedToday),
            transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
          ),
        ),
      );
    });
  }

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
    final days = streakWithFreezes(activeDays(problems, stats), now);
    _maybeCelebrate(
      done: due.isEmpty && (solvedToday > 0 || reviewedToday > 0) && solvedToday >= Prefs.dailyNewGoal.value,
      streak: days,
      solvedToday: solvedToday,
    );

    return ValueListenableBuilder(
      valueListenable: Prefs.dailyNewGoal,
      builder: (context, goal, _) => FutureBuilder<Sheet>(
        future: loadSheet(Prefs.sheetId.value),
        builder: (context, snap) {
          final sheet = snap.data;
          final next = sheet?.nextUnsolved({for (final p in problems) p.id});
          final hero = _NextStep(
            due: due,
            solvedToday: solvedToday,
            goal: goal,
            next: next,
            sheetStep: next == null || sheet == null ? null : sheet.steps[next.step - 1],
            // Today's flow: reviews first, then straight on to the new problem if the goal still needs one.
            onReview: () async {
              await _review(due, streakNow: days, firstToday: !activeDays(problems, stats).contains(now));
              if (!context.mounted || sheet == null || next == null || solvedToday >= goal) return;
              final go = await showAdaptiveDialog<bool>(
                context: context,
                builder: (context) => AlertDialog.adaptive(
                  title: const Text('Reviews done ✓'),
                  content: Text('Next up: ${next.title}. Solve it now?'),
                  actions: [
                    adaptiveAction(context, 'Later', () => Navigator.pop(context, false)),
                    adaptiveAction(context, 'Solve it', () => Navigator.pop(context, true), primary: true),
                  ],
                ),
              );
              if (go ?? false) _solve(sheet, next);
            },
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
                      onTap: () => unawaited(_review([p], streakNow: days, firstToday: !activeDays(problems, stats).contains(now))),
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
                  const Rise(child: PowerStrip()),
                  const SizedBox(height: 14),
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
                          onTap: () => unawaited(
                            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StreakPage(days: activeDays(problems, stats)))),
                          ),
                        ),
                        // New problems solved today out of the daily goal; past the goal it bursts into Overdrive.
                        StatTile(
                          key: _goalKey,
                          icon: solvedToday > goal && goal > 0 ? Icons.local_fire_department_rounded : Icons.task_alt_rounded,
                          value: goal == 0 ? '✓' : '$solvedToday/$goal',
                          label: solvedToday > goal && goal > 0
                              ? 'Overdrive${solvedToday > overdriveFrom ? ' +${(solvedToday - overdriveFrom) * overdriveXp}' : ''}'
                              : 'New today',
                          color: Accent.green,
                          fire: solvedToday > goal && goal > 0,
                        ),
                        StatTile(icon: Icons.event_note_rounded, value: '${due.length}', label: 'Due now', color: Accent.red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Rise(
                    index: 2,
                    child: Pressable(
                      onTap: () => unawaited(
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => InterviewSetupPage(store: widget.store, problems: problems),
                          ),
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Accent.violet.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.timer_rounded, color: Accent.violet),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Mock interview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                    Text(
                                      'A random problem against the clock',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _AptitudeDue(store: widget.store),
                  if (sheet != null && Prefs.sheetId.value == 'a2z')
                    if (dailyChallenge(sheet, now) case final c?)
                      _Challenge(problem: c, done: problems.any((p) => p.id == c.id), onTap: () => _solve(sheet, c)),
                  _QuizCard(store: widget.store, problems: problems),
                  if (Prefs.leaderboard.value) const _FriendsFeed(),
                  _WeekRecap(problems: problems, stats: stats, streak: days),
                  _WeakSpot(
                    stats: stats,
                    problems: problems,
                    onReview: (ps) => _review(ps, streakNow: days, firstToday: !activeDays(problems, stats).contains(now)),
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

/// Shown only when aptitude questions are due: opens a review of them.
class _AptitudeDue extends StatelessWidget {
  const _AptitudeDue({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AptCard>>(
    stream: store.aptCards(),
    builder: (context, snap) {
      final now = today();
      final due = [...?snap.data?.where((c) => c.isDue(now))]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
      if (due.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Pressable(
          onTap: () => unawaited(
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AptReviewPage(store: store, cards: due),
              ),
            ),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Accent.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.calculate_rounded, color: Accent.orange),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${due.length} aptitude ${due.length == 1 ? 'question' : 'questions'} due',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Pick the right option before it fades',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Quick-fire quiz from your stack. Locked until 3 problems; harder question kinds open as you level up.
class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      final theme = Theme.of(context);
      final level = p?.level.level ?? 1;
      final locked = problems.length < 3;
      final shape = quizShape(level);
      final nextKind = QuizKind.values.where((k) => k.fromLevel > level).firstOrNull;
      final subtitle = locked
          ? 'Solve ${3 - problems.length} more to unlock'
          : '${shape.count} questions · ${shape.seconds}s each${nextKind == null ? '' : ' · ${nextKind.label} at Lv ${nextKind.fromLevel}'}';
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Pressable(
          onTap: locked
              ? null
              : () => unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => QuizPage(store: store, problems: problems, level: level),
                    ),
                  ),
                ),
          child: Opacity(
            opacity: locked ? 0.55 : 1,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Accent.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(locked ? Icons.lock_rounded : Icons.quiz_rounded, color: Accent.green),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick quiz', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The topic you remember least (3+ reviews, under 60% recall): one tap reviews all its problems.
class _WeakSpot extends StatelessWidget {
  const _WeakSpot({required this.stats, required this.problems, required this.onReview});

  final Stats stats;
  final List<Problem> problems;
  final void Function(List<Problem>) onReview;

  @override
  Widget build(BuildContext context) {
    final weak = [
      for (final e in stats.topics.entries)
        if (e.value.total >= 3 && e.value.remembered / e.value.total < 0.6) (topic: e.key, recall: e.value.remembered / e.value.total),
    ]..sort((a, b) => a.recall.compareTo(b.recall));
    final w = weak.firstOrNull;
    final inTopic = w == null ? const <Problem>[] : problems.where((p) => p.topic == w.topic).toList();
    if (w == null || inTopic.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Pressable(
        onTap: () => onReview(inTopic),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Accent.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.trending_down_rounded, color: Accent.red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weak spot: ${w.topic}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${(w.recall * 100).round()}% recall · review its ${inTopic.length} problems now',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One problem a day for everyone, worth double XP when solved that day.
class _Challenge extends StatelessWidget {
  const _Challenge({required this.problem, required this.done, required this.onTap});

  final SheetProblem problem;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Pressable(
        onTap: done ? null : onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Accent.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                  child: Icon(done ? Icons.emoji_events_rounded : Icons.bolt_rounded, color: Accent.amber),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? 'Daily challenge done! 2× XP' : 'Daily challenge · 2× XP',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${problem.title}${problem.difficulty == null ? '' : ' · ${problem.difficulty}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!done) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The last 7 days at a glance, with a button to brag on WhatsApp.
class _WeekRecap extends StatelessWidget {
  const _WeekRecap({required this.problems, required this.stats, required this.streak});

  final List<Problem> problems;
  final Stats stats;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final from = addDays(now, -6);
    bool inWeek(DateTime d) => !dateOnly(d).isBefore(from);
    final solved = problems.where((p) => inWeek(p.solvedOn)).length;
    final reviews = stats.days.entries.where((e) => inWeek(e.key)).fold(0, (a, e) => a + e.value);
    if (solved + reviews == 0) return const SizedBox.shrink();
    final level = power.value?.level.level;
    final theme = Theme.of(context);
    final text =
        'My week on Memory Stack: $solved solved, $reviews reviews, $streak-day streak 🔥'
        '${level == null ? '' : ', Level $level'}. https://memory-stack-e6990.web.app';
    Widget stat(String n, String label) => Expanded(
      child: Column(
        children: [
          Text(
            n,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
          ),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS WEEK',
                style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(children: [stat('$solved', 'solved'), stat('$reviews', 'reviews'), stat('$streak', 'day streak')]),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => openLink(context, 'https://wa.me/?text=${Uri.encodeComponent(text)}', inApp: false),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What friends on the leaderboard did lately: a nudge to keep up.
class _FriendsFeed extends StatefulWidget {
  const _FriendsFeed();

  @override
  State<_FriendsFeed> createState() => _FriendsFeedState();
}

class _FriendsFeedState extends State<_FriendsFeed> {
  late final _recent = Leaderboard().recent().catchError((Object _) => <({LeaderboardEntry entry, DateTime at})>[]);

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    return d.inMinutes < 60 ? '${max(1, d.inMinutes)}m ago' : (d.inHours < 24 ? '${d.inHours}h ago' : '${d.inDays}d ago');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _recent,
    builder: (context, snap) {
      final me = FirebaseAuth.instance.currentUser?.uid;
      final items = [...?snap.data?.where((x) => x.entry.uid != me)];
      if (items.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FRIENDS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final x in items.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 16, child: Text(x.entry.name.characters.first.toUpperCase())),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${x.entry.name} · Lv ${x.entry.level} · 🔥 ${x.entry.streak} · ${x.entry.solved} solved',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(_ago(x.at), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
