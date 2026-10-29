import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import 'motion.dart';
import 'open_link.dart';
import 'stack_page.dart';
import 'widgets.dart';

/// Everything you have solved: as a list (with search and filters) or grouped by DSA pattern.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Problems'),
              Tab(text: 'Patterns'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              StackPage(store: store, problems: problems),
              PatternsView(problems: problems),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Problems grouped by the patterns on their solution cards, weakest recall first.
class PatternsView extends StatelessWidget {
  const PatternsView({super.key, required this.problems});

  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groups = <String, List<Problem>>{};
    for (final p in problems) {
      for (final pattern in p.patterns) {
        (groups[pattern] ??= []).add(p);
      }
    }
    final untagged = problems.where((p) => p.patterns.isEmpty).length;
    if (groups.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.hub_outlined,
          title: 'No patterns yet',
          message: 'Tag problems with a pattern on their solution card (Two Pointers, Sliding Window…) and they group here.',
        ),
      );
    }
    double recall(List<Problem> ps) {
      final reviews = ps.fold(0, (a, p) => a + p.reviews);
      return reviews == 0 ? 2 : ps.fold(0, (a, p) => a + p.remembered) / reviews; // unreviewed sort last
    }

    final names = groups.keys.toList()..sort((a, b) => recall(groups[a]!).compareTo(recall(groups[b]!)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (untagged > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$untagged ${untagged == 1 ? 'problem has' : 'problems have'} no pattern yet. Add one from its solution card.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 132,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: names.length,
          itemBuilder: (context, i) {
            final name = names[i], list = groups[name]!;
            final r = recall(list);
            final color = r > 1 ? colors.outline : (r < 0.5 ? Accent.red : (r < 0.8 ? Accent.amber : Accent.green));
            return Rise(
              index: i,
              child: Pressable(
                onTap: () => _open(context, name, list),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text('${list.length}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(width: 4),
                            Text('solved', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                            const Spacer(),
                            Text(
                              r > 1 ? 'new' : '${(r * 100).round()}%',
                              style: TextStyle(color: color, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: r > 1 ? 0 : r,
                          color: color,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, String pattern, List<Problem> list) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(pattern, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final p in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${p.topic} · ${p.reviews} reviews'),
            trailing: Pill.difficulty(p.difficulty),
            onTap: p.url == null ? null : () => openLink(context, p.url!),
          ),
      ],
    ),
  );
}
