import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'open_link.dart';

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
        content: const Text('Its review history is deleted too. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) store.deleteProblem(p.id);
  }

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Your stack is empty.\nTick problems in the A2Z sheet as you solve them, '
              'or add a problem you solved elsewhere.', textAlign: TextAlign.center),
        ),
      );
    }
    final sorted = [...problems]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final now = today();
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = sorted[i];
        final overdue = p.daysOverdue(now);
        final due = p.isDue(now);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: due ? colors.primary : colors.surfaceContainerHighest,
            foregroundColor: due ? colors.onPrimary : colors.onSurface,
            child: p.mastered ? const Icon(Icons.star) : Text('${p.stage + 1}'),
          ),
          title: Text(p.name),
          subtitle: Text('${p.topic} · ${p.difficulty} · '
              '${overdue > 0 ? '$overdue days overdue' : due ? 'due today' : 'next ${prettyDay(p.nextDue)}'}'),
          onTap: p.url == null ? null : () => openLink(context, p.url!),
          trailing: PopupMenuButton<String>(
            onSelected: (_) => _confirmDelete(context, p),
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
          ),
        );
      },
    );
  }
}
