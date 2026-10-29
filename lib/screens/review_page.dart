import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'code_pad.dart';
import 'motion.dart';
import 'open_link.dart';
import 'solution_sheet.dart';
import 'streak_page.dart';
import 'widgets.dart';

/// Flashcard review: recall the approach, flip to check against your solution card, grade it.
/// Swipe right for Good, left for Again; Undo takes back the last grade.
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

  Problem get _current => widget.queue[_index];
  bool get _done => _index >= widget.queue.length;

  Future<void> _flip() async {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _flipped = true);
    final id = _current.id;
    if (_solutions.containsKey(id)) return;
    final s = await widget.store.solution(id);
    if (mounted) setState(() => _solutions[id] = s);
  }

  void _grade(Grade grade) {
    final p = _current;
    unawaited(grade.remembered ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
    unawaited(widget.store.review(p, grade)); // saved locally at once, syncs when online
    setState(() {
      _history.add((before: p, grade: grade));
      _index++;
      _flipped = false;
    });
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
    setState(() {
      _solutions[p.id] = card.solution;
      _patterns[p.id] = card.patterns;
    });
  }

  Future<void> _practice(Problem p) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PracticeSheet(problem: p),
  );

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
                child: _SwipeCard(
                  enabled: _flipped,
                  onSwipe: (right) => _grade(right ? Grade.good : Grade.again),
                  child: _FlipCard(
                    flipped: _flipped,
                    front: _Face(
                      onTap: _flip,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          Wrap(
                            spacing: 8,
                            children: [
                              if (p.url != null)
                                TextButton.icon(
                                  onPressed: () => openLink(context, p.url!),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: Text(p.platform),
                                ),
                              TextButton.icon(
                                onPressed: () => _practice(p),
                                icon: const Icon(Icons.terminal_rounded, size: 18),
                                label: const Text('Practice in code'),
                              ),
                            ],
                          ),
                        ],
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: !_flipped
                    ? FilledButton.icon(
                        key: const ValueKey('show'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: _flip,
                        icon: const Icon(Icons.flip_rounded),
                        label: const Text('Show my solution'),
                      )
                    : Column(
                        key: const ValueKey('grade'),
                        children: [
                          Text(
                            'How well did you remember it?  Swipe → Good · ← Again',
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
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

/// Drag the card sideways to grade it; it tilts and tints towards the grade, then flies off.
class _SwipeCard extends StatefulWidget {
  const _SwipeCard({required this.child, required this.enabled, required this.onSwipe});

  final Widget child;
  final bool enabled; // only after the answer is shown
  final void Function(bool right) onSwipe;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final progress = (_dx / (width * 0.35)).clamp(-1.0, 1.0);
    final tint = progress > 0 ? Accent.green : Accent.red;
    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => _dx += d.delta.dx) : null,
      onHorizontalDragEnd: widget.enabled
          ? (d) {
              final fling = d.primaryVelocity ?? 0;
              if (progress.abs() >= 1 || fling.abs() > 900) {
                widget.onSwipe((progress.abs() >= 1 ? progress : fling) > 0);
              } else {
                setState(() => _dx = 0);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: _dx == 0 ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(_dx, 0, 0)..rotateZ(progress * 0.12),
        transformAlignment: Alignment.bottomCenter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (progress != 0)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.18 * progress.abs()),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: tint.withValues(alpha: progress.abs()), width: 3),
                  ),
                  alignment: progress > 0 ? Alignment.topLeft : Alignment.topRight,
                  padding: const EdgeInsets.all(20),
                  child: Opacity(
                    opacity: progress.abs(),
                    child: Text(
                      progress > 0 ? 'GOOD' : 'AGAIN',
                      style: TextStyle(color: tint, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
      children: [CodePad(controller: _code, title: 'Practice: ${widget.problem.name}')],
    ),
  );
}
