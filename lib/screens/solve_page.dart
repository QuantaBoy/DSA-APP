import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/runner.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'code_pad.dart';
import 'open_link.dart';
import 'widgets.dart';

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
              Text(p.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (p.difficulty != null) Pill.difficulty(p.difficulty!),
                Text(widget.sheet.steps[p.step - 1], style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                Text('·  ${p.platform}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                if (widget.solved) const Pill('Solved', color: Accent.green),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => openLink(context, p.url), icon: const Icon(Icons.description_outlined), label: Text('Read on ${p.platform}')),
                if (p.video != null)
                  OutlinedButton.icon(onPressed: () => openLink(context, p.video!), icon: const Icon(Icons.play_circle_outline), label: const Text('Video')),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(Accent.amber.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.1), theme.colorScheme.surfaceContainerLowest),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Accent.amber.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_rounded, color: Accent.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tip', style: TextStyle(fontWeight: FontWeight.w800, color: Accent.amber)),
                      const SizedBox(height: 2),
                      Text('Read the problem, write a full program that reads the input, then Run it with the examples '
                          'and your own edge cases. When it is right, tap I solved it.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ]),
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
