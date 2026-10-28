import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'open_link.dart';
import 'motion.dart';
import 'widgets.dart';

/// Every problem in your review stack, soonest review first.
class StackPage extends StatelessWidget {
  const StackPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

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
    if (ok == true) store.deleteProblem(p);
  }

  Future<void> _editNotes(BuildContext context, Problem p) async {
    final controller = TextEditingController(text: await store.notes(p.id));
    if (!context.mounted) return;
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes · ${p.name}'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(hintText: 'Key idea, edge cases, complexity, code…', border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (notes != null) store.setNotes(p.id, notes.isEmpty ? null : notes); // not awaited: saved locally at once
  }

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.layers_outlined,
          title: 'Your stack is empty',
          message: 'Tick problems in the A2Z sheet as you solve them, or add one you solved elsewhere.',
        ),
      );
    }
    final sorted = [...problems]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final now = today();
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = sorted[i];
        final overdue = p.daysOverdue(now);
        final due = p.isDue(now);
        final stageColor = p.mastered ? Accent.amber : due ? colors.primary : colors.outline;
        return Rise(index: i, child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: p.url == null ? null : () => openLink(context, p.url!),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: p.mastered
                      ? const Icon(Icons.star_rounded, color: Accent.amber)
                      : Text('${p.stage + 1}', style: TextStyle(color: stageColor, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Pill.difficulty(p.difficulty),
                      Text(due ? dueLabel(overdue) : 'next ${prettyDay(p.nextDue)}',
                          style: TextStyle(fontSize: 12, color: overdue > 0 ? Accent.red : colors.onSurfaceVariant, fontWeight: overdue > 0 ? FontWeight.w700 : null)),
                    ]),
                    const SizedBox(height: 2),
                    Text(p.topic, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ]),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'notes' ? _editNotes(context, p) : _confirmDelete(context, p),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'notes', child: Text('Notes')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ]),
            ),
          ),
        ));
      },
    );
  }
}
