import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/leetcode.dart';
import '../data/sounds.dart';
import '../data/statements.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'coach.dart';
import 'code_pad.dart';
import 'goal_celebration.dart';
import 'motion.dart';
import 'open_link.dart';
import 'solution_sheet.dart';
import 'solve_page.dart';
import 'streak_page.dart';
import 'widgets.dart';

/// Flashcard review: recall the approach, flip to check against your solution card, grade it.
/// Grade with the four buttons; Undo takes back the last grade.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.store, required this.queue, this.streakBefore, this.reviewDays = const {}});

  final Store store;
  final List<Problem> queue; // fixed when the session starts, so grading does not reshuffle it
  final int? streakBefore; // set when this is the first review of the day: show the streak celebration at the end
  final Set<DateTime> reviewDays;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _index = 0;
  bool _flipped = false;
  final _history = <({Problem before, Grade grade})>[]; // for undo and the summary
  final _solutions = <String, Solution>{}; // loaded when a card is flipped (one read each)
  late final _patterns = {for (final p in widget.queue) p.id: p.patterns}; // edits during the session show at once

  final _showKey = GlobalKey(), _gradeKey = GlobalKey();
  final _statements = <String, Future<String?>>{}; // LeetCode question text, fetched once per card

  Future<String?>? _statement(Problem p) => switch (leetCodeSlug(p.url)) {
    final slug? => _statements[p.id] ??= leetCodeStatement(slug),
    null => null,
  };

  /// A quick pop of praise after each grade, so every review feels like progress.
  void _cheer(Grade grade) {
    final (icon, text, color) = switch (grade) {
      Grade.easy => (Icons.bolt_rounded, 'Flawless!', const Color(0xFF22C55E)),
      Grade.good => (Icons.check_circle_rounded, 'Nailed it!', const Color(0xFF6C4EF5)),
      Grade.hard => (Icons.fitness_center_rounded, 'Tough one, you held on!', const Color(0xFFF59E0B)),
      Grade.again => (Icons.refresh_rounded, "It'll stick next time", const Color(0xFFEF4444)),
    };
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            builder: (context, t, child) => Opacity(
              opacity: t < 0.75 ? 1 : (1 - t) * 4,
              child: Transform.translate(
                offset: Offset(0, -40 * t),
                child: Transform.scale(scale: Curves.elasticOut.transform((t * 2.2).clamp(0, 1)), child: child),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+${grade.remembered ? 10 : 3} XP',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1150), entry.remove);
  }

  @override
  void initState() {
    super.initState();
    showTipsOnce(context, 'review', [
      (
        target: _showKey,
        title: 'Recall first',
        text: 'Think of the approach, then tap to flip the card and compare with your solution card.',
      ),
    ]);
  }

  Problem get _current => widget.queue[_index];
  bool get _done => _index >= widget.queue.length;

  final _loading = <String>{};
  final _hints = <String, int>{}; // hints shown per problem

  List<String> _hintsFor(Problem p) => [
    if ((_patterns[p.id] ?? const []).isNotEmpty) 'Pattern: ${_patterns[p.id]!.join(', ')}',
    if (_solutions[p.id]?.idea case final idea? when idea.isNotEmpty) 'Key idea: $idea',
  ];
  final _shared = <String, ({String text, String by})?>{}; // the question bank entry, one read per problem

  /// Loads the solution card (one read) as soon as a card shows, so its question can sit on the front.
  void _load(Problem p) {
    if (_solutions.containsKey(p.id) || !_loading.add(p.id)) return;
    if (leetCodeSlug(p.url) == null) {
      unawaited(
        widget.store.sharedQuestion(p.id).then((q) {
          if (mounted) setState(() => _shared[p.id] = q);
        }, onError: (Object _) {}),
      );
    }
    unawaited(
      widget.store.solution(p.id).then((s) {
        if (mounted) setState(() => _solutions[p.id] = s);
      }, onError: (Object _) {}),
    );
  }

  Future<void> _flip() async {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _flipped = true);
    showTipsOnce(context, 'review-grade', [
      (target: _gradeKey, title: 'Grade honestly', text: 'Again brings it back tomorrow; Easy pushes it far out. Undo fixes a wrong tap.'),
    ]);
    final id = _current.id;
    if (_solutions.containsKey(id)) return;
    final s = await widget.store.solution(id);
    if (mounted) setState(() => _solutions[id] = s);
  }

  void _grade(Grade grade) {
    final p = _current;
    unawaited(grade.remembered ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
    unawaited(widget.store.review(p, grade)); // saved locally at once, syncs when online
    _cheer(grade);
    play(grade.remembered ? Sound.correct : Sound.wrong);
    setState(() {
      _history.add((before: p, grade: grade));
      _index++;
      _flipped = false;
    });
    if (_done) {
      // Every finished session gets a burst of confetti over the summary.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) confettiBurst(context);
      });
    }
    if (_done && widget.streakBefore != null) {
      // Session done: show the streak growing, then the summary underneath.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          Navigator.push(
            context,
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => StreakCelebration(before: widget.streakBefore!, reviewDays: widget.reviewDays),
              transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
            ),
          ),
        );
      });
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    unawaited(HapticFeedback.selectionClick());
    unawaited(widget.store.undoReview(last.before, last.grade));
    setState(() {
      _index--;
      _flipped = true;
    });
  }

  Future<void> _editCard(Problem p) async {
    final card = await editSolutionCard(
      context,
      title: p.name,
      initial: _solutions[p.id] ?? const Solution(),
      patterns: _patterns[p.id] ?? const [],
    );
    if (card == null) return;
    unawaited(widget.store.setSolution(p.id, card.solution));
    unawaited(widget.store.setPatterns(p.id, card.patterns));
    // A new question for a problem nobody has shared yet goes to the shared bank for everyone.
    final q = card.solution.question;
    if (q.isNotEmpty && _shared[p.id] == null && leetCodeSlug(p.url) == null) {
      final by = (FirebaseAuth.instance.currentUser?.displayName ?? '').split(' ').first;
      unawaited(widget.store.shareQuestion(p.id, q, by).catchError((Object _) {}));
      _shared[p.id] = (text: q, by: by.isEmpty ? 'You' : by);
    }
    setState(() {
      _solutions[p.id] = card.solution;
      _patterns[p.id] = card.patterns;
    });
  }

  /// Solve it again in code; when every test passes you can submit, which grades the card Good.
  Future<void> _practice(Problem p) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PracticeSheet(problem: p),
    );
    if ((submitted ?? false) && mounted && !_done && _current.id == p.id) _grade(Grade.good);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.queue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_done ? 'Review complete' : 'Review ${_index + 1} of $total'),
        actions: [
          if (_history.isNotEmpty && !_done)
            TextButton.icon(onPressed: _undo, icon: const Icon(Icons.undo_rounded), label: const Text('Undo')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Grow(
            value: _index / total,
            duration: const Duration(milliseconds: 400),
            builder: (context, v) => LinearProgressIndicator(value: v),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(_index), child: _done ? _summary(context) : _card(context)),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final p = _current;
    _load(p);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                // Grades come only from the buttons: a swipe here clashed with the phone's back gesture
                // and graded cards "Again" by accident.
                child: _FlipCard(
                  flipped: _flipped,
                  front: _Face(
                    onTap: _flip,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pill.difficulty(p.difficulty),
                              Pill(p.topic, color: colors.primary),
                              Pill(p.mastered ? 'Mastered' : 'Stage ${p.stage + 1}/${reviewIntervals.length}', color: Accent.sky),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            p.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solved ${prettyDay(p.solvedOn)} · ${dueLabel(p.daysOverdue(today()))}',
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          if (_statement(p) case final statement?)
                            QuestionCard(statement: statement, platform: p.platform, onOpen: () => openLink(context, p.url!))
                          else if (_solutions[p.id]?.question case final q? when q.isNotEmpty)
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Question', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    Text(q, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                                  ],
                                ),
                              ),
                            )
                          else if (_shared[p.id] case final shared?)
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Question',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Text(
                                          'Added by ${shared.by}',
                                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(shared.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                                  ],
                                ),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _editCard(p),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add the question (shared with everyone)'),
                            ),
                          const SizedBox(height: 28),
                          Icon(Icons.psychology_rounded, size: 42, color: colors.primary),
                          const SizedBox(height: 8),
                          Text("What's the approach?", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Think of the pattern, the key idea and the complexity.\nThen tap to check.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          // Hint ladder: pattern first, then the key idea, before flipping the whole card.
                          if (_hintsFor(p) case final hints when hints.isNotEmpty) ...[
                            for (final h in hints.take(_hints[p.id] ?? 0))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '💡 $h',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            if ((_hints[p.id] ?? 0) < hints.length)
                              TextButton.icon(
                                onPressed: () => setState(() => _hints[p.id] = (_hints[p.id] ?? 0) + 1),
                                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                                label: Text('Hint ${(_hints[p.id] ?? 0) + 1} of ${hints.length}'),
                              ),
                          ],
                          Wrap(
                            spacing: 8,
                            children: [
                              if (p.url != null)
                                TextButton.icon(
                                  onPressed: () => openLink(context, p.url!),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: Text(p.platform),
                                ),
                              FilledButton.icon(
                                onPressed: () => _practice(p),
                                icon: const Icon(Icons.terminal_rounded, size: 18),
                                label: const Text('Practice in code · prove it'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  back: _Face(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 16),
                          if (_solutions[p.id] == null)
                            const Center(
                              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                            )
                          else
                            SolutionView(solution: _solutions[p.id]!, patterns: _patterns[p.id] ?? const [], onEdit: () => _editCard(p)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: !_flipped
                    ? FilledButton.icon(
                        key: _showKey,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: _flip,
                        icon: const Icon(Icons.flip_rounded),
                        label: const Text('Show my solution'),
                      )
                    : Column(
                        key: _gradeKey,
                        children: [
                          Text('How well did you remember it?', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final (i, g) in Grade.values.indexed) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _GradeButton(grade: g, days: daysAfter(p.stage, g), onPressed: () => _grade(g)),
                                ),
                              ],
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

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = _history.length;
    final remembered = _history.where((h) => h.grade.remembered).length;
    final nextDue = [for (final h in _history) h.before.review(grade: h.grade, on: today()).nextDue];
    final next = nextDue.isEmpty ? null : nextDue.reduce((a, b) => a.isBefore(b) ? a : b);
    final nextCount = next == null ? 0 : nextDue.where((d) => d == next).length;
    final days = next?.difference(today()).inDays;
    final when = days == null ? '' : (days <= 1 ? 'Tomorrow' : prettyDay(next!));
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) => Transform.scale(scale: t, child: child),
                    child: Image.asset('assets/illustrations/trophy.png', width: 190, height: 190),
                  ),
                  Rise(
                    index: 2,
                    child: Text(
                      'Nice work!',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Rise(
                    index: 3,
                    child: Text(
                      "You've completed today's revisions.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Rise(
                    index: 4,
                    child: Row(
                      children: [
                        StatTile(icon: Icons.check_circle_rounded, value: '$total', label: 'Reviewed', color: Accent.green),
                        const SizedBox(width: 10),
                        StatTile(icon: Icons.psychology_rounded, value: '$remembered', label: 'Remembered', color: Accent.orange),
                        const SizedBox(width: 10),
                        StatTile(
                          icon: Icons.bar_chart_rounded,
                          value: '${total == 0 ? 0 : (remembered * 100 / total).round()}%',
                          label: 'Recall rate',
                          color: Accent.violet,
                        ),
                      ],
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 14),
                    Rise(
                      index: 5,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.event_rounded, color: colors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Next review', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                                    Text(when, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                    Text(
                                      '$nextCount ${nextCount == 1 ? 'problem' : 'problems'}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Rise(
                    index: 6,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

/// One side of the flashcard.
class _Face extends StatelessWidget {
  const _Face({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}

/// Turns over in 3D from [front] to [back] when [flipped] becomes true.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.flipped, required this.front, required this.back});

  final bool flipped;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: flipped ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 450),
    curve: Curves.easeInOutCubic,
    builder: (context, t, _) {
      final showBack = t >= 0.5;
      final angle = t * pi;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // perspective
          ..rotateY(showBack ? angle - pi : angle),
        child: showBack ? back : front,
      );
    },
  );
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.grade, required this.days, required this.onPressed});

  final Grade grade;
  final int days;
  final VoidCallback onPressed;

  static Color colorOf(Grade g) => switch (g) {
    Grade.again => Accent.red,
    Grade.hard => Accent.amber,
    Grade.good => Accent.violet,
    Grade.easy => Accent.green,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(grade);
    return Pressable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: grade == Grade.good ? 1 : 0.13),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              grade.label,
              style: TextStyle(fontWeight: FontWeight.w800, color: grade == Grade.good ? Colors.white : color),
            ),
            const SizedBox(height: 2),
            Text(
              days == 1 ? '1 day' : '$days days',
              style: TextStyle(fontSize: 12, color: grade == Grade.good ? Colors.white70 : color.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional: write the solution in the editor and run it, without leaving the review.
class _PracticeSheet extends StatefulWidget {
  const _PracticeSheet({required this.problem});

  final Problem problem;

  @override
  State<_PracticeSheet> createState() => _PracticeSheetState();
}

class _PracticeSheetState extends State<_PracticeSheet> {
  final _code = CodeController();
  bool _passed = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.92,
    maxChildSize: 0.95,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        CodePad(
          controller: _code,
          title: 'Practice: ${widget.problem.name}',
          saveKey: widget.problem.id,
          onVerdict: (v) => setState(() => _passed = v ?? false),
        ),
        const SizedBox(height: 12),
        // Only a passing run can clear the review from here.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _passed
              ? FilledButton.icon(
                  key: const ValueKey('submit'),
                  style: FilledButton.styleFrom(backgroundColor: Accent.green, minimumSize: const Size.fromHeight(54)),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('All tests pass · Submit review'),
                )
              : Text(
                  'Add a test case with the expected output and run it. When all pass, you can submit.',
                  key: const ValueKey('hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
        ),
      ],
    ),
  );
}
