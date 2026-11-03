import 'srs.dart';

const platforms = ['LeetCode', 'Codeforces', 'CodeChef', 'Other'];

/// Input limits. maxNoteLength must match isValidNote() in firestore.rules.
abstract final class Limits {
  static const nameLength = 150;
  static const topicLength = 60;
  static const urlLength = 500;
  static const maxNoteLength = 20000; // code
  static const shortTextLength = 500; // idea, mistake
  static const questionLength = 5000; // the question, pasted in your own words
  static const complexityLength = 40;
  static const maxPatterns = 8;
  static const aptQuestionLength = 2000;
  static const aptOptionLength = 300;
  static const aptExplanationLength = 3000;
  static const minOptions = 2, maxOptions = 6;
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
  const Solution({this.question = '', this.idea = '', this.time = '', this.space = '', this.mistake = '', this.code = ''});

  final String question; // the problem statement, for reviews of problems whose text the app cannot fetch

  final String idea; // the key insight in one line
  final String time;
  final String space;
  final String mistake; // what went wrong last time
  final String code;

  bool get isEmpty => question.isEmpty && idea.isEmpty && time.isEmpty && space.isEmpty && mistake.isEmpty && code.isEmpty;

  Solution copyWith({String? question, String? idea, String? time, String? space, String? mistake, String? code}) => Solution(
    question: question ?? this.question,
    idea: idea ?? this.idea,
    time: time ?? this.time,
    space: space ?? this.space,
    mistake: mistake ?? this.mistake,
    code: code ?? this.code,
  );

  /// Only non-empty fields are stored. `text` is the code (the field name predates the card).
  Map<String, String> toMap() => {
    if (code.isNotEmpty) 'text': code,
    if (question.isNotEmpty) 'question': question,
    if (idea.isNotEmpty) 'idea': idea,
    if (time.isNotEmpty) 'time': time,
    if (space.isNotEmpty) 'space': space,
    if (mistake.isNotEmpty) 'mistake': mistake,
  };

  factory Solution.fromMap(Map<String, dynamic> m) => Solution(
    code: m['text'] as String? ?? '',
    question: m['question'] as String? ?? '',
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
    this.last,
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

  /// The latest review: its grade and the schedule before it, so a mis-tap can be corrected later.
  final ({Grade grade, int stage, DateTime due})? last;

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
    if (last case final l?) 'last': {'grade': l.grade.name, 'stage': l.stage, 'due': dayKey(l.due)},
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
    last: switch (m['last']) {
      {'grade': final String g, 'stage': final int s, 'due': final String d} when Grade.values.any((x) => x.name == g) => (
        grade: Grade.values.byName(g),
        stage: s,
        due: parseDay(d),
      ),
      _ => null,
    },
  );

  Problem copyWith({
    int? stage,
    DateTime? nextDue,
    int? reviews,
    int? remembered,
    List<String>? patterns,
    ({Grade grade, int stage, DateTime due})? last,
  }) => Problem(
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
    last: last ?? this.last,
  );

  /// The problem after one review: rescheduled, with its counts updated.
  Problem review({required Grade grade, required DateTime on}) {
    final (newStage, due) = afterReview(stage, grade, dateOnly(on));
    return copyWith(
      stage: newStage,
      nextDue: due,
      reviews: reviews + 1,
      remembered: remembered + (grade.remembered ? 1 : 0),
      last: (grade: grade, stage: stage, due: nextDue),
    );
  }

  /// The latest review graded [grade] instead: schedule redone from before it, counts adjusted, no new review.
  Problem regrade(Grade grade, {required DateTime on}) {
    final l = last;
    if (l == null) return this;
    final (newStage, due) = afterReview(l.stage, grade, dateOnly(on));
    return copyWith(
      stage: newStage,
      nextDue: due,
      remembered: remembered - (l.grade.remembered ? 1 : 0) + (grade.remembered ? 1 : 0),
      last: (grade: grade, stage: l.stage, due: l.due),
    );
  }
}

/// Running review totals, stored next to the problems so no screen ever reads a review history.
class Stats {
  const Stats({this.days = const {}, this.topics = const {}, this.quizRight = 0});

  final Map<DateTime, int> days; // reviews done per day
  final Map<String, ({int remembered, int total})> topics; // only problems still in the stack count
  final int quizRight; // quiz answers got right, ever (worth XP)

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
    quizRight: m['quiz'] as int? ?? 0,
  );
}

