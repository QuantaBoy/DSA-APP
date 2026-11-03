import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/scan.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/gate.dart';

void main() {
  test('syllabus ids are unique and tags round-trip', () {
    final ids = [for (final s in gateDa) ...s.topics.map((t) => t.id)];
    expect(ids.toSet().length, ids.length);
    expect(gateTopicCount, ids.length);
    expect(gateTopicOf(gateTag('la-eigen')), 'la-eigen');
    expect(isGateCard('Percentages'), isFalse);
    expect(gateLookup('la-eigen')!.section.id, 'linalg');
  });

  test('the next subtopic is the first uncovered one in order', () {
    expect(nextGateTopic({})!.id, 'prob-count');
    expect(nextGateTopic({'prob-count'})!.id, 'prob-axioms');
    expect(sectionProgress(gateDa[2], {'calc-limits', 'calc-taylor'}), 0.5);
  });

  test('covering a subtopic is saved and can be undone', () async {
    final store = Store('u', db: FakeFirebaseFirestore());
    await store.setGateCovered('ml-pca', covered: true);
    expect((await store.data().first).stats.gateCovered, {'ml-pca'});
    await store.setGateCovered('ml-pca', covered: false);
    expect((await store.data().first).stats.gateCovered, isEmpty);
  });

  test('the AI is told which subtopic ids it may use and its pick is read back', () {
    expect(gatePrompt([(id: 'la-eigen', name: 'Eigen')]), contains('la-eigen: Eigen'));
    final q = parseScan(
      '{"questions":[{"question":"q","options":["a","b"],"answer":1,"explanation":"e","topic":"t","subtopic":"la-eigen"}]}',
    );
    expect(q.single.subtopic, 'la-eigen');
  });
}
