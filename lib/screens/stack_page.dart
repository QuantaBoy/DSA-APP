import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'open_link.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text('Its notes are deleted too. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) unawaited(store.deleteProblem(p));
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
    final shown = [
      for (final p in problems)
        if (_matches(p, _filter) && (q.isEmpty || p.name.toLowerCase().contains(q) || p.topic.toLowerCase().contains(q))) p,
    ]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = shown[i];
                    final overdue = p.daysOverdue(now);
                    final due = p.isDue(now);
                    final stageColor = _stageColor(p);
                    final next = due ? dueLabel(overdue) : 'Next: ${prettyDay(p.nextDue).replaceFirst(RegExp(r' \d{4}$'), '')}';
                    return Rise(
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
                                  onSelected: (v) => v == 'notes' ? _editNotes(context, p) : _confirmDelete(context, p),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'notes', child: Text('Solution card')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
