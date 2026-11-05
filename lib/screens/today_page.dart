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
    Widget stat(String emoji, String n) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$emoji '),
            TextSpan(
              text: n,
              style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
            ),
          ],
        ),
        style: theme.textTheme.titleSmall,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Text(
              'WEEK',
              style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            stat('✅', '$solved'),
            stat('🔁', '$reviews'),
            stat('🔥', '$streak'),
            const Spacer(),
            IconButton(
              tooltip: 'Share my week',
              onPressed: () => openLink(context, 'https://wa.me/?text=${Uri.encodeComponent(text)}', inApp: false),
              icon: Icon(Icons.share_rounded, color: theme.colorScheme.primary, size: 20),
            ),
          ],
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
      // A row of friends: avatar ringed in fire when they were active today, flame count and level underneath.
      return SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            for (final x in items)
              Tooltip(
                message: '${x.entry.name} · ${x.entry.solved} solved · ${_ago(x.at)}',
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: DateTime.now().difference(x.at).inHours < 24
                              ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFEF4444)])
                              : null,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(x.entry.name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🔥${x.entry.streak} · Lv${x.entry.level}',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
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
