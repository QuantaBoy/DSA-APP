import 'srs.dart';

const platforms = ['LeetCode', 'Codeforces', 'CodeChef', 'Other'];
const difficulties = ['Easy', 'Medium', 'Hard'];

/// A problem you solved, plus where it is in the review schedule.
class Problem {
  const Problem({
    required this.id,
    required this.name,
    required this.platform,
    required this.difficulty,
    required this.topic,
    this.url,
    this.notes,
    required this.solvedOn,
    required this.stage,
    required this.nextDue,
  });

  /// A newly added problem: stage 0, first review the day after it was solved.
  factory Problem.solved({
    required String id,
    required String name,
    required String platform,
    required String difficulty,
    required String topic,
    String? url,
    String? notes,
    required DateTime solvedOn,
  }) {
    final day = dateOnly(solvedOn);
    return Problem(
      id: id, name: name, platform: platform, difficulty: difficulty, topic: topic,
      url: url, notes: notes, solvedOn: day, stage: 0, nextDue: firstDue(day),
    );
  }

  final String id;
  final String name;
  final String platform;
  final String difficulty;
  final String topic;
  final String? url;
  final String? notes; // your solution, key idea, complexity: whatever helps you recall
  final DateTime solvedOn;
  final int stage; // 0..9, index into reviewIntervals
  final DateTime nextDue;

  bool get mastered => stage == reviewIntervals.length - 1;
  bool isDue(DateTime today) => !nextDue.isAfter(dateOnly(today));
  int daysOverdue(DateTime today) => dateOnly(today).difference(nextDue).inDays;

  Map<String, Object?> toMap() => {
        'name': name, 'platform': platform, 'difficulty': difficulty, 'topic': topic, 'url': url, 'notes': notes,
        'solvedOn': dayKey(solvedOn), 'stage': stage, 'nextDue': dayKey(nextDue),
      };

  factory Problem.fromMap(String id, Map<String, dynamic> m) => Problem(
        id: id, name: m['name'] as String, platform: m['platform'] as String, difficulty: m['difficulty'] as String,
        topic: m['topic'] as String, url: m['url'] as String?, notes: m['notes'] as String?,
        solvedOn: parseDay(m['solvedOn'] as String), stage: m['stage'] as int, nextDue: parseDay(m['nextDue'] as String),
      );

  /// Records one review: returns the rescheduled problem and the log entry to save.
  (Problem, Review) review({required bool remembered, required DateTime on}) {
    final day = dateOnly(on);
    final (newStage, due) = afterReview(stage, remembered, day);
    return (
      Problem(
        id: id, name: name, platform: platform, difficulty: difficulty, topic: topic,
        url: url, notes: notes, solvedOn: solvedOn, stage: newStage, nextDue: due,
      ),
      Review(problemId: id, reviewedOn: day, remembered: remembered, stageBefore: stage),
    );
  }
}

/// One review you did: kept forever for streaks and topic strength.
class Review {
  const Review({required this.problemId, required this.reviewedOn, required this.remembered, required this.stageBefore});

  final String problemId;
  final DateTime reviewedOn;
  final bool remembered;
  final int stageBefore;

  Map<String, Object?> toMap() =>
      {'problemId': problemId, 'reviewedOn': dayKey(reviewedOn), 'remembered': remembered, 'stageBefore': stageBefore};

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        problemId: m['problemId'] as String, reviewedOn: parseDay(m['reviewedOn'] as String),
        remembered: m['remembered'] as bool, stageBefore: m['stageBefore'] as int,
      );
}

/// Days are stored as 'YYYY-MM-DD' text: no time zone, sorts correctly, readable in the Firebase console.
String dayKey(DateTime day) => dateOnly(day).toIso8601String().substring(0, 10);

DateTime parseDay(String key) => dateOnly(DateTime.parse(key));