/// Days are stored as 'YYYY-MM-DD' text: no time zone, sorts correctly, readable in the Firebase console.
String dayKey(DateTime day) => dateOnly(day).toIso8601String().substring(0, 10);

DateTime parseDay(String key) => dateOnly(DateTime.parse(key));

/// "26 Oct 2026"
String prettyDay(DateTime d) =>
    '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';

/// An aptitude question (multiple choice), revised like a problem: right moves it up a stage, wrong drops it.
class AptCard {
  const AptCard({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    this.explanation = '',
    this.topic = 'General',
    required this.stage,
    required this.nextDue,
    this.reviews = 0,
    this.remembered = 0,
  });

  /// A new card: first review tomorrow.
  factory AptCard.fresh({
    required String id,
    required String question,
    required List<String> options,
    required int answer,
    String explanation = '',
    String topic = 'General',
  }) => AptCard(
    id: id,
    question: question,
    options: options,
    answer: answer,
    explanation: explanation,
    topic: topic,
    stage: 0,
    nextDue: firstDue(today()),
  );

  final String id;
  final String question;
  final List<String> options;
  final int answer; // index into options
  final String explanation;
  final String topic;
  final int stage;
  final DateTime nextDue;
  final int reviews;
  final int remembered;

  bool isDue(DateTime on) => !nextDue.isAfter(on);

  /// Within the limits the security rules enforce.
  bool get isValid =>
      question.trim().isNotEmpty &&
      question.length <= Limits.aptQuestionLength &&
      options.length >= Limits.minOptions &&
      options.length <= Limits.maxOptions &&
      options.every((o) => o.trim().isNotEmpty && o.length <= Limits.aptOptionLength) &&
      answer >= 0 &&
      answer < options.length &&
      explanation.length <= Limits.aptExplanationLength &&
      topic.trim().isNotEmpty &&
      topic.length <= Limits.topicLength;

  AptCard review({required bool correct, required DateTime on}) {
    final (stage, nextDue) = afterReview(this.stage, correct ? Grade.good : Grade.again, on);
    return copyWith(stage: stage, nextDue: nextDue, reviews: reviews + 1, remembered: remembered + (correct ? 1 : 0));
  }

  AptCard copyWith({
    String? question,
    List<String>? options,
    int? answer,
    String? explanation,
    String? topic,
    int? stage,
    DateTime? nextDue,
    int? reviews,
    int? remembered,
  }) => AptCard(
    id: id,
    question: question ?? this.question,
    options: options ?? this.options,
    answer: answer ?? this.answer,
    explanation: explanation ?? this.explanation,
    topic: topic ?? this.topic,
    stage: stage ?? this.stage,
    nextDue: nextDue ?? this.nextDue,
    reviews: reviews ?? this.reviews,
    remembered: remembered ?? this.remembered,
  );

  Map<String, dynamic> toMap() => {
    'question': question,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    'topic': topic,
    'stage': stage,
    'nextDue': dayKey(nextDue),
    'reviews': reviews,
    'remembered': remembered,
  };

  factory AptCard.fromMap(String id, Map<String, dynamic> m) => AptCard(
    id: id,
    question: m['question'] as String,
    options: (m['options'] as List).cast<String>(),
    answer: m['answer'] as int,
    explanation: m['explanation'] as String? ?? '',
    topic: m['topic'] as String? ?? 'General',
    stage: m['stage'] as int? ?? 0,
    nextDue: parseDay(m['nextDue'] as String),
    reviews: m['reviews'] as int? ?? 0,
    remembered: m['remembered'] as int? ?? 0,
  );
}

/// Days you did something: reviewed, or solved a new problem. The streak counts these.
Set<DateTime> activeDays(Iterable<Problem> problems, Stats stats) => {
  ...stats.days.keys.map(dateOnly),
  for (final p in problems) dateOnly(p.solvedOn),
};

/// Things done per day: reviews plus new problems solved. Feeds the activity heatmap.
Map<DateTime, int> activityPerDay(Iterable<Problem> problems, Stats stats) {
  final days = {for (final e in stats.days.entries) dateOnly(e.key): e.value};
  for (final p in problems) {
    final d = dateOnly(p.solvedOn);
    days[d] = (days[d] ?? 0) + 1;
  }
  return days;
}
