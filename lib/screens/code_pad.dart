import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';

import '../data/runner.dart';

final _highlight = <String, Mode>{'C++': cpp, 'Java': java, 'Python': python, 'JavaScript': javascript};

/// Code editor plus a terminal: pick a language, write code, type input, Run, and see the output.
/// The parent owns [controller] so it can read the code (to save it as a solution).
class CodePad extends StatefulWidget {
  const CodePad({super.key, required this.controller, this.title = 'Code', this.runner = runCode});

  final CodeController controller;
  final String title;
  final Future<RunResult> Function(String language, String code, String stdin) runner; // tests pass a fake

  @override
  State<CodePad> createState() => _CodePadState();
}

class _CodePadState extends State<CodePad> {
  String _language = 'C++';
  final _stdin = TextEditingController();
  RunResult? _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _setLanguage(_language);
  }

  @override
  void dispose() {
    _stdin.dispose();
    super.dispose();
  }

  /// Switches highlighting, and swaps in the new starter program unless you already wrote your own code.
  void _setLanguage(String language) {
    final text = widget.controller.fullText.trim();
    final untouched = text.isEmpty || languages.values.any((l) => l.starter.trim() == text);
    _language = language;
    widget.controller.setLanguage(_highlight[language], analyzer: const DefaultLocalAnalyzer());
    if (untouched) widget.controller.fullText = languages[language]!.starter;
  }

  Future<void> _run() async {
    FocusScope.of(context).unfocus();
    setState(() => _running = true);
    final result = await widget.runner(_language, widget.controller.fullText, _stdin.text);
    if (mounted) {
      setState(() {
        _result = result;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mono = const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4);
    final r = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
            DropdownButton<String>(
              value: _language,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [for (final l in languages.keys) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (l) => setState(() => _setLanguage(l!)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CodeTheme(
            data: CodeThemeData(styles: theme.brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme),
            child: CodeField(
              controller: widget.controller,
              minLines: 12,
              textStyle: mono,
              gutterStyle: const GutterStyle(
                showErrors: false,
                showFoldingHandles: false,
                margin: 6,
                width: 64,
              ), // room for 3-digit line numbers
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _stdin,
          minLines: 1,
          maxLines: 4,
          style: mono,
          decoration: const InputDecoration(labelText: 'Input (stdin)', hintText: 'e.g. 5\n1 2 3 4 5'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _running ? null : _run,
          icon: _running
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_running ? 'Running…' : 'Run'),
        ),
        if (r != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF16161D), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.ok ? Icons.check_circle : Icons.error, size: 18, color: r.ok ? const Color(0xFF4ADE80) : colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.status,
                        style: TextStyle(color: r.ok ? const Color(0xFF4ADE80) : colors.error, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (r.time != null)
                      Text(
                        '${r.time}s${r.memoryKb == null ? '' : ' · ${(r.memoryKb! / 1024).toStringAsFixed(1)} MB'}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  [
                    if (r.output.isNotEmpty) r.output.trimRight(),
                    if (r.error.isNotEmpty) r.error,
                    if (r.output.isEmpty && r.error.isEmpty) '(no output)',
                  ].join('\n'),
                  style: mono.copyWith(color: r.error.isNotEmpty && r.output.isEmpty ? const Color(0xFFFCA5A5) : Colors.white),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
