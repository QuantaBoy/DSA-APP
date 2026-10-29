import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Problem problem(String id, String topic) =>
    Problem.solved(id: id, name: 'P$id', platform: 'LeetCode', difficulty: 'Easy', topic: topic, solvedOn: d(2026, 10, 1));

void main() {
  test('new problem is due the day after it was solved', () {
    final p = Problem.solved(
      id: '1',
      name: 'Two Sum',
      platform: 'LeetCode',
      difficulty: 'Easy',
      topic: 'Array',
      solvedOn: DateTime(2026, 10, 31, 23, 30),
    );
    expect(p.stage, 0);
    expect(p.nextDue, d(2026, 11, 1));
    expect(p.isDue(DateTime(2026, 10, 31)), isFalse);
    expect(p.isDue(DateTime(2026, 11, 3)), isTrue);
    expect(p.daysOverdue(DateTime(2026, 11, 3)), 2);
  });

  test('good climbs one stage, easy two, both capped at yearly', () {
    expect(afterReview(0, Grade.good, d(2026, 10, 25)), (1, d(2026, 10, 28)));
    expect(afterReview(0, Grade.easy, d(2026, 10, 25)), (2, d(2026, 11, 1)));
    expect(afterReview(9, Grade.good, d(2026, 10, 25)), (9, d(2027, 10, 25)));
    expect(afterReview(8, Grade.easy, d(2026, 10, 25)).$1, 9);
  });

  test('hard repeats the same interval; again drops two stages, never below zero', () {
    expect(afterReview(3, Grade.hard, d(2026, 10, 25)), (3, d(2026, 11, 8)));
    expect(afterReview(5, Grade.again, d(2026, 10, 25)), (3, d(2026, 11, 8)));
    expect(afterReview(1, Grade.again, d(2026, 10, 25)), (0, d(2026, 10, 26)));
  });

  test('grade buttons show the days until the next review', () {
    expect([for (final g in Grade.values) daysAfter(2, g)], [1, 7, 14, 30]);
    expect(Grade.values.where((g) => g.remembered), [Grade.hard, Grade.good, Grade.easy]);
  });

  test('review reschedules and counts the review', () {
    final updated = problem('1', 'Array').review(grade: Grade.good, on: DateTime(2026, 10, 2, 8));
    expect(updated.stage, 1);
    expect(updated.nextDue, d(2026, 10, 5));
    expect([updated.reviews, updated.remembered], [1, 1]);
    final forgot = updated.review(grade: Grade.again, on: d(2026, 10, 5));
    expect([forgot.reviews, forgot.remembered], [2, 1]);
  });

  test('ten remembered reviews reach mastered', () {
    var p = problem('1', 'Array');
    for (var i = 0; i < 10; i++) {
      p = p.review(grade: Grade.good, on: p.nextDue);
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

  test('problem survives a save and load', () {
    final p = Problem.solved(
      id: 'x',
      name: 'Two Sum',
      platform: 'LeetCode',
      difficulty: 'Easy',
      topic: 'Array',
      url: 'https://leetcode.com/problems/two-sum',
      solvedOn: DateTime(2026, 1, 9, 23, 59),
    ).review(grade: Grade.good, on: d(2026, 1, 10));
    final map = p.toMap();
    expect(map['solvedOn'], '2026-01-09');
    final back = Problem.fromMap('x', map);
    expect([back.name, back.url, back.stage, back.reviews, back.remembered], [p.name, p.url, 1, 1, 1]);
    expect([back.solvedOn, back.nextDue], [p.solvedOn, p.nextDue]);
  });

  test('stats read from the stored totals', () {
    final s = Stats.fromMap({
      'days': {'2026-10-27': 2, '2026-10-28': 1},
      'topics': {
        'Array': {'remembered': 2, 'total': 3},
      },
    });
    expect([s.reviews, s.reviewsOn(d(2026, 10, 27)), s.reviewsOn(d(2026, 10, 1))], [3, 2, 0]);
    expect(s.recall, closeTo(2 / 3, 1e-9));
    expect(const Stats().recall, isNull);
  });

  test('longest streak and when the current one started', () {
    final days = [d(2026, 10, 1), d(2026, 10, 2), d(2026, 10, 3), d(2026, 10, 10), d(2026, 10, 11)];
    expect(longestStreak(days), 3);
    expect(longestStreak([]), 0);
    expect(streakStart(days, d(2026, 10, 11)), d(2026, 10, 10));
    expect(streakStart(days, d(2026, 10, 12)), d(2026, 10, 10), reason: 'not reviewed yet today, streak still alive');
    expect(streakStart(days, d(2026, 10, 20)), isNull);
  });

  test('one missed day a week is forgiven by a streak freeze', () {
    // Reviewed 1-5 Oct, missed 6 Oct, reviewed 7-10 Oct.
    final days = [
      for (var i = 1; i <= 10; i++)
        if (i != 6) d(2026, 10, i),
    ];
    final info = streakInfo(days, d(2026, 10, 10));
    expect(info.days, 9);
    expect(info.frozen, [d(2026, 10, 6)]);
    expect(streak(days, d(2026, 10, 10)), 4, reason: 'plain streak still breaks');
    // Two gaps within a week: only the later one is forgiven.
    final twoGaps = [d(2026, 10, 1), d(2026, 10, 3), d(2026, 10, 5), d(2026, 10, 6)];
    expect(streakInfo(twoGaps, d(2026, 10, 6)).days, 3);
    // A two-day gap is never forgiven.
    expect(streakInfo([d(2026, 10, 1), d(2026, 10, 4)], d(2026, 10, 4)).days, 1);
  });

  test('mock interview results become review grades', () {
    const limit = Duration(minutes: 30);
    expect(interviewGrade(solved: false, took: const Duration(minutes: 5), limit: limit), Grade.again);
    expect(interviewGrade(solved: true, took: const Duration(minutes: 12), limit: limit), Grade.easy);
    expect(interviewGrade(solved: true, took: const Duration(minutes: 25), limit: limit), Grade.good);
    expect(interviewGrade(solved: true, took: const Duration(minutes: 31), limit: limit), Grade.hard);
  });
}
