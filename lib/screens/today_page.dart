import 'dart:async';

import 'package:flutter/material.dart';

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
  final _heroKey = GlobalKey(), _goalKey = GlobalKey();
  bool _showDue = false, _showUpcoming = false;

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
                // Folded by default: the card on top already starts these reviews. Tap to open the list.
                SectionTitle(
                  'Due now (${due.length})',
                  action: due.isEmpty ? null : (_showDue ? 'Hide' : 'Show'),
                  onAction: () => setState(() => _showDue = !_showDue),
                ),
                if (due.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text('Nothing due. Nice!', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                for (final (i, p) in _showDue ? due.indexed : const <(int, Problem)>[])
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
                if (upcoming.isNotEmpty)
                  SectionTitle(
                    'Coming up this week (${upcoming.length})',
                    action: _showUpcoming ? 'Hide' : 'Show',
                    onAction: () => setState(() => _showUpcoming = !_showUpcoming),
                  ),
                for (final (i, p) in _showUpcoming ? upcoming.indexed : const <(int, Problem)>[])
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
                          compact: true,
                        ),
                        StatTile(
                          icon: Icons.event_note_rounded,
                          value: '${due.length}',
                          label: 'Due now',
                          color: Accent.red,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  _AptitudeDue(store: widget.store),
                  Rise(
                    index: 2,
                    child: _ActionRow(
                      store: widget.store,
                      problems: problems,
                      challenge: sheet != null && Prefs.sheetId.value == 'a2z' ? dailyChallenge(sheet, now) : null,
                      onChallenge: (c) => _solve(sheet!, c),
                    ),
                  ),
                  Rise(
                    index: 3,
                    child: _StreakWeek(
                      active: activeDays(problems, stats),
                      streak: days,
                      onTap: () => unawaited(
                        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StreakPage(days: activeDays(problems, stats)))),
                      ),
                    ),
                  ),
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

/// Three square shortcuts side by side: quiz, today's 2× challenge (glowing until done) and a mock interview.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.store, required this.problems, required this.challenge, required this.onChallenge});

  final Store store;
  final List<Problem> problems;
  final SheetProblem? challenge;
  final ValueChanged<SheetProblem> onChallenge;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      final level = p?.level.level ?? 1;
      final quizLocked = problems.length < 3;
      final c = challenge;
      final challengeDone = c != null && problems.any((x) => x.id == c.id);
      void go(Widget page) => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            _Action(
              icon: quizLocked ? Icons.lock_rounded : Icons.quiz_rounded,
              label: 'Quiz',
              sub: quizLocked ? '${3 - problems.length} to unlock' : '${quizShape(level).count} Qs',
              color: Accent.green,
              onTap: quizLocked ? null : () => go(QuizPage(store: store, problems: problems, level: level)),
            ),
            const SizedBox(width: 10),
            if (c != null) ...[
              _Action(
                icon: challengeDone ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                label: challengeDone ? 'Done!' : '2× XP',
                sub: c.title,
                color: Accent.amber,
                glow: !challengeDone,
                onTap: challengeDone ? null : () => onChallenge(c),
              ),
              const SizedBox(width: 10),
            ],
            _Action(
              icon: Icons.timer_rounded,
              label: 'Interview',
              sub: 'vs clock',
              color: Accent.violet,
              onTap: () => go(InterviewSetupPage(store: store, problems: problems)),
            ),
          ],
        ),
      );
    },
  );
}

class _Action extends StatefulWidget {
  const _Action({required this.icon, required this.label, required this.sub, required this.color, this.onTap, this.glow = false});

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback? onTap;
  final bool glow; // breathing glow, for something waiting for you today

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.glow) unawaited(_t.repeat(reverse: true));
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Pressable(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, child) => Container(
            height: 104,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.color.withValues(alpha: widget.glow ? 0.3 + 0.5 * _t.value : 0.15), width: 1.5),
              boxShadow: [
                if (widget.glow)
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15 + 0.25 * _t.value),
                    blurRadius: 10 + 10 * _t.value,
                  ),
              ],
            ),
            child: child,
          ),
          child: Opacity(
            opacity: widget.onTap == null && widget.icon == Icons.lock_rounded ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(widget.icon, color: widget.color, size: 22),
                ),
                const Spacer(),
                Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                Text(
                  widget.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streak card: a big flame tile with the count, and this week's days (done ✓, missed !, today in progress).
class _StreakWeek extends StatelessWidget {
  const _StreakWeek({required this.active, required this.streak, required this.onTap});

  final Set<DateTime> active;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final monday = addDays(now, -(now.weekday - 1));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C4EF5), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned(
                    right: -14,
                    bottom: -18,
                    child: _Flicker(child: Text('🔥', style: TextStyle(fontSize: 72))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: streak.toDouble()),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            '${v.round()}',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ),
                        const Text(
                          'Streak days',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 112,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This week', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          _Day(
                            label: names[i],
                            state: switch (addDays(monday, i)) {
                              final d when active.contains(d) => _DayState.done,
                              final d when d == now => _DayState.today,
                              final d when d.isBefore(now) => _DayState.missed,
                              _ => _DayState.future,
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DayState { done, missed, today, future }

class _Day extends StatelessWidget {
  const _Day({required this.label, required this.state});

  final String label;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color bg, Widget mark) = switch (state) {
      _DayState.done => (Accent.green.withValues(alpha: 0.14), const Icon(Icons.check_circle_rounded, color: Accent.green, size: 20)),
      _DayState.missed => (Accent.red.withValues(alpha: 0.12), const Icon(Icons.priority_high_rounded, color: Accent.red, size: 18)),
      _DayState.today => (
        colors.primary.withValues(alpha: 0.14),
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            value: 0.3,
            strokeWidth: 3,
            color: colors.primary,
            backgroundColor: colors.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      _DayState.future => (colors.surfaceContainerHighest, Icon(Icons.circle_outlined, color: colors.outlineVariant, size: 18)),
    };
    return Container(
      width: 30,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: state == _DayState.today ? Border.all(color: colors.primary, width: 1.5) : null,
      ),
      child: Column(
        children: [
          SizedBox(height: 20, child: Center(child: mark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A flame that sways and breathes.
class _Flicker extends StatefulWidget {
  const _Flicker({required this.child});

  final Widget child;

  @override
  State<_Flicker> createState() => _FlickerState();
}

class _FlickerState extends State<_Flicker> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => Transform.rotate(
      angle: (_t.value - 0.5) * 0.12,
      alignment: Alignment.bottomCenter,
      child: Transform.scale(scale: 0.95 + 0.08 * _t.value, alignment: Alignment.bottomCenter, child: child),
    ),
    child: widget.child,
  );
}
