import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'open_link.dart';
import 'widgets.dart';

/// One problem at a time: recall the approach, check yourself, then say if you remembered it.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.store, required this.queue});

  final Store store;
  final List<Problem> queue; // fixed when the session starts, so answering does not reshuffle it

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _index = 0;
  int _remembered = 0;
  bool _revealed = false;

  void _answer(bool remembered) {
    widget.store.review(widget.queue[_index], remembered: remembered); // not awaited: saved locally at once
    setState(() {
      if (remembered) _remembered++;
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.queue.length;
    final done = _index >= total;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Review complete' : 'Review ${_index + 1} of $total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _index / total),
        ),
      ),
      body: SafeArea(child: done ? _summary(context, total) : _card(context, widget.queue[_index])),
    );
  }

  Widget _summary(BuildContext context, int total) => Center(
        child: EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Nice work!',
          message: 'You reviewed $total ${total == 1 ? 'problem' : 'problems'} and remembered $_remembered. '
              'Each one is scheduled for its next review.',
          action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ),
      );

  Widget _card(BuildContext context, Problem p) {
    final theme = Theme.of(context);
    final now = today();
    String inDays(bool remembered) {
      final days = afterReview(p.stage, remembered, now).$2.difference(now).inDays;
      return days == 1 ? 'again tomorrow' : 'again in $days days';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(p.topic), visualDensity: VisualDensity.compact),
            Chip(label: Text(p.difficulty), visualDensity: VisualDensity.compact),
            Chip(label: Text(p.mastered ? 'Mastered' : 'Stage ${p.stage + 1} of ${reviewIntervals.length}'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 16),
          Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Solved ${prettyDay(p.solvedOn)} · ${dueLabel(p.daysOverdue(now))}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Before you look: what is the pattern, the key idea, and the time and space complexity? '
                      'Say it or sketch it, then check.'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (p.url != null)
            OutlinedButton.icon(onPressed: () => openLink(context, p.url!), icon: const Icon(Icons.open_in_new), label: Text('Open on ${p.platform}')),
          if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_revealed)
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(p.notes!, style: const TextStyle(fontFamily: 'monospace')),
                ),
              )
            else
              TextButton.icon(onPressed: () => setState(() => _revealed = true), icon: const Icon(Icons.visibility_outlined), label: const Text('Show my notes')),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(child: _AnswerButton(remembered: false, hint: inDays(false), onPressed: () => _answer(false))),
          const SizedBox(width: 12),
          Expanded(child: _AnswerButton(remembered: true, hint: inDays(true), onPressed: () => _answer(true))),
        ]),
      ),
    ]);
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.remembered, required this.hint, required this.onPressed});

  final bool remembered;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(remembered ? 'Remembered' : 'Forgot', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(hint, style: const TextStyle(fontSize: 12)),
    ]);
    final style = ButtonStyle(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)));
    return remembered
        ? FilledButton(style: style, onPressed: onPressed, child: label)
        : FilledButton.tonal(
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(colors.errorContainer),
              foregroundColor: WidgetStatePropertyAll(colors.onErrorContainer),
            ),
            onPressed: onPressed,
            child: label,
          );
  }
}
