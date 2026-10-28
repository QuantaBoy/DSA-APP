import 'package:flutter/material.dart';

import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'open_link.dart';
import 'motion.dart';
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

  void _markSolved(Sheet sheet, SheetProblem p) {
    final problem = sheet.toProblem(p, today());
    widget.store.addProblem(problem); // not awaited: saved locally at once, syncs when online
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${p.title} added to your stack. First review on ${prettyDay(problem.nextDue)}.')));
  }

  void _solve(Sheet sheet, SheetProblem p, bool solved) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SolvePage(store: widget.store, sheet: sheet, problem: p, solved: solved),
    ),
  );

  Future<void> _unmark(SheetProblem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark ${p.title} as not solved?'),
        content: const Text('It is removed from your review stack, with its notes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) widget.store.deleteProblem(widget.problems.firstWhere((x) => x.id == p.id));
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
                  Text('$done / ${sheet.problems.length} solved', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Grow(
                    value: done / sheet.problems.length,
                    builder: (context, v) => LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
            ),
            if (next != null)
              AnimatedSwitcher(
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
                  onVideo: next.video == null ? null : () => openLink(context, next.video!),
                  onSolved: () => _markSolved(sheet, next),
                ),
              )
            else
              const Padding(padding: EdgeInsets.all(16), child: Text('You finished the whole sheet. Keep up your reviews!')),
            for (var step = 1; step <= sheet.steps.length; step++)
              _StepTile(
                step: step,
                sheet: sheet,
                solved: solved,
                initiallyExpanded: next?.step == step,
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
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF5B3FE0)),
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
        title: Text('Step $step · ${sheet.steps[step - 1]}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Grow(
          value: done / problems.length,
          builder: (context, v) => LinearProgressIndicator(value: v, borderRadius: BorderRadius.circular(3)),
        ),
        trailing: Text('$done/${problems.length}', style: theme.textTheme.labelLarge),
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
            ListTile(
              leading: Checkbox(value: solved.contains(p.id), onChanged: (_) => onToggle(p, solved.contains(p.id))),
              title: Text(p.title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (p.difficulty != null) Pill.difficulty(p.difficulty!),
                    Text(p.platform, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              trailing: p.video == null
                  ? null
                  : IconButton(
                      tooltip: 'Watch video',
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () => openLink(context, p.video!),
                    ),
              onTap: () => onOpen(p),
            ),
          ],
        ],
      ),
    );
  }
}
