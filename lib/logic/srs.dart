/// Spaced-repetition rules. Pure Dart, no Flutter or Firebase, so it is easy to test.
library;

import 'models.dart';

/// Days until the next review for each stage. The last stage repeats yearly forever.
const reviewIntervals = [1, 3, 7, 14, 30, 60, 90, 120, 180, 365];

/// Order to learn topics in. Names match the LeetCode tags in the problem catalog.
const roadmap = [
  'Array', 'String', 'Hash Table', 'Two Pointers', 'Sliding Window', 'Stack',
  'Binary Search', 'Linked List', 'Tree', 'Heap (Priority Queue)', 'Backtracking',
  'Graph', 'Dynamic Programming', 'Greedy', 'Trie', 'Union Find', 'Bit Manipulation', 'Math',
];
const problemsPerTopic = 5; // solve this many in a topic before the roadmap moves on
const weakSuccessRate = 0.6;
const minReviewsToJudge = 3;

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

/// Per topic: how many reviews you remembered out of how many you did.
Map<String, ({int remembered, int total})> topicResults(List<Problem> problems, List<Review> reviews) {
  final topicOf = {for (final p in problems) p.id: p.topic};
  final results = <String, ({int remembered, int total})>{};
  for (final r in reviews) {
    final topic = topicOf[r.problemId];
    if (topic == null) continue; // review of a deleted problem
    final old = results[topic] ?? (remembered: 0, total: 0);
    results[topic] = (remembered: old.remembered + (r.remembered ? 1 : 0), total: old.total + 1);
  }
  return results;
}

enum NextReason { reinforce, learn }

/// What to study next: a weak topic first, otherwise the next roadmap topic you have not covered.
({String topic, NextReason reason}) nextTopic(List<Problem> problems, List<Review> reviews) {
  final results = topicResults(problems, reviews);
  String? weakest;
  var weakestRate = 1.0;
  results.forEach((topic, r) {
    final rate = r.remembered / r.total;
    if (r.total >= minReviewsToJudge && rate < weakSuccessRate && rate < weakestRate) {
      weakest = topic;
      weakestRate = rate;
    }
  });
  if (weakest != null) return (topic: weakest!, reason: NextReason.reinforce);

  final solved = <String, int>{};
  for (final p in problems) {
    solved[p.topic] = (solved[p.topic] ?? 0) + 1;
  }
  for (final topic in roadmap) {
    if ((solved[topic] ?? 0) < problemsPerTopic) return (topic: topic, reason: NextReason.learn);
  }
  final leastPracticed = roadmap.reduce((a, b) => (solved[b] ?? 0) < (solved[a] ?? 0) ? b : a);
  return (topic: leastPracticed, reason: NextReason.learn);
}
