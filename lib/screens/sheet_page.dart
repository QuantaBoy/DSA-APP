import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'coach.dart';
import 'motion.dart';
import 'open_link.dart';
import 'solution_sheet.dart';
import 'solve_page.dart';
import 'widgets.dart';

/// Striver's A2Z sheet: continue where you left off, tick problems as solved.
/// Ticking adds the problem to your review stack; unticking removes it.
class SheetPage extends StatefulWidget {
  const SheetPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  State<SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<SheetPage> {
  late final Future<Sheet> _sheet = loadA2zSheet();
  int? _step; // topic filter chip: null = all steps
  final _continueKey = GlobalKey(), _chipsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    showTipsOnce(context, 'sheet', [
      (
        target: _continueKey,
        title: 'Continue where you left off',
        text: 'Solve here opens the editor. I solved it adds the problem to your reviews.',
      ),
      (target: _chipsKey, title: 'Jump to a topic', text: 'Filter the 402 problems by step: Arrays, Strings, Graphs and more.'),
    ]);
  }

  /// Adds the problem to the stack (with Undo). With [askForCard], also opens the solution card editor.
  Future<void> _markSolved(Sheet sheet, SheetProblem p, {bool askForCard = false}) async {
    var problem = sheet.toProblem(p, today());
    unawaited(HapticFeedback.lightImpact());
    unawaited(widget.store.addProblem(problem)); // saved locally at once, syncs when online
    if (askForCard) {
      final card = await editSolutionCard(context, title: p.title, saveLabel: 'Save card');
      if (card != null) {
        problem = problem.copyWith(patterns: card.patterns);
        unawaited(widget.store.addProblem(problem, solution: card.solution));
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${p.title} added. First review ${prettyDay(problem.nextDue)}.'),
          action: SnackBarAction(label: 'Undo', onPressed: () => unawaited(widget.store.deleteProblem(problem))),
        ),
      );
  }

  void _solve(Sheet sheet, SheetProblem p, bool solved) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SolvePage(store: widget.store, sheet: sheet, problem: p, solved: solved),
    ),
  );

  Future<void> _unmark(SheetProblem p) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Mark ${p.title} as not solved?'),
        content: const Text('It is removed from your reviews, with its solution card.'),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Remove', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok == true) unawaited(widget.store.deleteProblem(widget.problems.firstWhere((x) => x.id == p.id)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Sheet>(
      future: _sheet,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not load the sheet: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final sheet = snap.data!;
        final solved = {for (final p in widget.problems) p.id};
        final done = sheet.problems.where((p) => solved.contains(p.id)).length;
        final next = sheet.nextUnsolved(solved);
        final theme = Theme.of(context);

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$done',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: ' / ${sheet.problems.length} solved',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '${(done * 100 / sheet.problems.length).round()}%',
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Grow(
                    value: done / sheet.problems.length,
                    builder: (context, v) => LinearProgressIndicator(value: v, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
            ),
            if (next != null)
              KeyedSubtree(
                key: _continueKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutBack,
                  // Stretch the card to full width (the default layout centres and shrinks it).
                  layoutBuilder: (current, previous) => Stack(fit: StackFit.passthrough, children: [...previous, ?current]),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
                  ),
                  child: _ContinueCard(
                    key: ValueKey(next.id), // the next problem pops in after you tick one
                    sheet: sheet,
                    problem: next,
                    onSolveHere: () => _solve(sheet, next, false),
                    onOpen: () => openLink(context, next.url),
                    onVideo: next.video == null ? null : () => openLink(context, next.video!, inApp: false),
                    onSolved: () => _markSolved(sheet, next, askForCard: true),
                  ),
                ),
              )
            else
              const Padding(padding: EdgeInsets.all(16), child: Text('You finished the whole sheet. Keep up your reviews!')),
            SizedBox(
              key: _chipsKey,
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  for (final (i, label) in ['All', ...sheet.steps].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: (i == 0 ? null : i) == _step,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _step = i == 0 ? null : i),
                      ),
                    ),
                ],
              ),
            ),
            for (var step = 1; step <= sheet.steps.length; step++)
              if (_step == null || _step == step)
                _StepTile(
                  step: step,
                  sheet: sheet,
                  solved: solved,
                  initiallyExpanded: _step == step || (_step == null && next?.step == step),
                  onToggle: (p, isSolved) => isSolved ? _unmark(p) : _markSolved(sheet, p),
                  onOpen: (p) => _solve(sheet, p, solved.contains(p.id)),
                ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Problem list from ${sheet.title} by takeUforward (Striver).',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    super.key,
    required this.sheet,
    required this.problem,
    required this.onSolveHere,
    required this.onOpen,
    required this.onVideo,
    required this.onSolved,
  });

  final Sheet sheet;
  final SheetProblem problem;
  final VoidCallback onSolveHere;
  final VoidCallback onOpen;
  final VoidCallback? onVideo;
  final VoidCallback onSolved;

  @override
  Widget build(BuildContext context) {
    final ghost = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
    );
    return HeroCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTINUE LEARNING',
            style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(problem.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(
            'Step ${problem.step} · ${sheet.steps[problem.step - 1]} · ${problem.section}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (problem.difficulty != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text(problem.difficulty!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: HeroCard.ink(context)),
                onPressed: onSolveHere,
                icon: const Icon(Icons.terminal_rounded),
                label: const Text('Solve here'),
              ),
              OutlinedButton.icon(
                style: ghost,
                onPressed: onSolved,
                icon: const Icon(Icons.check_rounded),
                label: const Text('I solved it'),
              ),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                tooltip: 'Open on ${problem.platform}',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              if (onVideo != null)
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  tooltip: 'Watch video',
                  onPressed: onVideo,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.sheet,
    required this.solved,
    required this.initiallyExpanded,
    required this.onToggle,
    required this.onOpen,
  });

  final int step;
  final Sheet sheet;
  final Set<String> solved;
  final bool initiallyExpanded;
  final void Function(SheetProblem p, bool isSolved) onToggle;
  final void Function(SheetProblem p) onOpen;

  @override
  Widget build(BuildContext context) {
    final problems = sheet.inStep(step);
    final done = problems.where((p) => solved.contains(p.id)).length;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('step-$step'),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(), // no lines above and below when open
        collapsedShape: const Border(),
        title: Text(
          'Step $step · ${sheet.steps[step - 1]}',
          style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
        ),
        subtitle: Grow(
          value: done / problems.length,
          builder: (context, v) => LinearProgressIndicator(value: v, borderRadius: BorderRadius.circular(3)),
        ),
        trailing: Text('$done/${problems.length}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        children: [
          for (final (i, p) in problems.indexed) ...[
            if (i == 0 || problems[i - 1].section != p.section)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(p.section, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                ),
              ),
            InkWell(
              onTap: () => onOpen(p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
                child: Row(
                  children: [
                    Checkbox(value: solved.contains(p.id), onChanged: (_) => onToggle(p, solved.contains(p.id))),
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (p.difficulty != null) ...[const SizedBox(width: 8), Pill.difficulty(p.difficulty!)],
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: p.video == null ? 'Solve' : 'Watch video',
                      icon: Icon(p.video == null ? Icons.chevron_right_rounded : Icons.play_arrow_rounded, size: 18),
                      onPressed: p.video == null ? () => onOpen(p) : () => openLink(context, p.video!, inApp: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
