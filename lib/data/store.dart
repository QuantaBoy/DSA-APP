import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/models.dart';
import '../logic/srs.dart';

/// Reads and writes one user's data in Firestore: users/{uid}/problems and users/{uid}/reviews.
///
/// Firestore keeps a copy on the device, so everything works offline and syncs later.
/// Writes update the local copy (and every stream) at once, but their Futures only finish
/// when the server confirms, so screens should not wait on them before moving on.
class Store {
  Store(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _user => FirebaseFirestore.instance.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _problems => _user.collection('problems');
  CollectionReference<Map<String, dynamic>> get _reviews => _user.collection('reviews');

  Stream<List<Problem>> problems() =>
      _problems.snapshots().map((s) => [for (final d in s.docs) Problem.fromMap(d.id, d.data())]);

  Stream<List<Review>> reviews() => _reviews.snapshots().map((s) => [for (final d in s.docs) Review.fromMap(d.data())]);

  /// A fresh id for Problem.solved(id: ...).
  String newProblemId() => _problems.doc().id;

  Future<void> addProblem(Problem p) => _problems.doc(p.id).set(p.toMap());

  /// Saves the rescheduled problem and the review log together, so they never disagree.
  Future<void> review(Problem p, {required bool remembered}) {
    final (updated, log) = p.review(remembered: remembered, on: today());
    return (FirebaseFirestore.instance.batch()
          ..set(_problems.doc(p.id), updated.toMap())
          ..set(_reviews.doc(), log.toMap()))
        .commit();
  }

  /// Deletes a problem and its review history.
  Future<void> deleteProblem(String id) async {
    final history = await _reviews.where('problemId', isEqualTo: id).get();
    final batch = FirebaseFirestore.instance.batch()..delete(_problems.doc(id));
    for (final d in history.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
