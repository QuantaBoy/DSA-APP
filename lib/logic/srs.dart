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

/// Remembered moves one stage up; forgot drops two stages so it comes back soon.
(int, DateTime) afterReview(int stage, bool remembered, DateTime reviewedOn) {
  final next = remembered ? (stage + 1).clamp(0, reviewIntervals.length - 1) : (stage - 2).clamp(0, reviewIntervals.length - 1);
  return (next, addDays(dateOnly(reviewedOn), reviewIntervals[next]));
}

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
