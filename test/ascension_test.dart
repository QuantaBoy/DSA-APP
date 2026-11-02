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

  test('XP counts solves by difficulty and aptitude, not streaks', () {
    const none = Stats();
    expect(totalXp((problems: [_p('a', 'Easy'), _p('b', 'Hard')], stats: none, aptCorrect: 0, aptWrong: 0)), 130);
    expect(totalXp((problems: const [], stats: none, aptCorrect: 2, aptWrong: 1)), 18);
    final run = Stats(days: {DateTime.utc(2026, 1, 1): 1, DateTime.utc(2026, 1, 2): 1, DateTime.utc(2026, 1, 3): 1});
    expect(totalXp((problems: const [], stats: run, aptCorrect: 0, aptWrong: 0)), 0);
  });

  test('ranks follow levels', () {
    expect(Rank.of(1), Rank.awakened);
    expect(Rank.of(5), Rank.shadowInitiate);
    expect(Rank.of(80), Rank.monarch);
  });

  test('a topic title is earned only when all of the topic is solved', () {
    SheetProblem sp(String id) => SheetProblem.fromJson({'id': id, 's': 1, 'sec': 'Patterns', 't': id, 'p': 'LeetCode', 'u': 'u'});
    final sheet = Sheet(title: 'A2Z', source: '', steps: ['Beginner Problems'], problems: [for (var i = 0; i < 8; i++) sp('p$i')]);
    Deeds solved(int n) => (problems: [for (var i = 0; i < n; i++) _p('p$i', 'Easy')], stats: const Stats(), aptCorrect: 0, aptWrong: 0);
    expect(earnedTitles(solved(7), sheet), isEmpty);
    expect(earnedTitles(solved(8), sheet), containsAll(['patterns', 'a2z']));
    expect(nextTitle(solved(3), sheet)!.progress, (done: 3, total: 8));
  });

  test('a solve with no review still lights the heatmap and keeps the streak', () {
    final day = DateTime.utc(2026, 1, 1);
    final p = _p('x', 'Easy');
    expect(activityPerDay([p], const Stats()), {day: 1});
    expect(activityPerDay([p], Stats(days: {day: 2})), {day: 3});
    expect(activeDays([p], const Stats()), {day});
  });
}
