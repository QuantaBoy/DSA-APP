import 'dart:math';

import 'models.dart';

/// Quick-fire quiz built from your own stack: what you solved, the patterns you tagged,
/// the complexity you wrote down and the code you saved. Works offline, no AI.

enum QuizKind {
  topic('Which topic?', 1),
  pattern('Spot the pattern', 1),
  complexity('Time complexity', 3),
  blank('Fill the blank', 5);

  const QuizKind(this.label, this.fromLevel);
  final String label;
  final int fromLevel; // higher levels unlock harder kinds
}

class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.problem,
    required this.prompt,
    required this.options,
    required this.answer,
    this.code,
  });

  final QuizKind kind;
  final String problem; // problem name
  final String prompt;
  final List<String> options;
  final int answer; // index into options
  final String? code; // for blanks: the code with the hidden line shown as ____
}

/// How a quiz plays at [level]: more questions and less time as you climb.
({int count, int seconds}) quizShape(int level) => (count: min(5 + level ~/ 5, 10), seconds: max(8, 20 - level ~/ 3));

/// Quiz kinds open at [level].
List<QuizKind> kindsAt(int level) => [
  for (final k in QuizKind.values)
    if (level >= k.fromLevel) k,
];

/// A shuffled set of options containing [right]; returns the options and where [right] ended up.
(List<String>, int) _options(String right, Iterable<String> pool, Random rnd, {int size = 4}) {
  final wrong = {...pool}
    ..remove(right)
    ..removeWhere((w) => w.trim().isEmpty);
  final picked = (wrong.toList()..shuffle(rnd)).take(size - 1).toList();
  final all = [right, ...picked]..shuffle(rnd);
  return (all, all.indexOf(right));
}

QuizQuestion? topicQuestion(Problem p, List<String> topics, Random rnd) {
  final (opts, i) = _options(p.topic, topics, rnd);
  if (opts.length < 2) return null;
  return QuizQuestion(kind: QuizKind.topic, problem: p.name, prompt: 'Which topic is "${p.name}" from?', options: opts, answer: i);
}

QuizQuestion? patternQuestion(Problem p, Random rnd) {
  if (p.patterns.isEmpty) return null;
  final right = p.patterns[rnd.nextInt(p.patterns.length)];
  final (opts, i) = _options(right, dsaPatterns.where((x) => !p.patterns.contains(x)), rnd);
  return QuizQuestion(kind: QuizKind.pattern, problem: p.name, prompt: 'Which pattern solves "${p.name}"?', options: opts, answer: i);
}

QuizQuestion? complexityQuestion(Problem p, Solution s, Random rnd) {
  if (s.time.isEmpty) return null;
  final (opts, i) = _options(s.time, complexities, rnd);
  return QuizQuestion(
    kind: QuizKind.complexity,
    problem: p.name,
    prompt: 'What is the time complexity of your solution to "${p.name}"?',
    options: opts,
    answer: i,
  );
}

/// Small believable mistakes, used to turn the real line into wrong options.
final _mutations = <(Pattern, String Function(Match))>[
  (RegExp('<='), (_) => '<'),
  (RegExp('<(?![=<])'), (_) => '<='),
  (RegExp('>='), (_) => '>'),
  (RegExp('>(?![=>])'), (_) => '>='),
  (RegExp(r'\+\+'), (_) => '--'),
  (RegExp('--'), (_) => '++'),
  (RegExp(r'\+ ?1\b'), (_) => '- 1'),
  (RegExp(r'- ?1\b'), (_) => '+ 1'),
  (RegExp('&&'), (_) => '||'),
  (RegExp(r'\|\|'), (_) => '&&'),
  (RegExp('=='), (_) => '!='),
  (RegExp('!='), (_) => '=='),
  (RegExp(r'\bi\b'), (_) => 'j'),
  (RegExp(r'\bj\b'), (_) => 'i'),
  (RegExp(r'\b0\b'), (_) => '1'),
  (RegExp(r'\b1\b'), (_) => '0'),
  (RegExp(r'\bn\b'), (_) => 'n - 1'),
  (RegExp(r'\bmax\b'), (_) => 'min'),
  (RegExp(r'\bmin\b'), (_) => 'max'),
];

/// Every distinct single-mutation variant of [line].
Set<String> variants(String line) => {
  for (final (from, to) in _mutations)
    for (final m in from.allMatches(line)) line.replaceRange(m.start, m.end, to(m)),
}..remove(line);

/// Hides one key line of your code (a loop, condition or update) and asks which line goes there.
QuizQuestion? blankQuestion(Problem p, Solution s, Random rnd) {
  final lines = s.code.split('\n');
  final candidates = [
    for (final (i, l) in lines.indexed)
      if (l.trim().length >= 6 && l.trim().length <= 80 && !l.trim().startsWith('//') && variants(l.trim()).length >= 3) i,
  ];
  if (candidates.isEmpty) return null;
  final at = candidates[rnd.nextInt(candidates.length)];
  final right = lines[at].trim();
  final (opts, i) = _options(right, variants(right), rnd);
  if (opts.length < 4) return null;
  final indent = lines[at].substring(0, lines[at].length - lines[at].trimLeft().length);
  final shown = [...lines]..[at] = '${indent}____';
  return QuizQuestion(
    kind: QuizKind.blank,
    problem: p.name,
    prompt: 'Which line completes your solution to "${p.name}"?',
    options: opts,
    answer: i,
    code: shown.join('\n'),
  );
}

/// Builds a quiz from your stack at your [level]: kinds you have unlocked, mixed, up to the level's count.
List<QuizQuestion> buildQuiz(List<Problem> problems, Map<String, Solution> solutions, int level, Random rnd) {
  final kinds = kindsAt(level);
  final topics = {...problems.map((p) => p.topic), ..._fallbackTopics}.toList();
  final pool = <QuizQuestion>[];
  for (final p in problems) {
    final s = solutions[p.id] ?? const Solution();
    for (final k in kinds) {
      final q = switch (k) {
        QuizKind.topic => topicQuestion(p, topics, rnd),
        QuizKind.pattern => patternQuestion(p, rnd),
        QuizKind.complexity => complexityQuestion(p, s, rnd),
        QuizKind.blank => blankQuestion(p, s, rnd),
      };
      if (q != null) pool.add(q);
    }
  }
  // Take kinds in turn (hardest first) so one kind never crowds out the rest.
  pool.shuffle(rnd);
  final byKind = {for (final k in kinds.reversed) k: pool.where((q) => q.kind == k).toList()};
  final kept = <QuizQuestion>[];
  final target = quizShape(level).count;
  while (kept.length < target && byKind.values.any((l) => l.isNotEmpty)) {
    for (final l in byKind.values) {
      if (l.isNotEmpty && kept.length < target) kept.add(l.removeAt(0));
    }
  }
  return kept..shuffle(rnd);
}

const _fallbackTopics = ['Arrays', 'Strings', 'Linked List', 'Binary Search', 'Recursion', 'Graphs', 'Dynamic Programming', 'Trees'];
