import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import '../data/prefs.dart';
import '../data/runner.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'code_pad.dart';
import 'motion.dart';
import 'open_link.dart';
import 'solution_sheet.dart';
import 'widgets.dart';

/// Where interview problems come from.
enum InterviewSource {
  fresh('New problem', 'Unsolved, from your sheet'),
  recall('From my stack', 'Something you solved before');

  const InterviewSource(this.label, this.detail);
  final String label;
  final String detail;
}

/// Set up a timed mock interview: difficulty, length and where the problem comes from.
class InterviewSetupPage extends StatefulWidget {
  const InterviewSetupPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  State<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends State<InterviewSetupPage> {
  String? _difficulty = 'Medium'; // null = any
  int _minutes = 30;
  InterviewSource _source = InterviewSource.fresh;
  final _random = Random();

  Future<void> _start() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool fits(String? d) => _difficulty == null || d == _difficulty;
    ({String id, String title, String difficulty, String topic, String url, Sheet? sheet, SheetProblem? sheetProblem, Problem? problem})?
    pick;
    if (_source == InterviewSource.recall) {
      final pool = [
        for (final p in widget.problems)
          if (fits(p.difficulty) && p.url != null) p,
      ];
      if (pool.isNotEmpty) {
        final p = pool[_random.nextInt(pool.length)];
        pick = (
          id: p.id,
          title: p.name,
          difficulty: p.difficulty,
          topic: p.topic,
          url: p.url!,
          sheet: null,
          sheetProblem: null,
          problem: p,
        );
      }
    } else {
      final sheet = await loadSheet(Prefs.sheetId.value);
      final solved = {for (final p in widget.problems) p.id};
      final pool = [
        for (final p in sheet.problems)
          if (!solved.contains(p.id) && fits(p.difficulty)) p,
      ];
      if (pool.isNotEmpty) {
        final p = pool[_random.nextInt(pool.length)];
        pick = (
          id: p.id,
          title: p.title,
          difficulty: p.difficulty ?? 'Easy',
          topic: sheet.steps[p.step - 1],
          url: p.url,
          sheet: sheet,
          sheetProblem: p,
          problem: null,
        );
      }
    }
    if (pick == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No problem matches. Try another difficulty or source.')));
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    final chosen = pick;
    unawaited(
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => InterviewPage(
            store: widget.store,
            title: chosen.title,
            difficulty: chosen.difficulty,
            topic: chosen.topic,
            url: chosen.url,
            minutes: _minutes,
            stackProblem: chosen.problem,
            sheet: chosen.sheet,
            sheetProblem: chosen.sheetProblem,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mock interview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Rise(
            child: HeroCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INTERVIEW MODE', style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        Text('One problem. One timer.', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Read it, talk through the approach, code it and run it before time runs out.'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bob(child: Icon(Icons.timer_rounded, size: 64, color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
          ),
          label('Difficulty'),
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'Easy', label: Text('Easy')),
              ButtonSegment(value: 'Medium', label: Text('Medium')),
              ButtonSegment(value: 'Hard', label: Text('Hard')),
              ButtonSegment(value: null, label: Text('Any')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.single),
          ),
          label('Time'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 20, label: Text('20 min')),
              ButtonSegment(value: 30, label: Text('30 min')),
              ButtonSegment(value: 45, label: Text('45 min')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() => _minutes = s.single),
          ),
          label('Problem'),
          RadioGroup<InterviewSource>(
            groupValue: _source,
            onChanged: (v) => setState(() => _source = v!),
            child: Column(
              children: [
                for (final s in InterviewSource.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: RadioListTile<InterviewSource>(
                        value: s,
                        title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(s.detail),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start interview'),
          ),
        ],
      ),
    );
  }
}

/// The interview itself: problem, countdown ring, editor. Finishing records the attempt.
class InterviewPage extends StatefulWidget {
  const InterviewPage({
    super.key,
    required this.store,
    required this.title,
    required this.difficulty,
    required this.topic,
    required this.url,
    required this.minutes,
    this.stackProblem,
    this.sheet,
    this.sheetProblem,
  });

  final Store store;
  final String title, difficulty, topic, url;
  final int minutes;
  final Problem? stackProblem; // set for a problem from your stack: finishing grades it
  final Sheet? sheet; // set with sheetProblem for a new problem: solving adds it
  final SheetProblem? sheetProblem;

  @override
  State<InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends State<InterviewPage> {
  final _code = CodeController();
  final _watch = Stopwatch()..start();
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  bool _finished = false;

  Duration get _limit => Duration(minutes: widget.minutes);
  Duration get _left => _limit - _watch.elapsed;

  @override
  void initState() {
    super.initState();
    _tick; // start ticking
  }

  @override
  void dispose() {
    _tick.cancel();
    _code.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || _finished) return;
    if (_left <= Duration.zero) {
      unawaited(HapticFeedback.heavyImpact());
      unawaited(_finish(timeUp: true));
    } else {
      setState(() {});
    }
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_finished) return;
    _watch.stop();
    setState(() => _finished = true);
    final took = _watch.elapsed;
    final solved = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      showDragHandle: true,
      builder: (context) => _Result(took: took, limit: _limit, timeUp: timeUp),
    );
    if (!mounted || solved == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final code = isStarterCode(_code.fullText) ? '' : _code.fullText.trim();
    final stack = widget.stackProblem;
    if (stack != null) {
      final grade = interviewGrade(solved: solved, took: took, limit: _limit);
      unawaited(widget.store.review(stack, grade));
      messenger.showSnackBar(SnackBar(content: Text('Recorded as ${grade.label}. Next review in ${daysAfter(stack.stage, grade)} days.')));
    } else if (solved && widget.sheet != null && widget.sheetProblem != null) {
      final card = await editSolutionCard(
        context,
        title: widget.title,
        initial: Solution(code: code.length <= Limits.maxNoteLength ? code : ''),
        saveLabel: 'Save & add to my stack',
      );
      final problem = widget.sheet!.toProblem(widget.sheetProblem!, today()).copyWith(patterns: card?.patterns);
      unawaited(widget.store.addProblem(problem, solution: card?.solution));
      messenger.showSnackBar(SnackBar(content: Text('${widget.title} added. First review ${prettyDay(problem.nextDue)}.')));
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = _left.isNegative ? Duration.zero : _left;
    final fraction = left.inSeconds / _limit.inSeconds;
    final color = fraction > 0.5 ? Accent.green : (fraction > 0.2 ? Accent.amber : Accent.red);
    String two(int n) => n.toString().padLeft(2, '0');
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Interview'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox.square(
                dimension: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 4,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                    Center(
                      child: Text(
                        left.inMinutes >= 1 ? '${left.inMinutes}m' : '${two(left.inSeconds)}s',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill.difficulty(widget.difficulty),
                        Pill(widget.topic, color: theme.colorScheme.primary),
                        Pill('${widget.minutes} min', color: color),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => openLink(context, widget.url),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Read the problem'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Like a real interview: say your approach out loud first, then code it and test it.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    CodePad(controller: _code, title: 'Your solution'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _finished ? null : _finish,
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.took, required this.limit, required this.timeUp});

  final Duration took;
  final Duration limit;
  final bool timeUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = took.inMinutes, secs = took.inSeconds % 60;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(timeUp ? Icons.timer_off_rounded : Icons.flag_circle_rounded, size: 56, color: timeUp ? Accent.red : Accent.green),
          const SizedBox(height: 8),
          Text(timeUp ? "Time's up" : 'Finished', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            '${mins}m ${secs}s of ${limit.inMinutes}m',
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          const Text('Did you solve it?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, solved')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
