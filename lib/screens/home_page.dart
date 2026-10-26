import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'add_problem_page.dart';

/// Your problem list, soonest review first. Layer 4 adds the Today and Review screens.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final store = Store(widget.user.uid);
  late final Stream<List<Problem>> _problems = store.problems();

  Future<void> _confirmDelete(Problem p) async {
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
    final name = widget.user.displayName?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(name == null || name.isEmpty ? 'My problems' : 'Hi ${name.split(' ').first}'),
        actions: [
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProblemPage(store: store))),
        icon: const Icon(Icons.add),
        label: const Text('Add problem'),
      ),
      body: StreamBuilder<List<Problem>>(
        stream: _problems,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(icon: Icons.cloud_off, text: 'Could not load your problems.\n${snapshot.error}');
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final problems = [...snapshot.data!]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
          if (problems.isEmpty) {
            return const _Message(icon: Icons.playlist_add, text: 'No problems yet.\nSolve one, then tap "Add problem".');
          }
          final now = today();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: problems.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = problems[i];
              final colors = Theme.of(context).colorScheme;
              final overdue = p.daysOverdue(now);
              return ListTile(
                title: Text(p.name),
                subtitle: Text('${p.topic} · ${p.difficulty} · '
                    '${overdue > 0 ? '$overdue days overdue' : p.isDue(now) ? 'due today' : 'next ${prettyDay(p.nextDue)}'}'),
                leading: CircleAvatar(
                  backgroundColor: p.isDue(now) ? colors.primary : colors.surfaceContainerHighest,
                  foregroundColor: p.isDue(now) ? colors.onPrimary : colors.onSurface,
                  child: p.mastered ? const Icon(Icons.star) : Text('${p.stage + 1}'),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (_) => _confirmDelete(p),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
