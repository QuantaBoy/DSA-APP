import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

import '../data/sounds.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/quiz.dart';
import 'solution_sheet.dart';

/// Quick-fire quiz from your own stack: a timer per question, instant feedback, XP at the end.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.store, required this.problems, required this.level});

  final Store store;
  final List<Problem> problems;
  final int level;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with SingleTickerProviderStateMixin {
  List<QuizQuestion>? _quiz;
  int _index = 0;
  int? _picked; // the option tapped, or -1 when time ran out
  int _right = 0;
  int? _aptStart; // where part 2 (aptitude) begins, when there are both parts
  bool _onBreak = false; // the 'DSA done, now aptitude' screen between the parts
  late final _clock =
      AnimationController(
        vsync: this,
        duration: Duration(seconds: quizShape(widget.level).seconds),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && _picked == null) _answer(-1);
      });

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  /// Reads the solution cards of up to 15 random problems (one read each), then builds the quiz.
  Future<void> _build() async {
    final rnd = Random();
    final picks = ([...widget.problems]..shuffle(rnd)).take(15).toList();
    final solutions = <String, Solution>{};
    for (final p in picks) {
      try {
        solutions[p.id] = await widget.store.solution(p.id);
      } on Exception {
        // offline and not cached: that problem just gives fewer question kinds
      }
    }
    var apt = <QuizQuestion>[];
    try {
      apt = aptitudeQuiz(await widget.store.aptCards().first.timeout(const Duration(seconds: 8)), widget.level, rnd);
    } on Exception {
      // offline with nothing cached: DSA only
    }
    if (!mounted) return;
    final dsa = buildQuiz(picks, solutions, widget.level, rnd);
    setState(() {
      _quiz = [...dsa, ...apt];
      if (dsa.isNotEmpty && apt.isNotEmpty) _aptStart = dsa.length;
    });
    unawaited(_clock.forward(from: 0));
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _answer(int option) {
    final q = _quiz![_index];
    final right = option == q.answer;
    unawaited(right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
    _clock.stop();
    play(right ? Sound.correct : Sound.wrong);
    setState(() {
      _picked = option;
      if (right) _right++;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _picked = null;
    });
    if (_index == _aptStart) {
      setState(() => _onBreak = true); // part 1 done: show the hand-over, timer waits
    } else if (_index < _quiz!.length) {
      unawaited(_clock.forward(from: 0));
    } else if (_right > 0) {
      unawaited(widget.store.addQuizScore(_right));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    final done = quiz != null && _index >= quiz.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(quiz == null || done || _onBreak ? 'Quick quiz' : '${_part()} · ${_index + 1} of ${quiz.length}'),
        bottom: quiz == null || done || _onBreak
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => LinearProgressIndicator(
                    value: 1 - _clock.value,
                    color: Color.lerp(const Color(0xFF22C55E), const Color(0xFFEF4444), _clock.value),
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: quiz == null
            ? const Center(child: CircularProgressIndicator())
            : quiz.isEmpty
            ? const _Empty()
            : done
            ? _Summary(right: _right, total: quiz.length)
            : _onBreak
            ? _Break(
                right: _right,
                total: _aptStart!,
                aptitude: quiz.length - _aptStart!,
                onGo: () {
                  setState(() => _onBreak = false);
                  unawaited(_clock.forward(from: 0));
                },
              )
            : _question(context, quiz[_index]),
      ),
    );
  }

  String _part() => _aptStart == null ? 'Quiz' : (_index < _aptStart! ? 'DSA 1/2' : 'Aptitude 2/2');

  Widget _question(BuildContext context, QuizQuestion q) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final answered = _picked != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  q.kind.label.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: colors.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(q.prompt, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (q.code case final code?) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: HighlightView(
                    code,
                    language: codeLanguage(code).name,
                    theme: vs2015Theme,
                    padding: const EdgeInsets.all(12),
                    textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final (i, option) in q.options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Option(
                  text: option,
                  code: q.kind == QuizKind.blank,
                  state: !answered
                      ? _State.open
                      : i == q.answer
                      ? _State.right
                      : i == _picked
                      ? _State.wrong
                      : _State.faded,
                  onTap: answered ? null : () => _answer(i),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 6),
              Text(
                _picked == q.answer
                    ? 'Correct! +5 XP'
                    : _picked == -1
                    ? "Time's up. The answer is highlighted."
                    : 'Not quite. The answer is highlighted.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: _picked == q.answer ? const Color(0xFF16A34A) : colors.error),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _next,
                child: Text(_index + 1 < _quiz!.length ? 'Next' : 'See score'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _State { open, right, wrong, faded }

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.code, required this.state, required this.onTap});

  final String text;
  final bool code;
  final _State state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (bg, border) = switch (state) {
      _State.right => (const Color(0xFF22C55E).withValues(alpha: 0.15), const Color(0xFF22C55E)),
      _State.wrong => (colors.error.withValues(alpha: 0.12), colors.error),
      _ => (colors.surfaceContainerLowest, colors.outlineVariant),
    };
    return Opacity(
      opacity: state == _State.faded ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              text,
              style: TextStyle(fontFamily: code ? 'monospace' : null, fontWeight: FontWeight.w600, fontSize: code ? 13 : 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.right, required this.total});

  final int right;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = right / total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Icon(
                share >= 0.8 ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                size: 90,
                color: share >= 0.8 ? const Color(0xFFF59E0B) : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text('$right / $total correct', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              share == 1
                  ? 'Perfect run. Your memory is sharp.'
                  : share >= 0.6
                  ? 'Strong. A few more and it sticks.'
                  : 'Every miss is a lesson. Review those problems.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '+${right * 5} XP',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF6C4EF5)),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'Not enough to quiz you on yet. Solve a few problems and fill their solution cards (patterns, complexity, code).',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// Between the parts: DSA is done, aptitude starts right here (no new quiz to open).
class _Break extends StatelessWidget {
  const _Break({required this.right, required this.total, required this.aptitude, required this.onGo});

  final int right;
  final int total;
  final int aptitude;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 72, color: Color(0xFF22C55E)),
            const SizedBox(height: 12),
            Text('DSA quiz complete', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('$right / $total correct · part 1 of 2 done', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Next: $aptitude aptitude questions', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
              onPressed: onGo,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue to aptitude'),
            ),
          ],
        ),
      ),
    );
  }
}
