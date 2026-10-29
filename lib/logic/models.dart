import 'srs.dart';

const platforms = ['LeetCode', 'Codeforces', 'CodeChef', 'Other'];

/// Input limits. maxNoteLength must match isValidNote() in firestore.rules.
abstract final class Limits {
  static const nameLength = 150;
  static const topicLength = 60;
  static const urlLength = 500;
  static const maxNoteLength = 20000; // code
  static const shortTextLength = 500; // idea, mistake
  static const complexityLength = 40;
  static const maxPatterns = 8;
}

const difficulties = ['Easy', 'Medium', 'Hard'];

/// DSA patterns a solution can be tagged with. The pattern library groups problems by these.
const dsaPatterns = [
  'Two Pointers',
  'Sliding Window',
  'Hashing',
  'Prefix Sum',
  'Binary Search',
  'Sorting',
  'Stack',
  'Monotonic Stack',
  'Queue',
  'Linked List',
  'Fast & Slow Pointers',
  'Recursion',
  'Backtracking',
  'Tree Traversal',
  'BST',
  'Heap',
  'Greedy',
  'Intervals',
  'BFS',
  'DFS',
  'Topological Sort',
  'Union Find',
  'Shortest Path',
  'Dynamic Programming',
  'Trie',
  'Bit Manipulation',
  'Math',
  'Matrix',
  'Strings',
  'Divide & Conquer',
  'Design',
];

/// Common complexities, offered as quick picks on the solution card.
const complexities = ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)', 'O(n²)', 'O(n³)', 'O(2ⁿ)', 'O(n!)', 'O(m·n)'];

/// What you want to remember about a solution: the approach first, code last.
/// Stored in users/{uid}/notes/{problemId}; the patterns live on the [Problem] so lists need no extra reads.
class Solution {
  const Solution({this.idea = '', this.time = '', this.space = '', this.mistake = '', this.code = ''});

  final String idea; // the key insight in one line
  final String time;
  final String space;
  final String mistake; // what went wrong last time
  final String code;

  bool get isEmpty => idea.isEmpty && time.isEmpty && space.isEmpty && mistake.isEmpty && code.isEmpty;

  Solution copyWith({String? idea, String? time, String? space, String? mistake, String? code}) => Solution(
    idea: idea ?? this.idea,
    time: time ?? this.time,
    space: space ?? this.space,
    mistake: mistake ?? this.mistake,
    code: code ?? this.code,
  );

  /// Only non-empty fields are stored. `text` is the code (the field name predates the card).
  Map<String, String> toMap() => {
    if (code.isNotEmpty) 'text': code,
    if (idea.isNotEmpty) 'idea': idea,
    if (time.isNotEmpty) 'time': time,
    if (space.isNotEmpty) 'space': space,
    if (mistake.isNotEmpty) 'mistake': mistake,
  };

  factory Solution.fromMap(Map<String, dynamic> m) => Solution(
    code: m['text'] as String? ?? '',
    idea: m['idea'] as String? ?? '',
    time: m['time'] as String? ?? '',
    space: m['space'] as String? ?? '',
    mistake: m['mistake'] as String? ?? '',
  );
}

/// A problem you solved, plus where it is in the review schedule.
/// Notes are stored separately (see Store.notes) so loading the stack stays one small read.
class Problem {
  const Problem({
    required this.id,
    required this.name,
    required this.platform,
    required this.difficulty,
    required this.topic,
    this.url,
    required this.solvedOn,
    required this.stage,
    required this.nextDue,
    this.reviews = 0,
    this.remembered = 0,
    this.patterns = const [],
  });

  /// A newly added problem: stage 0, first review the day after it was solved.
  factory Problem.solved({
    required String id,
    required String name,
    required String platform,
    required String difficulty,
    required String topic,
    String? url,
    required DateTime solvedOn,
  }) {
    final day = dateOnly(solvedOn);
    return Problem(
      id: id,
      name: name,
      platform: platform,
      difficulty: difficulty,
      topic: topic,
      url: url,
      solvedOn: day,
      stage: 0,
      nextDue: firstDue(day),
    );
  }

