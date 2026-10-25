import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Problem problem(String id, String topic) => Problem.solved(
      id: id, name: 'P$id', platform: 'LeetCode', difficulty: 'Easy', topic: topic, solvedOn: d(2026, 10, 1));

Review review(String id, bool remembered) =>
    Review(problemId: id, reviewedOn: d(2026, 10, 5), remembered: remembered, stageBefore: 0);

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

  test('review returns the rescheduled problem and a log entry', () {
    final (updated, log) = problem('1', 'Array').review(remembered: true, on: DateTime(2026, 10, 2, 8));
    expect(updated.stage, 1);
    expect(updated.nextDue, d(2026, 10, 5));
    expect(log.stageBefore, 0);
    expect(log.reviewedOn, d(2026, 10, 2));
  });

  test('ten remembered reviews reach mastered', () {
    var p = problem('1', 'Array');
    for (var i = 0; i < 10; i++) {
      p = p.review(remembered: true, on: p.nextDue).$1;
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
    expect(nextTopic([], []), (topic: 'Array', reason: NextReason.learn));
    final fiveArrays = [for (var i = 0; i < 5; i++) problem('$i', 'Array')];
    expect(nextTopic(fiveArrays, []).topic, 'String');
  });

  test('next topic reinforces the weakest topic first', () {
    final problems = [problem('a', 'Array'), problem('g', 'Graph')];
    final reviews = [
      review('a', true), review('a', false), review('a', true), // Array 67%: fine
      review('g', true), review('g', false), review('g', false), review('g', false), // Graph 25%: weak
    ];
    expect(nextTopic(problems, reviews), (topic: 'Graph', reason: NextReason.reinforce));
    // Two bad reviews are not enough evidence yet.
    expect(nextTopic(problems, [review('g', false), review('g', false)]).reason, NextReason.learn);
  });

  test('problem and review survive a save and load', () {
    final p = Problem.solved(id: 'x', name: 'Two Sum', platform: 'LeetCode', difficulty: 'Easy', topic: 'Array',
        url: 'https://leetcode.com/problems/two-sum', notes: 'hash map', solvedOn: DateTime(2026, 1, 9, 23, 59));
    final map = p.toMap();
    expect(map['solvedOn'], '2026-01-09');
    expect(map['nextDue'], '2026-01-10');
    final back = Problem.fromMap('x', map);
    expect([back.name, back.url, back.notes, back.stage], [p.name, p.url, p.notes, 0]);
    expect([back.solvedOn, back.nextDue], [p.solvedOn, p.nextDue]);

    final r = Review.fromMap(review('x', true).toMap());
    expect([r.problemId, r.reviewedOn, r.remembered, r.stageBefore], ['x', d(2026, 10, 5), true, 0]);
  });

  test('reviews of deleted problems are ignored', () {
    expect(topicResults([problem('a', 'Array')], [review('gone', true)]), isEmpty);
  });
}
