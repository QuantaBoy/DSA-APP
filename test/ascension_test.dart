import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/sheet.dart';
import 'package:memory_stack/logic/ascension.dart';
import 'package:memory_stack/logic/models.dart';

Problem _p(String id, String difficulty) =>
    Problem.solved(id: id, name: id, platform: 'LeetCode', difficulty: difficulty, topic: 't', solvedOn: DateTime.utc(2026, 1, 1));

void main() {
  test('levels come quickly at first and need more XP later', () {
    expect(levelFor(0), (level: 1, into: 0, needed: 140));
    expect(levelFor(140).level, 2);
    expect(levelFor(139).level, 1);
    expect(xpToNext(10), greaterThan(xpToNext(2)));
  });

  test('XP counts solves by difficulty, streak runs and aptitude', () {
    const none = Stats();
    expect(totalXp((problems: [_p('a', 'Easy'), _p('b', 'Hard')], stats: none, aptCorrect: 0, aptWrong: 0)), 130);
    expect(totalXp((problems: const [], stats: none, aptCorrect: 2, aptWrong: 1)), 18);
    final run = Stats(days: {DateTime.utc(2026, 1, 1): 1, DateTime.utc(2026, 1, 2): 1, DateTime.utc(2026, 1, 3): 1});
    expect(totalXp((problems: const [], stats: run, aptCorrect: 0, aptWrong: 0)), 5 + 10 + 15);
  });

  test('ranks follow levels', () {
    expect(Rank.of(1), Rank.awakened);
    expect(Rank.of(5), Rank.shadowInitiate);
    expect(Rank.of(80), Rank.monarch);
  });

  test('a section title unlocks only when all of it is solved', () {
    SheetProblem sp(String id, String section) =>
        SheetProblem.fromJson({'id': id, 's': 1, 'sec': section, 't': id, 'p': 'LeetCode', 'u': 'u'});
    final sheet = Sheet(title: 'A2Z', source: '', steps: ['Beginner Problems'], problems: [sp('p1', 'Patterns'), sp('p2', 'Patterns')]);
    Set<String> earned(List<Problem> ps) => earnedTitles((problems: ps, stats: const Stats(), aptCorrect: 0, aptWrong: 0), sheet);
    expect(earned([_p('p1', 'Easy')]), isNot(contains('patterns')));
    expect(earned([_p('p1', 'Easy'), _p('p2', 'Easy')]), containsAll(['patterns', 'a2z']));
  });
}
