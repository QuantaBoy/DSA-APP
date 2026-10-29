import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';
import 'package:memory_stack/screens/library_page.dart';
import 'package:memory_stack/screens/profile_page.dart';
import 'package:memory_stack/screens/review_page.dart';
import 'package:memory_stack/screens/stats_page.dart';
import 'package:memory_stack/screens/streak_page.dart';
import 'package:memory_stack/screens/today_page.dart';
import 'package:memory_stack/screens/widgets.dart';

Problem solved(String id, int daysAgo, {String topic = 'Arrays'}) => Problem.solved(
  id: id,
  name: 'Problem $id',
  platform: 'LeetCode',
  difficulty: 'Easy',
  topic: topic,
  solvedOn: addDays(today(), -daysAgo),
);

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A tall screen, so every list item is built without scrolling.
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('due labels read naturally', () {
    expect(dueLabel(0), 'due today');
    expect(dueLabel(1), '1 day overdue');
    expect(dueLabel(4), '4 days overdue');
    expect(dueLabel(-1), 'tomorrow');
    expect(dueLabel(-3), 'in 3 days');
  });

  testWidgets('Today lists due problems with a start button, and upcoming ones', (tester) async {
    tall(tester);
    final problems = [solved('a', 3), solved('b', 1), solved('c', 0)]; // a overdue, b due today, c due tomorrow
    await tester.pumpWidget(app(TodayPage(store: Store('test'), problems: problems, stats: const Stats(), onOpenSheet: () {})));
    expect(find.text('2 problems to review'), findsOneWidget);
    expect(find.text('2 days overdue'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Coming up this week'), findsOneWidget);
  });

  testWidgets('Today with an empty stack points to the sheet', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      app(TodayPage(store: Store('test'), problems: const [], stats: const Stats(), onOpenSheet: () => opened = true)),
    );
    expect(find.text('Start the A2Z sheet'), findsOneWidget);
    await tester.tap(find.text('Open the sheet'));
    expect(opened, isTrue);
  });

  testWidgets('Stats shows totals, recall rate and the weakest topic first', (tester) async {
    tall(tester);
    final problems = [solved('a', 10, topic: 'Arrays'), solved('b', 10, topic: 'Graphs')];
    final stats = Stats(days: {today(): 4}, topics: {'Graphs': (remembered: 0, total: 3), 'Arrays': (remembered: 1, total: 1)});
    await tester.pumpWidget(app(StatsPage(problems: problems, stats: stats)));
    await tester.pumpAndSettle(); // let the ring count up
    expect(find.text('25%'), findsOneWidget); // 1 of 4 remembered
    expect(find.text('0% · 1 solved'), findsOneWidget);
    final graphs = tester.getTopLeft(find.text('Graphs')).dy, arrays = tester.getTopLeft(find.text('Arrays')).dy;
    expect(graphs, lessThan(arrays));
  });

  testWidgets('Review: flip shows the solution card, grading moves on, undo brings the card back', (tester) async {
    tall(tester);
    final store = Store('u', db: FakeFirebaseFirestore());
    final a = solved('a', 3).copyWith(patterns: ['Hashing']), b = solved('b', 2);
    // Database calls run on the real clock; the widget-test clock only moves when pumped.
    await tester.runAsync(() async {
      await store.addProblem(
        a,
        solution: const Solution(idea: 'value to index map', time: 'O(n)'),
      );
      await store.addProblem(b);
    });
    Future<int?> stageOfA() => tester.runAsync(() async => (await store.data().first).problems.firstWhere((p) => p.id == 'a').stage);
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPage(store: store, queue: [a, b]),
      ),
    );
    expect(find.text("What's the approach?"), findsOneWidget);
    expect(find.text('value to index map'), findsNothing); // hidden until flipped

    await tester.tap(find.text('Show my solution'));
    await settle();
    await settle(); // the card loads, then draws
    expect(find.text('value to index map'), findsOneWidget);
    expect(find.text('Time O(n)'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget); // grade buttons appear after the flip

    await tester.tap(find.text('Good'));
    await settle();
    expect(find.text('Review 2 of 2'), findsOneWidget);
    expect(await stageOfA(), 1);

    await tester.tap(find.text('Undo'));
    await settle();
    expect(find.text('Review 1 of 2'), findsOneWidget);
    expect(await stageOfA(), 0);
  });

  testWidgets('Streak page shows the streak, the next challenge and the record', (tester) async {
    tall(tester);
    final now = today();
    final stats = Stats(days: {for (var i = 0; i < 5; i++) addDays(now, -i): 1, addDays(now, -30): 1});
    await tester.pumpWidget(MaterialApp(home: StreakPage(stats: stats)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('5'), findsWidgets);
    expect(find.text('7 days challenge'), findsOneWidget);
    expect(find.text('Day 5 of 7'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget); // record
    expect(find.text('2 days to go'), findsOneWidget); // 7-day milestone
  });

  testWidgets('Streak celebration counts up by one and ticks today', (tester) async {
    tall(tester);
    final now = today();
    await tester.pumpWidget(MaterialApp(home: StreakCelebration(before: 4, reviewDays: {now, addDays(now, -1)})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Patterns view groups problems by pattern, weakest first', (tester) async {
    tall(tester);
    final problems = [
      solved('a', 1).copyWith(patterns: ['Two Pointers'], reviews: 4, remembered: 4),
      solved('b', 1).copyWith(patterns: ['Two Pointers', 'Sorting'], reviews: 2, remembered: 2),
      solved('c', 1).copyWith(patterns: ['Sliding Window'], reviews: 4, remembered: 1),
      solved('d', 1),
    ];
    await tester.pumpWidget(app(PatternsView(problems: problems)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Two Pointers'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget); // Sliding Window: 1 of 4
    expect(find.textContaining('1 problem has no pattern'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Sliding Window')).dy, lessThanOrEqualTo(tester.getTopLeft(find.text('Two Pointers')).dy));
  });

  testWidgets('Activity heatmap counts active days', (tester) async {
    tall(tester);
    final now = today();
    await tester.pumpWidget(
      app(
        ActivityHeatmap(
          stats: Stats(days: {now: 3, addDays(now, -2): 1, addDays(now, -400): 5}),
          today: now,
        ),
      ),
    );
    expect(find.text('2 active days in the last 18 weeks'), findsOneWidget);
  });
}
