import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/leaderboard.dart';
import 'package:memory_stack/data/prefs.dart';
import 'package:memory_stack/screens/leaderboard_page.dart';

void main() {
  test('publishing clamps values and the top list is sorted', () async {
    final board = Leaderboard(db: FakeFirebaseFirestore());
    await board.publish(uid: 'a', name: 'Asha', streak: 12, solved: 40);
    await board.publish(uid: 'b', name: 'Bilal', streak: 30, solved: 9999);
    await board.publish(uid: 'c', name: '  ', streak: 3, solved: 5);
    final byStreak = await board.top(Ranking.streak).first;
    expect(byStreak.map((e) => e.name), ['Bilal', 'Asha', 'Coder']);
    expect(byStreak.first.solved, 5000, reason: 'clamped to the rule limit');
    await board.leave('b');
    expect(await board.isJoined('b'), isFalse);
  });

  testWidgets('join shows exactly what is shared, then the podium with you on it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Prefs.leaderboard.value = false;
    final board = Leaderboard(db: FakeFirebaseFirestore());
    await tester.runAsync(() => board.publish(uid: 'other', name: 'Bilal', streak: 30, solved: 50));

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardPage(uid: 'me', name: 'Asha', streak: 7, solved: 12, board: board),
      ),
    );
    expect(find.text('Name: Asha'), findsOneWidget);
    expect(find.textContaining('Never your email'), findsOneWidget);

    await tester.tap(find.text('Join the leaderboard'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Asha (you)'), findsOneWidget);
    expect(find.text('Bilal'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
  });
}
