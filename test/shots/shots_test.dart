@Tags(['shots'])
library;

// Renders the main screens to PNGs for design review: flutter test test/shots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/sheet.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/logic/srs.dart';
import 'package:memory_stack/main.dart';
import 'package:memory_stack/screens/library_page.dart';
import 'package:memory_stack/screens/login_page.dart';
import 'package:memory_stack/screens/onboarding_page.dart';
import 'package:memory_stack/screens/sheet_page.dart';
import 'package:memory_stack/screens/stack_page.dart';
import 'package:memory_stack/screens/stats_page.dart';
import 'package:memory_stack/screens/streak_page.dart';
import 'package:memory_stack/screens/today_page.dart';

const fonts = r'C:/flutter/bin/cache/artifacts/material_fonts';

Future<void> load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
  }
  await loader.load();
}

Problem p(String id, String name, String topic, String diff, int daysAgo, {int stage = 0}) => Problem(
  id: id,
  name: name,
  platform: 'LeetCode',
  difficulty: diff,
  topic: topic,
  solvedOn: addDays(today(), -30),
  stage: stage,
  nextDue: addDays(today(), -daysAgo),
);

final problems = [
  p('1', 'Two Sum', 'Arrays', 'Easy', 2, stage: 1),
  p('2', 'Longest Substring Without Repeating', 'Sliding Window', 'Medium', 0, stage: 2),
  p('3', 'Merge K Sorted Lists', 'Linked List', 'Hard', 0, stage: 3),
  p('4', 'Valid Parentheses', 'Stack', 'Easy', -2, stage: 4),
  p('5', 'Binary Tree Level Order', 'Trees', 'Medium', -5, stage: 9),
];
final stats = Stats(
  days: {
    for (var i = 0; i < 6; i++) addDays(today(), -i): [3, 5, 2, 4, 6, 1][i],
  },
  topics: {'Arrays': (remembered: 4, total: 5), 'Sliding Window': (remembered: 1, total: 4), 'Stack': (remembered: 3, total: 3)},
);

Future<void> shot(
  WidgetTester tester,
  String name,
  String title,
  Widget body, {
  int tab = 0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(brightness),
      home: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: CircleAvatar(radius: 17, child: Text('T')),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'A2Z Sheet'),
            NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: 'My stack'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2)); // let entrance animations finish (the illustration floats forever)
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
}

void main() {
  setUpAll(() async {
    await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
    await load('MaterialIcons', ['materialicons-regular.otf']);
    await loadA2zSheet(); // cached, so the sheet screen has it at once
  });

  testWidgets(
    'today',
    (t) => shot(t, 'today', 'Hi, Three', TodayPage(store: Store('x'), problems: problems, stats: stats, onOpenSheet: () {})),
  );
  testWidgets('stack', (t) => shot(t, 'stack', 'My stack', StackPage(store: Store('x'), problems: problems), tab: 2));
  testWidgets('stats', (t) => shot(t, 'stats', 'Stats', StatsPage(problems: problems, stats: stats), tab: 3));
  testWidgets(
    'sheet dark',
    (t) => shot(
      t,
      'sheet_dark',
      'A2Z Sheet',
      SheetPage(store: Store('x'), problems: problems),
      tab: 1,
      brightness: Brightness.dark,
    ),
  );
  testWidgets(
    'today dark',
    (t) => shot(
      t,
      'today_dark',
      'Hi, Three',
      TodayPage(store: Store('x'), problems: problems, stats: stats, onOpenSheet: () {}),
      brightness: Brightness.dark,
    ),
  );
  testWidgets(
    'stats dark',
    (t) => shot(
      t,
      'stats_dark',
      'Stats',
      StatsPage(problems: problems, stats: stats),
      tab: 3,
      brightness: Brightness.dark,
    ),
  );
  testWidgets('patterns', (t) => shot(t, 'patterns', 'Library', PatternsView(problems: [
    for (final (i, p) in problems.indexed) p.copyWith(patterns: [['Hashing', 'Two Pointers'], ['Sliding Window'], ['Heap'], ['Stack'], ['Tree Traversal', 'BFS']][i], reviews: 4, remembered: [4, 1, 2, 4, 3][i]),
  ]), tab: 2));
  testWidgets('onboarding', (t) => page(t, 'onboarding', OnboardingPage(onDone: () {})));
  testWidgets('streak', (t) => page(t, 'streak', StreakPage(stats: Stats(days: {for (var i = 0; i < 5; i++) addDays(today(), -i): 1}))));
  testWidgets(
    'streak celebration',
    (t) => page(t, 'streak_celebration', StreakCelebration(before: 4, reviewDays: {for (var i = 0; i < 5; i++) addDays(today(), -i)})),
  );
  testWidgets('login', (t) => page(t, 'login', const LoginPage()));
}

/// A full screen with no app bar or tabs (intro, login).
Future<void> page(WidgetTester tester, String name, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: appTheme(Brightness.light), home: home));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // decode images
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2)); // delayed pop-ins start, then finish
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
}
