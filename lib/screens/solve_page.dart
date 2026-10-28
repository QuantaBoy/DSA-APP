import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/runner.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'code_pad.dart';
import 'open_link.dart';

/// Solve one sheet problem in the app: read it on its site, code and run it here,
/// then mark it solved, which saves your code as the solution you will review later.
class SolvePage extends StatefulWidget {
  const SolvePage({super.key, required this.store, required this.sheet, required this.problem, required this.solved});

  final Store store;
  final Sheet sheet;
  final SheetProblem problem;
  final bool solved; // already in your stack: the button saves code instead

  @override
  State<SolvePage> createState() => _SolvePageState();
}

class _SolvePageState extends State<SolvePage> {
  final _code = CodeController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Your code, or null if you never changed the starter program.
  String? get _yourCode {
    final text = _code.fullText.trim();
    return text.isEmpty || languages.values.any((l) => l.starter.trim() == text) ? null : text;
  }

  void _finish() {
    final p = widget.problem;
    final messenger = ScaffoldMessenger.of(context);
    if (widget.solved) {
      if (_yourCode != null) widget.store.setNotes(p.id, _yourCode); // not awaited: saved locally at once
      messenger.showSnackBar(const SnackBar(content: Text('Saved as your solution.')));
    } else {
      final problem = widget.sheet.toProblem(p, today());
      widget.store.addProblem(problem, notes: _yourCode); // not awaited: saved locally at once
      messenger.showSnackBar(SnackBar(content: Text('${p.title} added to your stack. First review on ${prettyDay(problem.nextDue)}.')));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solve')),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text('Step ${p.step} · ${widget.sheet.steps[p.step - 1]}'), visualDensity: VisualDensity.compact),
                if (p.difficulty != null) Chip(label: Text(p.difficulty!), visualDensity: VisualDensity.compact),
                if (widget.solved) const Chip(avatar: Icon(Icons.check, size: 16), label: Text('Solved'), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 12),
              Text(p.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(p.section, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => openLink(context, p.url), icon: const Icon(Icons.description_outlined), label: Text('Read on ${p.platform}')),
                if (p.video != null)
                  OutlinedButton.icon(onPressed: () => openLink(context, p.video!), icon: const Icon(Icons.play_circle_outline), label: const Text('Video')),
              ]),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.terminal, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Read the problem, write a full program that reads the input, then Run it with the '
                          'examples and your own edge cases. When it is right, tap I solved it.'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              CodePad(controller: _code, title: 'Your solution'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _finish,
              icon: Icon(widget.solved ? Icons.save_outlined : Icons.check),
              label: Text(widget.solved ? 'Save code as my solution' : 'I solved it'),
            ),
          ),
        ]),
      ),
    );
  }
}
