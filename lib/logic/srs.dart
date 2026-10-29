/// Spaced-repetition rules. Pure Dart, no Flutter or Firebase, so it is easy to test.
library;

/// Days until the next review for each stage. The last stage repeats yearly forever.
const reviewIntervals = [1, 3, 7, 14, 30, 60, 90, 120, 180, 365];

/// Common DSA topics, in learning order. Names match the LeetCode tags in the problem catalog.
const roadmap = [
  'Array',
  'String',
  'Hash Table',
  'Two Pointers',
  'Sliding Window',
  'Stack',
  'Binary Search',
  'Linked List',
  'Tree',
  'Heap (Priority Queue)',
  'Backtracking',
  'Graph',
  'Dynamic Programming',
  'Greedy',
  'Trie',
  'Union Find',
  'Bit Manipulation',
  'Math',
];

/// Calendar day only, in UTC, so adding days never shifts the hour (no daylight-saving surprises).
DateTime dateOnly(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateTime today() => dateOnly(DateTime.now());

DateTime addDays(DateTime day, int days) => DateTime.utc(day.year, day.month, day.day + days);

DateTime firstDue(DateTime solvedOn) => addDays(dateOnly(solvedOn), reviewIntervals.first);

/// How well a review went. Everything except [again] counts as remembered.
enum Grade {
  again('Again'),
  hard('Hard'),
  good('Good'),
  easy('Easy');

  const Grade(this.label);
  final String label;

  bool get remembered => this != again;

  /// Stage change: again drops two stages, hard repeats the same interval, good moves up one, easy skips one.
  int get step => switch (this) {
    again => -2,
    hard => 0,
    good => 1,
    easy => 2,
  };
}

/// The new stage and due date after reviewing a problem at [stage].
(int, DateTime) afterReview(int stage, Grade grade, DateTime reviewedOn) {
  final next = (stage + grade.step).clamp(0, reviewIntervals.length - 1);
  return (next, addDays(dateOnly(reviewedOn), reviewIntervals[next]));
}

/// Days until the next review for each grade, for the labels on the grade buttons.
int daysAfter(int stage, Grade grade) => reviewIntervals[(stage + grade.step).clamp(0, reviewIntervals.length - 1)];

/// Consecutive days with at least one review, ending today (or yesterday if not reviewed yet today).
int streak(Iterable<DateTime> reviewDays, DateTime on) {
  final days = reviewDays.map(dateOnly).toSet();
  var day = dateOnly(on);
  if (!days.contains(day)) day = addDays(day, -1);
  var count = 0;
  while (days.contains(day)) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}

/// Longest run of consecutive review days ever.
int longestStreak(Iterable<DateTime> reviewDays) {
  final days = reviewDays.map(dateOnly).toSet();
  var best = 0;
  for (final d in days) {
    if (days.contains(addDays(d, -1))) continue; // only count from the first day of each run
    var length = 1;
    while (days.contains(addDays(d, length))) {
      length++;
    }
    best = best > length ? best : length;
  }
  return best;
}

/// The day the current streak began, or null when there is no streak.
DateTime? streakStart(Iterable<DateTime> reviewDays, DateTime on) {
  final n = streak(reviewDays, on);
  if (n == 0) return null;
  final days = reviewDays.map(dateOnly).toSet();
  final end = days.contains(dateOnly(on)) ? dateOnly(on) : addDays(dateOnly(on), -1);
  return addDays(end, -(n - 1));
}

/// Streak goals, in order. The challenge bar always aims at the next one.
const streakMilestones = [3, 7, 14, 30, 60, 100, 200, 365];

/// The current streak where one missed day per [freezeEvery] streak days is forgiven (a "streak freeze"),
/// with the forgiven days so the streak screen can show them.
({int days, List<DateTime> frozen}) streakInfo(Iterable<DateTime> reviewDays, DateTime on, {int freezeEvery = 7}) {
  final days = reviewDays.map(dateOnly).toSet();
  var day = dateOnly(on);
  if (!days.contains(day)) day = addDays(day, -1); // today still open
  var count = 0;
  int? lastFreezeAt; // streak length when the last freeze was used
  final frozen = <DateTime>[];
  while (true) {
    if (days.contains(day)) {
      count++;
      day = addDays(day, -1);
      continue;
    }
    final canFreeze = count > 0 && days.contains(addDays(day, -1)) && (lastFreezeAt == null || count - lastFreezeAt >= freezeEvery);
    if (!canFreeze) break;
    lastFreezeAt = count;
    frozen.add(day);
    day = addDays(day, -1);
  }
  return (days: count, frozen: frozen);
}

/// Streak length with freezes, for the places that only show the number.
int streakWithFreezes(Iterable<DateTime> reviewDays, DateTime on) => streakInfo(reviewDays, on).days;

/// A mock interview on a problem you already solved counts as a review:
/// not solved is Again, solved within half the time is Easy, within the time Good, over it Hard.
Grade interviewGrade({required bool solved, required Duration took, required Duration limit}) {
  if (!solved) return Grade.again;
  if (took <= limit ~/ 2) return Grade.easy;
  return took <= limit ? Grade.good : Grade.hard;
}
