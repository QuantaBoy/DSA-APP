import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'open_link.dart';
import 'review_page.dart';
import 'solution_sheet.dart';
import 'widgets.dart';

/// Every problem in your review stack, soonest review first, with search and stage filters.
class StackPage extends StatefulWidget {
  const StackPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  State<StackPage> createState() => _StackPageState();
}

enum _Filter { all, fresh, growing, mastered }

class _StackPageState extends State<StackPage> {
  /// Topics folded or opened by hand; untouched ones open only when something in them is due.
  final _toggled = <String, bool>{};
  bool _open(String topic, List<Problem> all, DateTime now) =>
      _toggled[topic] ?? all.any((p) => p.topic == topic && p.isDue(now)) || all.map((p) => p.topic).toSet().length == 1;

  _Filter _filter = _Filter.all;
  String _query = '';
  bool _searching = false;

  Store get store => widget.store;

  static bool _matches(Problem p, _Filter f) => switch (f) {
    _Filter.all => true,
    _Filter.fresh => p.stage == 0,
    _Filter.growing => p.stage > 0 && !p.mastered,
    _Filter.mastered => p.mastered,
  };

  /// Stage badge colour: early stages warm, later stages cool, mastered gold.
  static Color _stageColor(Problem p) => p.mastered
      ? Accent.amber
      : switch (p.stage) {
          0 => Accent.orange,
          1 || 2 => Accent.amber,
          3 || 4 => Accent.violet,
          _ => Accent.green,
        };

  Future<void> _confirmDelete(BuildContext context, Problem p) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete ${p.name}?'),
        content: const Text('Its solution card and review history go too. This cannot be undone.'),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Delete', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok == true) unawaited(store.deleteProblem(p));
  }

  /// Fixes a mis-tapped grade: pick the right one, the schedule and recall are redone as if you had chosen it.
  Future<void> _regrade(BuildContext context, Problem p) async {
    final grade = await showModalBottomSheet<Grade>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change last grade', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('You graded ${p.name} "${p.last!.grade.label}". Pick what you meant; it replaces that review.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (i, g) in Grade.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: (g == p.last!.grade ? OutlinedButton.new : FilledButton.tonal)(
                        onPressed: g == p.last!.grade ? null : () => Navigator.pop(context, g),
                        child: Text(g.label),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (grade == null || !context.mounted) return;
    unawaited(store.regrade(p, grade));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Changed to ${grade.label}. Next review ${prettyDay(p.regrade(grade, on: today()).nextDue)}.')));
  }

  Future<void> _editNotes(BuildContext context, Problem p) async {
    final current = await store.solution(p.id);
    if (!context.mounted) return;
    final card = await editSolutionCard(context, title: p.name, initial: current, patterns: p.patterns);
    if (card == null) return;
    unawaited(store.setSolution(p.id, card.solution)); // saved locally at once
    unawaited(store.setPatterns(p.id, card.patterns));
  }

  @override
  Widget build(BuildContext context) {
    final problems = widget.problems;
    if (problems.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.layers_outlined,
          title: 'Your stack is empty',
          message: 'Tick problems in the A2Z sheet as you solve them, or add one you solved elsewhere.',
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final now = today();
    final q = _query.trim().toLowerCase();
    final shown =
        [
          for (final p in problems)
            if (_matches(p, _filter) && (q.isEmpty || p.name.toLowerCase().contains(q) || p.topic.toLowerCase().contains(q))) p,
        ]..sort(
          (a, b) => switch (a.topic.compareTo(b.topic)) {
            0 => a.nextDue.compareTo(b.nextDue),
            final c => c,
          },
        ); // grouped by topic, soonest review first inside each
    String chip(_Filter f, String name) => '$name (${problems.where((p) => _matches(p, f)).length})';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: _searching
                    ? TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search problems or topics',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (f, name) in [
                              (_Filter.all, 'All'),
                              (_Filter.fresh, 'New'),
                              (_Filter.growing, 'Growing'),
                              (_Filter.mastered, 'Mastered'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(chip(f, name)),
                                  selected: _filter == f,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => _filter = f),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              IconButton(
                tooltip: _searching ? 'Close search' : 'Search',
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  _query = '';
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text('No problems match.', style: TextStyle(color: colors.onSurfaceVariant)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: shown.length,
                  // Rows of folded topics take no space.
                  separatorBuilder: (_, i) => SizedBox(height: _open(shown[i].topic, shown, now) ? 10 : 0),
                  itemBuilder: (context, i) {
                    final p = shown[i];
                    final overdue = p.daysOverdue(now);
                    final due = p.isDue(now);
                    final stageColor = _stageColor(p);
                    final firstOfTopic = i == 0 || shown[i - 1].topic != p.topic;
                    final count = shown.where((x) => x.topic == p.topic).length;
                    final next = due ? dueLabel(overdue) : 'Next: ${prettyDay(p.nextDue).replaceFirst(RegExp(r' \d{4}$'), '')}';
                    final row = Rise(
                      index: i,
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: p.url == null ? null : () => openLink(context, p.url!),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: stageColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: p.mastered
                                      ? const Icon(Icons.star_rounded, color: Accent.amber)
                                      : Text(
                                          '${p.stage + 1}',
                                          style: TextStyle(color: stageColor, fontWeight: FontWeight.w900, fontSize: 17),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Pill.difficulty(p.difficulty),
                                          Text(p.topic, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.mastered && !due ? 'Mastered · $next' : next,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: overdue > 0 ? Accent.red : colors.onSurfaceVariant,
                                          fontWeight: overdue > 0 ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => switch (v) {
                                    'again' => unawaited(
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ReviewPage(store: store, queue: [p]),
                                        ),
                                      ),
                                    ),
                                    'regrade' => _regrade(context, p),
                                    'notes' => _editNotes(context, p),
                                    _ => _confirmDelete(context, p),
                                  },
                                  itemBuilder: (_) => [
                                    if (p.last case final l?)
                                      PopupMenuItem(value: 'regrade', child: Text('Change last grade (${l.grade.label})')),
                                    const PopupMenuItem(value: 'again', child: Text('Review again')),
                                    const PopupMenuItem(value: 'notes', child: Text('Solution card')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    final open = _open(p.topic, shown, now);
                    if (!firstOfTopic) return open ? row : const SizedBox.shrink();
                    final dueHere = shown.where((x) => x.topic == p.topic && x.isDue(now)).length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tap the header to fold or open the topic.
                        InkWell(
                          onTap: () => setState(() => _toggled[p.topic] = !open),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, i == 0 ? 4 : 10, 16, 8),
                            child: Row(
                              children: [
                                AnimatedRotation(
                                  turns: open ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(Icons.chevron_right_rounded, color: colors.primary),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${p.topic.toUpperCase()} · $count',
                                    style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: colors.primary),
                                  ),
                                ),
                                if (dueHere > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Accent.red.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$dueHere due',
                                      style: const TextStyle(color: Accent.red, fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (open) row,
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
