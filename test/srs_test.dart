import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Problem problem(String id, String topic) => Problem.solved(
      id: id, name: 'P$id', platform: 'LeetCode', difficulty: 'Easy', topic: topic, solvedOn: d(2026, 10, 1));

void main() {
  test('new problem is due the day after it was solved', () {
    final p = Problem.solved(id: '1', name: 'Two Sum', platform: 'LeetCode', difficulty: 'Easy', topic: 'Array',
        solvedOn: DateTime(2026, 10, 31, 23, 30));
    expect(p.stage, 0);
    expect(p.nextDue, d(2026, 11, 1));
    expect(p.isDue(DateTime(2026, 10, 31)), isFalse);
    expect(p.isDue(DateTime(2026, 11, 3)), isTrue);
    expect(p.daysOverdue(DateTime(2026, 11, 3)), 2);
  });

  test('remembered climbs one stage and caps at yearly', () {
    expect(afterReview(0, true, d(2026, 10, 25)), (1, d(2026, 10, 28)));
    expect(afterReview(9, true, d(2026, 10, 25)), (9, d(2027, 10, 25)));
  });

  test('forgot drops two stages, never below zero', () {
    expect(afterReview(5, false, d(2026, 10, 25)), (3, d(2026, 11, 8)));
    expect(afterReview(1, false, d(2026, 10, 25)), (0, d(2026, 10, 26)));
  });

  test('review reschedules and counts the review', () {
    final updated = problem('1', 'Array').review(remembered: true, on: DateTime(2026, 10, 2, 8));
    expect(updated.stage, 1);
    expect(updated.nextDue, d(2026, 10, 5));
    expect([updated.reviews, updated.remembered], [1, 1]);
    final forgot = updated.review(remembered: false, on: d(2026, 10, 5));
    expect([forgot.reviews, forgot.remembered], [2, 1]);
  });

  test('ten remembered reviews reach mastered', () {
    var p = problem('1', 'Array');
    for (var i = 0; i < 10; i++) {
      p = p.review(remembered: true, on: p.nextDue);
    }
    expect(p.mastered, isTrue);
  });

  test('streak counts consecutive days', () {
    final days = [d(2026, 10, 24), d(2026, 10, 23), d(2026, 10, 21)];
    expect(streak(days, d(2026, 10, 25)), 2); // not reviewed today yet, yesterday still counts
    expect(streak([...days, d(2026, 10, 25)], d(2026, 10, 25)), 3);
    expect(streak([d(2026, 10, 20)], d(2026, 10, 25)), 0);
    expect(streak([d(2026, 2, 28), d(2026, 3, 1)], d(2026, 3, 1)), 2); // across a month end
  });

  test('next topic follows the roadmap', () {
    expect(nextTopic([], {}), (topic: 'Array', reason: NextReason.learn));
    final fiveArrays = [for (var i = 0; i < 5; i++) problem('$i', 'Array')];
    expect(nextTopic(fiveArrays, {}).topic, 'String');
  });

  test('next topic reinforces the weakest topic first', () {
    final problems = [problem('a', 'Array'), problem('g', 'Graph')];
    final results = {'Array': (remembered: 2, total: 3), 'Graph': (remembered: 1, total: 4)}; // 67% fine, 25% weak
    expect(nextTopic(problems, results), (topic: 'Graph', reason: NextReason.reinforce));
    // Two bad reviews are not enough evidence yet.
    expect(nextTopic(problems, {'Graph': (remembered: 0, total: 2)}).reason, NextReason.learn);
  });

  test('problem survives a save and load', () {
    final p = Problem.solved(id: 'x', name: 'Two Sum', platform: 'LeetCode', difficulty: 'Easy', topic: 'Array',
            url: 'https://leetcode.com/problems/two-sum', solvedOn: DateTime(2026, 1, 9, 23, 59))
        .review(remembered: true, on: d(2026, 1, 10));
    final map = p.toMap();
    expect(map['solvedOn'], '2026-01-09');
    final back = Problem.fromMap('x', map);
    expect([back.name, back.url, back.stage, back.reviews, back.remembered], [p.name, p.url, 1, 1, 1]);
    expect([back.solvedOn, back.nextDue], [p.solvedOn, p.nextDue]);
  });

  test('stats read from the stored totals', () {
    final s = Stats.fromMap({
      'days': {'2026-10-27': 2, '2026-10-28': 1},
      'topics': {'Array': {'remembered': 2, 'total': 3}},
    });
    expect([s.reviews, s.reviewsOn(d(2026, 10, 27)), s.reviewsOn(d(2026, 10, 1))], [3, 2, 0]);
    expect(s.recall, closeTo(2 / 3, 1e-9));
    expect(const Stats().recall, isNull);
  });
}
