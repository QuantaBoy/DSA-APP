import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';

Problem solved(String id, String topic) =>
    Problem.solved(id: id, name: 'P$id', platform: 'LeetCode', difficulty: 'Easy', topic: topic, solvedOn: addDays(today(), -3));

void main() {
  test('everything loads from one document; reviews update the totals; deleting takes a problem out', () async {
    final db = FakeFirebaseFirestore();
    final store = Store('u', db: db);
    await store.addProblem(solved('a', 'Arrays'), notes: 'two pointers');
    await store.addProblem(solved('b', 'Graphs'));
    var data = await store.data().first;
    await store.review(data.problems.firstWhere((p) => p.id == 'a'), remembered: true);
    await store.review(data.problems.firstWhere((p) => p.id == 'b'), remembered: false);

    data = await store.data().first;
    expect(data.problems.length, 2);
    expect(data.stats.reviewsOn(today()), 2);
    expect(data.stats.topics['Arrays'], (remembered: 1, total: 1));
    expect(data.stats.recall, 0.5);
    expect(await store.notes('a'), 'two pointers');
    expect(data.problems.firstWhere((p) => p.id == 'a').stage, 1);

    await store.deleteProblem(data.problems.firstWhere((p) => p.id == 'a'));
    data = await store.data().first;
    expect(data.problems.map((p) => p.id), ['b']);
    expect(data.stats.topics['Arrays'], (remembered: 0, total: 0));
    expect(data.stats.reviews, 2, reason: 'the streak and the day chart keep past days');
    expect(await store.notes('a'), isNull);
  });

  test('old layout (a document per problem and per review) moves over once, with notes', () async {
    final db = FakeFirebaseFirestore();
    final user = db.collection('users').doc('u');
    final p = solved('a', 'Arrays').review(remembered: true, on: today());
    await user.collection('problems').doc('a').set({
      ...p.toMap()
        ..remove('reviews')
        ..remove('remembered'),
      'notes': 'hash map',
    });
    await user.collection('reviews').add({'problemId': 'a', 'reviewedOn': '2026-10-27', 'remembered': true, 'stageBefore': 0});
    await user.collection('reviews').add({'problemId': 'gone', 'reviewedOn': '2026-10-27', 'remembered': false, 'stageBefore': 0});

    final store = Store('u', db: db);
    await store.upgrade();
    await store.upgrade(); // second run does nothing

    final data = await store.data().first;
    expect(data.problems.single.stage, 1);
    expect([data.problems.single.reviews, data.problems.single.remembered], [1, 1]);
    expect(data.stats.reviewsOn(DateTime.utc(2026, 10, 27)), 1, reason: 'review of a deleted problem is dropped');
    expect(data.stats.topics['Arrays'], (remembered: 1, total: 1));
    expect(await store.notes('a'), 'hash map');
    expect((await user.collection('problems').get()).docs, isEmpty);
    expect((await user.collection('reviews').get()).docs, isEmpty);
  });

  test('deleting everything leaves nothing behind', () async {
    final db = FakeFirebaseFirestore();
    final store = Store('u', db: db);
    await store.addProblem(solved('a', 'Arrays'), notes: 'x');
    await store.deleteEverything();
    expect((await db.collection('users').doc('u').get()).exists, isFalse);
    expect((await db.collection('users').doc('u').collection('notes').get()).docs, isEmpty);
  });
}
