import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';
import 'package:memory_stack/screens/review_page.dart';
import 'package:memory_stack/screens/stats_page.dart';
import 'package:memory_stack/screens/today_page.dart';
import 'package:memory_stack/screens/widgets.dart';

Problem solved(String id, int daysAgo, {String topic = 'Arrays'}) => Problem.solved(
    id: id, name: 'Problem $id', platform: 'LeetCode', difficulty: 'Easy', topic: topic, solvedOn: addDays(today(), -daysAgo));

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
    await tester.pumpWidget(app(TodayPage(store: Store('test'), problems: const [], stats: const Stats(), onOpenSheet: () => opened = true)));
    expect(find.text('All caught up'), findsOneWidget);
    await tester.tap(find.text('Open A2Z sheet'));
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

  testWidgets('Review shows a code pad, and checking reveals the saved solution', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1; // tall screen: everything visible without scrolling
    addTearDown(tester.view.reset);
    final p = solved('a', 3);
    await tester.pumpWidget(MaterialApp(home: ReviewPage(store: _NotesStore('return seen[target - x]'), queue: [p])));
    expect(find.text('Write it from memory'), findsOneWidget);
    expect(find.text('return seen[target - x]'), findsNothing); // hidden until you check
    await tester.tap(find.text('Check against my solution'));
    await tester.pumpAndSettle();
    expect(find.text('return seen[target - x]'), findsOneWidget);
    expect(find.textContaining('Different code is fine'), findsOneWidget);
  });
}

/// A store whose saved solution is fixed, so the review screen can be tested without Firebase.
class _NotesStore extends Store {
  _NotesStore(this.saved) : super('test');

  final String saved;

  @override
  Future<String?> notes(String id) async => saved;
}
