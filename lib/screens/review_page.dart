import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'code_pad.dart';
import 'open_link.dart';
import 'widgets.dart';

/// One problem at a time: write the solution from memory, compare it with your saved one,
/// then say if you remembered it.
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
  bool _checked = false;
  final _code = CodeController();
  final _saved = <String, String>{}; // saved solutions, loaded on Check (one read) and updated on save

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _answer(bool remembered) {
    widget.store.review(widget.queue[_index], remembered: remembered); // not awaited: saved locally at once
    setState(() {
      if (remembered) _remembered++;
      _index++;
      _checked = false;
      _code.fullText = '';
    });
  }

  Future<void> _check(Problem p) async {
    setState(() => _checked = true);
    if (_saved.containsKey(p.id)) return;
    final notes = await widget.store.notes(p.id);
    if (mounted) setState(() => _saved[p.id] = notes?.trim() ?? '');
  }

  void _saveAsSolution(Problem p) {
    final code = _code.fullText.trim();
    widget.store.setNotes(p.id, code); // not awaited: saved locally at once
    setState(() => _saved[p.id] = code);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved as your solution for next time.')));
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
          const SizedBox(height: 24),
          CodePad(controller: _code, title: 'Write it from memory'),
          const SizedBox(height: 12),
          if (!_checked)
            FilledButton.tonalIcon(
              onPressed: () => _check(p),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Check against my solution'),
            )
          else
            _savedSolution(theme, p),
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

  Widget _savedSolution(ThemeData theme, Problem p) {
    final saved = _saved[p.id];
    if (saved == null) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    final canSave = _code.fullText.trim().isNotEmpty && _code.fullText.trim() != saved;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your saved solution', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          if (saved.isEmpty)
            Text('Nothing saved yet. Save the code you just wrote, so next time you can compare.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
          else
            SelectableText(saved, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Text('Different code is fine. Judge the idea, not the lines: if your approach is correct with the same '
              'or better complexity, tap Remembered. Found a better way? Save it as your new solution.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (canSave) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _saveAsSolution(p),
              icon: const Icon(Icons.save_outlined),
              label: Text(saved.isEmpty ? 'Save my code as the solution' : 'Replace with my new code'),
            ),
          ],
        ]),
      ),
    );
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
