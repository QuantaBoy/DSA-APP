import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';

import '../data/runner.dart';
import '../data/templates.dart';
import 'widgets.dart';

final _highlight = <String, Mode>{'C++': cpp, 'Java': java, 'Python': python, 'JavaScript': javascript};

/// The public runner is rate-limited, so a run is capped at a few cases.
const maxTestCases = 5;

/// One test case: input, the output you expect (optional), and the last result.
class _Case {
  _Case({String input = '', String expected = ''})
    : input = TextEditingController(text: input),
      expected = TextEditingController(text: expected);

  final TextEditingController input;
  final TextEditingController expected;
  RunResult? result;

  /// Pass/fail when an expected output was given; null when there is nothing to compare.
  bool? get passed {
    final r = result;
    if (r == null || expected.text.trim().isEmpty) return null;
    return r.ok && outputsMatch(r.output, expected.text);
  }

  void dispose() {
    input.dispose();
    expected.dispose();
  }
}

/// Code editor plus a test runner: pick a language and an input template, write code,
/// add test cases (input + expected output), run them all and see which pass.
/// The parent owns [controller] so it can read the code (to save it on the solution card).
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
  InputKind _kind = InputKind.number;
  final _cases = [_Case()];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _apply(_language, _kind);
  }

  @override
  void dispose() {
    for (final c in _cases) {
      c.dispose();
    }
    super.dispose();
  }

  /// Switches highlighting and, unless you already wrote your own code, the starter program.
  void _apply(String language, InputKind kind) {
    final untouched = isStarterCode(widget.controller.fullText);
    _language = language;
    _kind = kind;
    widget.controller.setLanguage(_highlight[language], analyzer: const DefaultLocalAnalyzer());
    if (untouched) widget.controller.fullText = template(language, kind);
  }

  Future<void> _useTemplate(InputKind kind) async {
    if (!isStarterCode(widget.controller.fullText)) {
      final ok = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text('Use the ${kind.label} template?'),
          content: const Text('This replaces the code you wrote.'),
          actions: [
            adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
            adaptiveAction(context, 'Replace', () => Navigator.pop(context, true), destructive: true),
          ],
        ),
      );
      if (ok != true) return;
      widget.controller.fullText = '';
    }
    setState(() {
      _apply(_language, kind);
      if (_cases.length == 1 && _cases.first.input.text.trim().isEmpty) _cases.first.input.text = sampleInput[kind]!;
    });
  }

  Future<void> _runAll() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _running = true;
      for (final c in _cases) {
        c.result = null;
      }
    });
    for (final c in _cases) {
      final r = await widget.runner(_language, widget.controller.fullText, c.input.text);
      if (!mounted) return;
      setState(() => c.result = r);
      if (r.status == 'Too many runs' || r.status == 'Could not reach the runner') break; // the rest would fail the same way
    }
    if (!mounted) return;
    setState(() => _running = false);
    final verdicts = [for (final c in _cases) c.passed].whereType<bool>();
    unawaited(verdicts.isNotEmpty && verdicts.every((v) => v) ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4);
    final verdicts = [for (final c in _cases) c.passed].whereType<bool>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
            PopupMenuButton<InputKind>(
              tooltip: 'Input template',
              onSelected: _useTemplate,
              itemBuilder: (_) => [
                for (final k in InputKind.values)
                  CheckedPopupMenuItem(value: k, checked: k == _kind, child: Text('${k.label} · ${k.format}')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.data_object_rounded, size: 18, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _kind.label,
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            DropdownButton<String>(
              value: _language,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [for (final l in languages.keys) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (l) => setState(() => _apply(l!, _kind)),
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
              // room for 3-digit line numbers
              gutterStyle: const GutterStyle(showErrors: false, showFoldingHandles: false, margin: 6, width: 64),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Test cases', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (verdicts.isNotEmpty)
              Pill(
                '${verdicts.where((v) => v).length} / ${verdicts.length} passed',
                color: verdicts.every((v) => v) ? Accent.green : Accent.red,
              ),
            const Spacer(),
            if (_cases.length < maxTestCases)
              TextButton.icon(
                onPressed: _running ? null : () => setState(() => _cases.add(_Case())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add case'),
              ),
          ],
        ),
        for (final (i, c) in _cases.indexed) ...[
          _CaseView(
            index: i,
            testCase: c,
            mono: mono,
            onRemove: _cases.length > 1 && !_running
                ? () => setState(() {
                    _cases.removeAt(i).dispose();
                  })
                : null,
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: _running ? null : _runAll,
          icon: _running
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_running ? 'Running…' : (_cases.length == 1 ? 'Run' : 'Run ${_cases.length} cases')),
        ),
      ],
    );
  }
}

class _CaseView extends StatelessWidget {
  const _CaseView({required this.index, required this.testCase, required this.mono, this.onRemove});

  final int index;
  final _Case testCase;
  final TextStyle mono;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final r = testCase.result;
    final passed = testCase.passed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Case ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (passed != null)
                  Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: passed ? Accent.green : Accent.red),
                const Spacer(),
                if (onRemove != null)
                  IconButton(tooltip: 'Remove case', onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 18)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: testCase.input,
                      minLines: 2,
                      maxLines: 6,
                      style: mono,
                      decoration: InputDecoration(labelText: index == 0 ? 'Input (stdin)' : 'Input', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: testCase.expected,
                      minLines: 2,
                      maxLines: 6,
                      style: mono,
                      decoration: const InputDecoration(labelText: 'Expected (optional)', isDense: true),
                    ),
                  ),
                ],
              ),
            ),
            if (r != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF16161D), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(r.ok ? Icons.check_circle : Icons.error, size: 16, color: r.ok ? const Color(0xFF4ADE80) : colors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              passed == false ? 'Wrong answer' : r.status,
                              style: TextStyle(
                                color: r.ok && passed != false ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (r.time != null)
                            Text(
                              '${r.time}s${r.memoryKb == null ? '' : ' · ${(r.memoryKb! / 1024).toStringAsFixed(1)} MB'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
