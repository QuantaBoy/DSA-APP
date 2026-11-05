import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/leetcode.dart';
import '../data/runner.dart';
import '../data/sheet.dart';
import '../data/sounds.dart';
import '../data/statements.dart';
import '../data/store.dart';
import '../logic/ascension.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'coach.dart';
import 'code_pad.dart';
import 'goal_celebration.dart';
import 'open_link.dart';
import 'solution_sheet.dart';
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
  final _padKey = GlobalKey(), _doneKey = GlobalKey();
  bool? _verdict; // last run: all expected outputs matched, one failed, or none checked
  late final Future<String?> _statement = switch (leetCodeSlug(widget.problem.url)) {
    final slug? => leetCodeStatement(slug),
    null => Future.value(),
  };

  @override
  void initState() {
    super.initState();
    showTipsOnce(context, 'solve', [
      (
        target: _padKey,
        title: 'Code and run',
        text: 'Pick a language, write a full program, add input and tap Run. It runs on a real compiler.',
      ),
      (
        target: _doneKey,
        title: 'Save what you learned',
        text: 'Tap I solved it to fill a quick solution card. Your reviews show it later.',
      ),
    ]);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Your code, or null if you never changed the starter program.
  String? get _yourCode {
    final text = _code.fullText.trim();
    return isStarterCode(text) ? null : text;
  }

  /// Shows the problem page over the editor, so you can read and code without leaving.
  /// The statement stays on its own site (it is not ours to copy); the web app opens a tab instead.
  Future<void> _showQuestion() async {
    final url = widget.problem.url;
    if (kIsWeb || !isWebLink(url)) return openLink(context, url);
    final page = WebViewController();
    await page.setJavaScriptMode(JavaScriptMode.unrestricted);
    await page.setBackgroundColor(Colors.white);
    unawaited(page.loadRequest(Uri.parse(url.trim())));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // the page scrolls; close with the button
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.problem.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(widget.problem.platform),
              trailing: IconButton(tooltip: 'Back to code', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Expanded(child: WebViewWidget(controller: page)),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final p = widget.problem;
    if (_verdict == false && !widget.solved) {
      final markAnyway = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: const Text('A test case is failing'),
          content: const Text('Your output does not match the expected output yet. Fix it and Run again, or mark it solved anyway.'),
          actions: [
            adaptiveAction(context, 'Keep coding', () => Navigator.pop(context, false), primary: true),
            adaptiveAction(context, 'Mark solved', () => Navigator.pop(context, true)),
          ],
        ),
      );
      if (markAnyway != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final code = _yourCode ?? '';
    final initial = widget.solved ? (await widget.store.solution(p.id)).copyWith(code: code.isEmpty ? null : code) : Solution(code: code);
    if (!mounted) return;
    final card = await editSolutionCard(
      context,
      title: p.title,
      initial: initial,
      saveLabel: widget.solved ? 'Save card' : 'Save & add to my stack',
    );
    if (card == null && widget.solved) return; // dismissed: nothing to save
    // Writes are not awaited: Firestore saves locally at once and syncs when online.
    if (widget.solved) {
      unawaited(widget.store.setSolution(p.id, card!.solution));
      unawaited(widget.store.setPatterns(p.id, card.patterns));
      messenger.showSnackBar(const SnackBar(content: Text('Solution card saved.')));
    } else {
      final problem = widget.sheet.toProblem(p, today()).copyWith(patterns: card?.patterns);
      unawaited(widget.store.addProblem(problem, solution: card?.solution));
      unawaited(HapticFeedback.mediumImpact());
      play(Sound.correct);
      if (mounted) {
        confettiBurst(context);
        cheer(context, icon: Icons.rocket_launch_rounded, text: 'Solved!', color: const Color(0xFF6C4EF5), xp: solveXp(problem.difficulty));
      }
      messenger.showSnackBar(SnackBar(content: Text('${p.title} added to your stack. First review ${prettyDay(problem.nextDue)}.')));
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Solve')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(p.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (p.difficulty != null) Pill.difficulty(p.difficulty!),
                      Text(
                        widget.sheet.steps[p.step - 1],
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                      Text('·  ${p.platform}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      if (widget.solved) const Pill('Solved', color: Accent.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showQuestion,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text('Open on ${p.platform}'),
                      ),
                      if (p.video != null)
                        OutlinedButton.icon(
                          onPressed: () => openLink(context, p.video!, inApp: false),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Video'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  QuestionCard(statement: _statement, platform: p.platform, onOpen: _showQuestion),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        Accent.amber.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.1),
                        theme.colorScheme.surfaceContainerLowest,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Accent.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Accent.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tip',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Accent.amber),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Copy an example from the question into Input and its answer into Expected, then Run. '
                                'Add your own edge cases too. When every case passes, tap I solved it.',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CodePad(
                    key: _padKey,
                    controller: _code,
                    title: 'Your solution',
                    saveKey: widget.problem.id,
                    onVerdict: (v) => _verdict = v,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                key: _doneKey,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _finish,
                icon: Icon(widget.solved ? Icons.save_outlined : Icons.check),
                label: Text(widget.solved ? 'Save code as my solution' : 'I solved it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The problem statement, shown above the editor. LeetCode statements are kept on the device after the
/// first view; other sites (and LeetCode on the web) get a button that opens the page.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.statement, required this.platform, required this.onOpen});

  final Future<String?> statement;
  final String platform;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<String?>(
          future: statement,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final html = snap.data;
            if (html == null) {
              return Row(
                children: [
                  Icon(Icons.description_outlined, color: colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('The question opens on $platform.', style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
                  TextButton(onPressed: onOpen, child: const Text('Open')),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                HtmlWidget(
                  html,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  customStylesBuilder: (e) => switch (e.localName) {
                    'pre' => {'background-color': '#80808022', 'padding': '10px', 'white-space': 'pre-wrap'},
                    'code' => {'font-family': 'monospace'},
                    _ => null,
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'From LeetCode, saved on this device for offline use.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