  final String id;
  final String name;
  final String platform;
  final String difficulty;
  final String topic;
  final String? url;
  final DateTime solvedOn;
  final int stage; // 0..9, index into reviewIntervals
  final DateTime nextDue;
  final int reviews; // how many times reviewed, and how many of those remembered:
  final int remembered; // kept so deleting the problem can take it out of the topic totals
  final List<String> patterns; // e.g. ['Two Pointers'], from the solution card

  bool get mastered => stage == reviewIntervals.length - 1;
  bool isDue(DateTime today) => !nextDue.isAfter(dateOnly(today));
  int daysOverdue(DateTime today) => dateOnly(today).difference(nextDue).inDays;

  Map<String, Object?> toMap() => {
    'name': name,
    'platform': platform,
    'difficulty': difficulty,
    'topic': topic,
    'url': url,
    'solvedOn': dayKey(solvedOn),
    'stage': stage,
    'nextDue': dayKey(nextDue),
    'reviews': reviews,
    'remembered': remembered,
    if (patterns.isNotEmpty) 'patterns': patterns,
  };

  factory Problem.fromMap(String id, Map<String, dynamic> m) => Problem(
    id: id,
    name: m['name'] as String,
    platform: m['platform'] as String,
    difficulty: m['difficulty'] as String,
    topic: m['topic'] as String,
    url: m['url'] as String?,
    solvedOn: parseDay(m['solvedOn'] as String),
    stage: m['stage'] as int,
    nextDue: parseDay(m['nextDue'] as String),
    reviews: m['reviews'] as int? ?? 0,
    remembered: m['remembered'] as int? ?? 0,
    patterns: [...?(m['patterns'] as List?)?.whereType<String>()],
  );

  Problem copyWith({int? stage, DateTime? nextDue, int? reviews, int? remembered, List<String>? patterns}) => Problem(
    id: id,
    name: name,
    platform: platform,
    difficulty: difficulty,
    topic: topic,
    url: url,
    solvedOn: solvedOn,
    stage: stage ?? this.stage,
    nextDue: nextDue ?? this.nextDue,
    reviews: reviews ?? this.reviews,
    remembered: remembered ?? this.remembered,
    patterns: patterns ?? this.patterns,
  );

  /// The problem after one review: rescheduled, with its counts updated.
  Problem review({required Grade grade, required DateTime on}) {
    final (newStage, due) = afterReview(stage, grade, dateOnly(on));
    return copyWith(stage: newStage, nextDue: due, reviews: reviews + 1, remembered: remembered + (grade.remembered ? 1 : 0));
  }
}

/// Running review totals, stored next to the problems so no screen ever reads a review history.
class Stats {
  const Stats({this.days = const {}, this.topics = const {}});

  final Map<DateTime, int> days; // reviews done per day
  final Map<String, ({int remembered, int total})> topics; // only problems still in the stack count

  int get reviews => days.values.fold(0, (a, b) => a + b);
  int reviewsOn(DateTime day) => days[dateOnly(day)] ?? 0;

  /// Share of reviews remembered, or null before the first review.
  double? get recall {
    final total = topics.values.fold(0, (a, t) => a + t.total);
    return total == 0 ? null : topics.values.fold(0, (a, t) => a + t.remembered) / total;
  }

  factory Stats.fromMap(Map<String, dynamic> m) => Stats(
    days: {for (final e in (m['days'] as Map? ?? {}).entries) parseDay(e.key as String): e.value as int},
    topics: {
      for (final e in (m['topics'] as Map? ?? {}).entries)
        e.key as String: (remembered: (e.value as Map)['remembered'] as int? ?? 0, total: (e.value as Map)['total'] as int? ?? 0),
    },
  );
}

/// Days are stored as 'YYYY-MM-DD' text: no time zone, sorts correctly, readable in the Firebase console.
String dayKey(DateTime day) => dateOnly(day).toIso8601String().substring(0, 10);

DateTime parseDay(String key) => dateOnly(DateTime.parse(key));

/// "26 Oct 2026"
String prettyDay(DateTime d) =>
    '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
