import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/scan.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';

void main() {
  test('scan results keep valid questions and drop broken ones', () {
    final json = jsonEncode({
      'questions': [
        {
          'question': 'What is 20% of 50?',
          'options': ['5', '10', ' ', '20'],
          'answer': 1,
          'photoAnswer': -1,
          'explanation': '50 × 0.2 = 10',
          'topic': 'Percentages',
        },
        {'question': 'No options', 'options': <String>[], 'answer': 0, 'explanation': '', 'topic': 'x'},
        {'question': 'Answer out of range', 'options': ['a', 'b'], 'answer': 5, 'explanation': '', 'topic': 'x'},
        {'question': 'Photo disagrees', 'options': ['a', 'b'], 'answer': 0, 'photoAnswer': 1, 'explanation': '', 'topic': ''},
      ],
    });
    final found = parseScan(json);
    expect(found.length, 2);
    expect(found.first.options, ['5', '10', '20'], reason: 'blank option dropped');
    expect(found.first.photoAnswer, isNull);
    expect((found.last.photoAnswer, found.last.topic), (1, 'General'));
    expect(() => parseScan('not json'), throwsA(isA<ScanException>()));
  });

  test('right answers move a card up, wrong ones bring it back tomorrow', () {
    final card = AptCard.fresh(id: 'c', question: 'q', options: ['a', 'b'], answer: 0);
    final day = DateTime.utc(2026, 11, 2);
    final right = card.review(correct: true, on: day);
    expect((right.stage, right.nextDue, right.remembered), (1, addDays(day, reviewIntervals[1]), 1));
    final wrong = right.review(correct: false, on: day);
    expect((wrong.stage, wrong.nextDue, wrong.reviews), (0, addDays(day, reviewIntervals[0]), 2));
    expect(card.copyWith(answer: 2).isValid, isFalse);
  });

  test('cards are saved, reviewed (counting for the streak) and deleted', () async {
    final db = FakeFirebaseFirestore();
    final store = Store('u1', db: db);
    final card = AptCard.fresh(id: store.newAptId(), question: 'What is 2+2?', options: ['3', '4'], answer: 1, topic: 'Arithmetic');
    await store.saveApt(card);
    expect((await store.aptCards().first).single.question, 'What is 2+2?');

    await store.reviewApt(card, correct: true);
    expect((await store.aptCards().first).single.stage, 1);
    final user = (await db.doc('users/u1').get()).data()!;
    expect((user['days'] as Map)[dayKey(today())], 1);

    expect(() => store.saveApt(card.copyWith(options: ['only one'])), throwsArgumentError);
    await store.deleteApt(card.id);
    expect(await store.aptCards().first, isEmpty);
  });
}
