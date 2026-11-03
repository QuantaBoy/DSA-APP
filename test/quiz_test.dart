import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/quiz.dart';

Problem _p(String id, {List<String> patterns = const []}) => Problem.solved(
  id: id,
  name: id,
  platform: 'LeetCode',
  difficulty: 'Easy',
  topic: 'Arrays',
  solvedOn: DateTime.utc(2026),
).copyWith(patterns: patterns);

const _code = '''
int n = nums.size();
for (int i = 0; i < n; i++) {
  if (seen.count(target - nums[i])) return {seen[target - nums[i]], i};
  seen[nums[i]] = i;
}''';

void main() {
  test('wrong options are small believable changes of the real line', () {
    final v = variants('for (int i = 0; i < n; i++) {');
    expect(v, contains('for (int i = 0; i <= n; i++) {'));
    expect(v, contains('for (int i = 0; i < n; i--) {'));
    expect(v, isNot(contains('for (int i = 0; i < n; i++) {')));
  });

  test('a blank hides one line and the right answer is that line', () {
    final q = blankQuestion(_p('two-sum'), const Solution(code: _code), Random(1))!;
    expect(q.options.toSet().length, 4);
    expect(q.code, contains('____'));
    expect(_code, contains(q.options[q.answer]));
  });

  test('pattern and complexity questions come from the solution card', () {
    final q = patternQuestion(_p('a', patterns: ['Hashing']), Random(2))!;
    expect(q.options[q.answer], 'Hashing');
    expect(complexityQuestion(_p('a'), const Solution(), Random(2)), isNull);
    expect(complexityQuestion(_p('a'), const Solution(time: 'O(n)'), Random(2))!.options, contains('O(n)'));
  });

  test('levels unlock harder kinds and longer, faster quizzes', () {
    expect(kindsAt(1), [QuizKind.topic, QuizKind.pattern]);
    expect(kindsAt(5), QuizKind.values);
    expect(quizShape(1).count, 5);
    expect(quizShape(30).count, 10);
    expect(quizShape(30).seconds, lessThan(quizShape(1).seconds));
  });

  test('a quiz mixes kinds and never repeats the same question', () {
    final ps = [
      for (var i = 0; i < 6; i++) _p('p$i', patterns: ['Hashing']),
    ];
    final sols = {for (final p in ps) p.id: const Solution(code: _code, time: 'O(n)')};
    final quiz = buildQuiz(ps, sols, 10, Random(3));
    expect(quiz.length, quizShape(10).count);
    expect(quiz.map((q) => q.kind).toSet().length, greaterThan(2));
  });
}
