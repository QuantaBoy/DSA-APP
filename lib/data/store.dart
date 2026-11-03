import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/models.dart';
import '../logic/srs.dart';

/// Everything the screens show, loaded from one Firestore document.
typedef UserData = ({List<Problem> problems, Stats stats});

/// Reads and writes one user's data in Firestore.
///
/// users/{uid}              one document: every problem (by id), reviews per day, results per topic
/// users/{uid}/notes/{id}   the solution card (idea, complexity, mistake, code), loaded only when opened
///
/// Opening the app costs one read however many problems you have; Firebase's free plan allows 50,000 a day.
/// Firestore keeps a copy on the device, so everything works offline and syncs later.
/// Writes update the local copy (and the stream) at once, but their Futures only finish
/// when the server confirms, so screens should not wait on them before moving on.
class Store {
  Store(this.uid, {FirebaseFirestore? db}) : _dbOverride = db;

  final String uid;
  final FirebaseFirestore? _dbOverride; // tests pass a fake
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  static const _version = 2; // version 1 kept one document per problem and per review

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _notes => _user.collection('notes');
  CollectionReference<Map<String, dynamic>> get _apt => _user.collection('apt');

  Stream<UserData> data() => _user.snapshots().map((s) {
    final m = s.data() ?? const {};
    return (
      problems: [
        for (final e in (m['problems'] as Map? ?? {}).entries) Problem.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map)),
      ],
      stats: Stats.fromMap(m),
    );
  });

  /// Your problems as the server has them (not the offline copy, which may be behind on a new device).
  Future<List<Problem>> serverProblems() async {
    final m = (await _user.get(const GetOptions(source: Source.server))).data() ?? const {};
    return [
      for (final e in (m['problems'] as Map? ?? {}).entries) Problem.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map)),
    ];
  }

  /// A fresh id for Problem.solved(id: ...).
  String newProblemId() => _notes.doc().id;

  Future<void> addProblem(Problem p, {Solution? solution}) => Future.wait([
    _user.set({
      'v': _version,
      'problems': {p.id: p.toMap()},
    }, SetOptions(merge: true)),
    if (solution != null && !solution.isEmpty) setSolution(p.id, solution),
  ]);

  /// Reschedules the problem and adds the review to the day and topic totals, in one write.
  Future<void> review(Problem p, Grade grade) => _user.update({
    FieldPath(['problems', p.id]): p.review(grade: grade, on: today()).toMap(),
    FieldPath(['days', dayKey(today())]): FieldValue.increment(1),
    FieldPath(['topics', p.topic, 'total']): FieldValue.increment(1),
    if (grade.remembered) FieldPath(['topics', p.topic, 'remembered']): FieldValue.increment(1),
  });

  /// Replaces the latest grade of [p] (a mis-tap): reschedules from before that review and fixes recall,
  /// without counting another review.
  Future<void> regrade(Problem p, Grade grade) {
    final old = p.last!.grade;
    return _user.update({
      FieldPath(['problems', p.id]): p.regrade(grade, on: today()).toMap(),
      if (old.remembered != grade.remembered) FieldPath(['topics', p.topic, 'remembered']): FieldValue.increment(grade.remembered ? 1 : -1),
    });
  }

  /// Adds right quiz answers to your total (5 XP each) and counts the quiz as activity for the day.
  Future<void> addQuizScore(int right) => _user.set({
    'quiz': FieldValue.increment(right),
    'days': {dayKey(today()): FieldValue.increment(0)},
  }, SetOptions(merge: true));

  /// Reverses [review]: puts [before] (the problem as it was) back and takes the review out of the totals.
  Future<void> undoReview(Problem before, Grade grade) => _user.update({
    FieldPath(['problems', before.id]): before.toMap(),
    FieldPath(['days', dayKey(today())]): FieldValue.increment(-1),
    FieldPath(['topics', before.topic, 'total']): FieldValue.increment(-1),
    if (grade.remembered) FieldPath(['topics', before.topic, 'remembered']): FieldValue.increment(-1),
  });

  /// Tags a problem with DSA patterns (kept on the problem so the pattern library needs no extra reads).
  Future<void> setPatterns(String id, List<String> patterns) => _user.update({
    FieldPath(['problems', id, 'patterns']): patterns.take(Limits.maxPatterns).toList(),
  });

  /// Deletes a problem, its notes, and its share of the topic totals.
  Future<void> deleteProblem(Problem p) => Future.wait([
    _user.update({
      FieldPath(['problems', p.id]): FieldValue.delete(),
      if (p.reviews > 0) FieldPath(['topics', p.topic, 'total']): FieldValue.increment(-p.reviews),
      if (p.remembered > 0) FieldPath(['topics', p.topic, 'remembered']): FieldValue.increment(-p.remembered),
    }),
    _notes.doc(p.id).delete(),
  ]);

  /// The saved solution card, or an empty one.
  Future<Solution> solution(String id) async {
    final data = (await _notes.doc(id).get()).data();
    return data == null ? const Solution() : Solution.fromMap(data);
  }

  /// Saves (or clears, when empty) a solution card. Throws [ArgumentError] when a field is over its limit,
  /// the same limits firestore.rules enforces, so a bad write fails here instead of silently on the server.
  Future<void> setSolution(String id, Solution s) {
    if (s.isEmpty) return _notes.doc(id).delete();
    if (!fitsLimits(s)) throw ArgumentError.value(s, 'solution', 'a field is over its length limit');
    return _notes.doc(id).set(s.toMap());
  }

  static bool fitsLimits(Solution s) =>
      s.code.length <= Limits.maxNoteLength &&
      s.question.length <= Limits.questionLength &&
      s.idea.length <= Limits.shortTextLength &&
      s.mistake.length <= Limits.shortTextLength &&
      s.time.length <= Limits.complexityLength &&
      s.space.length <= Limits.complexityLength;

  /// Deletes every problem, note, aptitude card and review day: used to reset progress and when the account is deleted.
  Future<void> deleteEverything() async {
    final docs = [
      ...(await _notes.get()).docs,
      ...(await _apt.get()).docs,
      ...(await _user.collection('problems').get()).docs, // version 1 data, if never moved
      ...(await _user.collection('reviews').get()).docs,
    ];
    for (var i = 0; i < docs.length; i += 500) {
      // a Firestore batch holds at most 500 writes
      final batch = _db.batch();
      for (final d in docs.skip(i).take(500)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await _user.delete();
  }

  /// Your aptitude cards. ponytail: one document per card, so opening the list reads every card;
  /// move the schedule into the user document (like problems) if decks grow past a few hundred.
  Stream<List<AptCard>> aptCards() => _apt.snapshots().map((s) => [for (final d in s.docs) AptCard.fromMap(d.id, d.data())]);

  String newAptId() => _apt.doc().id;

  /// Saves a new or edited card. Throws [ArgumentError] when it breaks the limits (the rules would reject it).
  Future<void> saveApt(AptCard card) {
    if (!card.isValid) throw ArgumentError('Aptitude card is empty or too long');
    return _apt.doc(card.id).set(card.toMap());
  }

  /// Reschedules the card and counts the review for the streak, in one batch.
  Future<void> reviewApt(AptCard card, {required bool correct}) =>
      (_db.batch()
            ..set(_apt.doc(card.id), card.review(correct: correct, on: today()).toMap())
            ..set(_user, {
              'days': {dayKey(today()): FieldValue.increment(1)},
            }, SetOptions(merge: true)))
          .commit();

  Future<void> deleteApt(String id) => _apt.doc(id).delete();

  /// Moves version 1 data (a document per problem and per review) into the version 2 layout, once.
  Future<void> upgrade() async {
    final user = await _user.get();
    if ((user.data()?['v'] as int? ?? 0) >= _version) return;
    final oldProblems = await _user.collection('problems').get();
    final oldReviews = await _user.collection('reviews').get();

    final problems = <String, Map<String, dynamic>>{};
    for (final d in oldProblems.docs) {
      problems[d.id] = Map.of(d.data())..remove('notes');
    }
    final days = <String, int>{};
    final topics = <String, Map<String, int>>{};
    for (final d in oldReviews.docs) {
      final r = d.data(), id = r['problemId'] as String, remembered = r['remembered'] as bool;
      final p = problems[id];
      if (p == null) continue; // review of a deleted problem
      final day = r['reviewedOn'] as String;
      days[day] = (days[day] ?? 0) + 1;
      p['reviews'] = (p['reviews'] as int? ?? 0) + 1;
      final t = topics.putIfAbsent(p['topic'] as String, () => {'remembered': 0, 'total': 0});
      t['total'] = t['total']! + 1;
      if (remembered) {
        p['remembered'] = (p['remembered'] as int? ?? 0) + 1;
        t['remembered'] = t['remembered']! + 1;
      }
    }

    final batch = _db.batch()..set(_user, {'v': _version, 'problems': problems, 'days': days, 'topics': topics}, SetOptions(merge: true));
    for (final d in oldProblems.docs) {
      final notes = d.data()['notes'] as String?;
      if (notes != null && notes.isNotEmpty) batch.set(_notes.doc(d.id), {'text': notes});
    }
    await batch.commit();
    // Old documents go only after the new layout is saved, so nothing is lost if this stops halfway.
    final old = [...oldProblems.docs, ...oldReviews.docs];
    for (var i = 0; i < old.length; i += 500) {
      final b = _db.batch();
      for (final d in old.skip(i).take(500)) {
        b.delete(d.reference);
      }
      await b.commit();
    }
  }
}
