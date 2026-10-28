import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/models.dart';
import '../logic/srs.dart';

/// Everything the screens show, loaded from one Firestore document.
typedef UserData = ({List<Problem> problems, Stats stats});

/// Reads and writes one user's data in Firestore.
///
/// users/{uid}              one document: every problem (by id), reviews per day, results per topic
/// users/{uid}/notes/{id}   your notes or code for one problem, loaded only when opened
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

  Stream<UserData> data() => _user.snapshots().map((s) {
        final m = s.data() ?? const {};
        return (
          problems: [for (final e in (m['problems'] as Map? ?? {}).entries) Problem.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map))],
          stats: Stats.fromMap(m),
        );
      });

  /// A fresh id for Problem.solved(id: ...).
  String newProblemId() => _notes.doc().id;

  Future<void> addProblem(Problem p, {String? notes}) => Future.wait([
        _user.set({'v': _version, 'problems': {p.id: p.toMap()}}, SetOptions(merge: true)),
        if (notes != null && notes.isNotEmpty) setNotes(p.id, notes),
      ]);

  /// Reschedules the problem and adds the review to the day and topic totals, in one write.
  Future<void> review(Problem p, {required bool remembered}) => _user.update({
        FieldPath(['problems', p.id]): p.review(remembered: remembered, on: today()).toMap(),
        FieldPath(['days', dayKey(today())]): FieldValue.increment(1),
        FieldPath(['topics', p.topic, 'total']): FieldValue.increment(1),
        if (remembered) FieldPath(['topics', p.topic, 'remembered']): FieldValue.increment(1),
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

  Future<String?> notes(String id) async => (await _notes.doc(id).get()).data()?['text'] as String?;

  Future<void> setNotes(String id, String? text) =>
      text == null || text.isEmpty ? _notes.doc(id).delete() : _notes.doc(id).set({'text': text});

  /// Deletes every problem, note and total: used when the account is deleted.
  Future<void> deleteEverything() async {
    final docs = [
      ...(await _notes.get()).docs,
      ...(await _user.collection('problems').get()).docs, // version 1 data, if never moved
      ...(await _user.collection('reviews').get()).docs,
    ];
    for (var i = 0; i < docs.length; i += 500) { // a Firestore batch holds at most 500 writes
      final batch = _db.batch();
      for (final d in docs.skip(i).take(500)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await _user.delete();
  }

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

    final batch = _db.batch()
      ..set(_user, {'v': _version, 'problems': problems, 'days': days, 'topics': topics}, SetOptions(merge: true));
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
